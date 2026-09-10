"""Rescues repository — the ONLY layer permitted to touch the MongoDB driver.

The listing-side atomic claim lives in `listings/repository.py`; this module
owns the rescue document that claim creates.
"""

from datetime import UTC, datetime
from typing import Any

from bson import ObjectId
from bson.errors import InvalidId
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.db import collections as col
from app.shared.lifecycle import RESCUE_ACTIVE_STATES, LifecycleState


def active_rescue_filter() -> dict[str, Any]:
    """Matches rescues that still occupy their listing.

    Mirrors the `uniq_active_rescue_per_listing` partial index exactly, and is
    derived from `RESCUE_ACTIVE_STATES` for the same reason the index is — so
    neither can drift from the canonical lifecycle.
    """
    return {"status": {"$in": sorted(s.value for s in RESCUE_ACTIVE_STATES)}}


class RescueRepository:
    def __init__(self, db: AsyncIOMotorDatabase) -> None:
        self._db = db

    @property
    def _collection(self):
        return self._db[col.RESCUES]

    async def create(self, document: dict[str, Any]) -> dict[str, Any]:
        """Insert a rescue.

        Raises `DuplicateKeyError` when an active rescue already exists for the
        listing — the `uniq_active_rescue_per_listing` partial index is the
        second line of defence behind the listing claim, and the service turns
        that error into a clean 409.
        """
        await self._collection.insert_one(document)
        return document

    async def delete(self, rescue_id: ObjectId) -> None:
        """Remove a rescue that never took effect.

        Only ever used to undo an insert whose listing claim could not be
        completed, so no rescue is left pointing at an unclaimed listing. It is
        not a user-facing delete: cancelling a rescue is a lifecycle
        transition, which preserves the record.
        """
        await self._collection.delete_one({"_id": rescue_id})

    async def find_by_id(self, rescue_id: str) -> dict[str, Any] | None:
        try:
            object_id = ObjectId(rescue_id)
        except (InvalidId, TypeError):
            return None
        return await self._collection.find_one({"_id": object_id})

    async def find_active_for_listing(
        self, listing_id: ObjectId
    ) -> dict[str, Any] | None:
        """The rescue currently holding a listing, if any.

        Used only to answer "who claimed it" after a claim is refused, so the
        caller can be told whether the listing is already theirs.
        """
        return await self._collection.find_one(
            {"listing_id": listing_id, **active_rescue_filter()}
        )

    async def find_by_rescuer(
        self, *, rescuer_id: ObjectId, active_only: bool, limit: int, offset: int
    ) -> list[dict[str, Any]]:
        """A consumer's own rescues, newest first (`by_rescuer_created`)."""
        query: dict[str, Any] = {"rescuer_id": rescuer_id}
        if active_only:
            query.update(active_rescue_filter())

        cursor = (
            self._collection.find(query)
            .sort("created_at", -1)
            .skip(offset)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def set_handover_code(
        self,
        rescue_id: ObjectId,
        *,
        code_hash: str,
        expires_at: datetime,
    ) -> None:
        """Store a freshly issued handover code and reset its attempt counter.

        Only the hash is written. The plaintext exists in memory long enough to
        be returned to the rescuer once and is never persisted.
        """
        await self._collection.update_one(
            {"_id": rescue_id},
            {
                "$set": {
                    "handover_code_hash": code_hash,
                    "handover_code_expires_at": expires_at,
                    "handover_attempts": 0,
                    "updated_at": datetime.now(UTC),
                }
            },
        )

    async def count_handover_attempt(self, rescue_id: ObjectId) -> int:
        """Atomically record a failed attempt and return the new total.

        `$inc` rather than read-modify-write: concurrent guesses must each be
        counted, or the attempt cap could be walked past by firing requests in
        parallel.
        """
        updated = await self._collection.find_one_and_update(
            {"_id": rescue_id},
            {"$inc": {"handover_attempts": 1}},
            return_document=True,
        )
        return int(updated.get("handover_attempts", 0)) if updated else 0

    async def set_status(
        self,
        rescue_id: ObjectId,
        *,
        expected: list[LifecycleState],
        status: LifecycleState,
        extra: dict[str, Any] | None = None,
    ) -> dict[str, Any] | None:
        """Move a rescue to `status`, but only from one of `expected`.

        The expected-state guard is in the query rather than a prior read, so
        two concurrent transitions cannot both succeed. Returns the updated
        document, or None when the rescue had already moved on.
        """
        now = datetime.now(UTC)
        changes: dict[str, Any] = {"status": status.value, "updated_at": now}
        changes.update(extra or {})

        return await self._collection.find_one_and_update(
            {
                "_id": rescue_id,
                "status": {"$in": [state.value for state in expected]},
            },
            {
                "$set": changes,
                "$push": {"lifecycle": {"step": status.value, "at": now}},
            },
            return_document=True,
        )
