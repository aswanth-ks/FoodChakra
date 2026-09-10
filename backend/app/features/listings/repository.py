"""Listings repository — the ONLY layer permitted to touch the MongoDB driver.

Every query here is served by an index declared in `app/db/indexes.py`. None
was added for Stage D: `geo_pickup_location`, `by_status_expires_at` and
`by_owner_created` already covered all three access patterns.
"""

from datetime import UTC, datetime
from typing import Any

from bson import ObjectId
from bson.errors import InvalidId
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.db import collections as col
from app.shared.lifecycle import LISTING_CLAIMABLE_STATES, LifecycleState


def claimable_filter(*, now: datetime | None = None) -> dict[str, Any]:
    """The filter defining "this listing can still be claimed".

    Built from `LISTING_CLAIMABLE_STATES` rather than a literal list, so it
    cannot drift from the canonical lifecycle.

    **Stage E must reuse this.** The atomic claim is
    `find_one_and_update(claimable_filter() | {"_id": id}, {"$set": {...}})`,
    which lets exactly one concurrent caller win. Reading the listing, checking
    availability in Python, and then inserting a rescue is the race this exists
    to prevent — it looks correct and double-books under load.
    """
    return {
        "status": {"$in": sorted(s.value for s in LISTING_CLAIMABLE_STATES)},
        "expires_at": {"$gt": now or datetime.now(UTC)},
    }


class ListingRepository:
    def __init__(self, db: AsyncIOMotorDatabase) -> None:
        self._db = db

    @property
    def _collection(self):
        return self._db[col.LISTINGS]

    # -------------------------------------------------------------- writes

    async def create(self, document: dict[str, Any]) -> dict[str, Any]:
        result = await self._collection.insert_one(document)
        return {**document, "_id": result.inserted_id}

    async def set_status(
        self,
        listing_id: ObjectId,
        *,
        expected: list[LifecycleState],
        status: LifecycleState,
        extra: dict[str, Any] | None = None,
    ) -> dict[str, Any] | None:
        """Move a listing to `status`, but only from one of `expected`.

        The expected-state guard is part of the query, not a prior read, so two
        concurrent cancels cannot both succeed. Returns the updated document,
        or None when the listing was not in an expected state.
        """
        changes: dict[str, Any] = {
            "status": status.value,
            "updated_at": datetime.now(UTC),
        }
        changes.update(extra or {})

        return await self._collection.find_one_and_update(
            {
                "_id": listing_id,
                "status": {"$in": [state.value for state in expected]},
            },
            {"$set": changes},
            return_document=True,
        )

    async def claim(
        self, listing_id: ObjectId, *, rescue_id: ObjectId
    ) -> dict[str, Any] | None:
        """Atomically take a claimable listing. Returns the pre-claim document.

        **This single call is the mutual exclusion for the whole rescue flow.**
        The claimable condition lives inside the update's filter, so MongoDB
        applies it and the write as one indivisible operation: of two consumers
        tapping "Rescue" in the same millisecond, exactly one matches a
        `published`/`searching` document, and the other matches nothing and
        gets `None`.

        The alternative — read the listing, check it in Python, then write —
        has a window between the check and the write in which the other request
        does the same thing. Both see "available", both proceed, and the
        surplus is promised twice. That window is small, which is precisely
        what makes it dangerous: it passes every manual test.

        `return_document=False` returns the document *before* the update, which
        is what makes the compensating release in the service possible — it
        carries the status to restore.
        """
        return await self._collection.find_one_and_update(
            {"_id": listing_id, **claimable_filter()},
            {
                "$set": {
                    "status": LifecycleState.MATCHED.value,
                    "active_rescue_id": rescue_id,
                    "updated_at": datetime.now(UTC),
                }
            },
            return_document=False,
        )

    async def release(
        self,
        listing_id: ObjectId,
        *,
        rescue_id: ObjectId,
        restore_to: LifecycleState,
    ) -> bool:
        """Undo a claim, returning the listing to the pool.

        Guarded on `active_rescue_id` so it can only ever undo *this* claim.
        Without that guard a late compensating write could release a listing
        that a different rescuer has since legitimately claimed.
        """
        result = await self._collection.update_one(
            {
                "_id": listing_id,
                "active_rescue_id": rescue_id,
                "status": LifecycleState.MATCHED.value,
            },
            {
                "$set": {
                    "status": restore_to.value,
                    "active_rescue_id": None,
                    "updated_at": datetime.now(UTC),
                }
            },
        )
        return result.modified_count == 1

    # --------------------------------------------------------------- reads

    async def find_by_id(self, listing_id: str) -> dict[str, Any] | None:
        try:
            object_id = ObjectId(listing_id)
        except (InvalidId, TypeError):
            return None
        return await self._collection.find_one({"_id": object_id})

    async def find_nearby(
        self,
        *,
        longitude: float,
        latitude: float,
        radius_km: float,
        limit: int,
        offset: int,
        food_types: list[str] | None = None,
        source: str | None = None,
    ) -> list[dict[str, Any]]:
        """Claimable listings within `radius_km`, nearest first.

        `$nearSphere` does the distance work inside MongoDB against the
        `geo_pickup_location` 2dsphere index — the alternative, loading every
        listing into Python and measuring there, stops working at the first
        city. It also returns results already sorted by distance, which is the
        order the Explore list wants.
        """
        query: dict[str, Any] = {
            **claimable_filter(),
            "pickup_location.point": {
                "$nearSphere": {
                    "$geometry": {
                        "type": "Point",
                        "coordinates": [longitude, latitude],
                    },
                    "$maxDistance": radius_km * 1000,
                }
            },
        }
        if food_types:
            query["food_type"] = {"$in": food_types}
        if source:
            query["source"] = source

        # No explicit sort: $nearSphere already returns nearest-first, and
        # adding one would discard that ordering.
        cursor = self._collection.find(query).skip(offset).limit(limit)
        return await cursor.to_list(length=limit)

    async def find_by_owner(
        self,
        *,
        owner_id: ObjectId,
        statuses: list[str] | None,
        limit: int,
        offset: int,
    ) -> list[dict[str, Any]]:
        """A publisher's own listings, newest first (`by_owner_created`)."""
        query: dict[str, Any] = {"owner_user_id": owner_id}
        if statuses:
            query["status"] = {"$in": statuses}

        cursor = (
            self._collection.find(query)
            .sort("created_at", -1)
            .skip(offset)
            .limit(limit)
        )
        return await cursor.to_list(length=limit)

    async def reference_exists(self, reference: str) -> bool:
        """Backs the retry loop when generating a human-facing reference."""
        return await self._collection.count_documents(
            {"reference": reference}, limit=1
        ) > 0
