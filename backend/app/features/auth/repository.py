"""Users repository — the ONLY layer permitted to touch the MongoDB driver.

Refresh sessions live embedded on the user document rather than in their own
collection. They are always read with their user, never queried alone, and the
list is capped — which is exactly the rule `docs/BACKEND_CONTRACT.md` §3.1
gives for embedding, and it keeps the collection count at the agreed ten.
"""

from datetime import UTC, datetime
from typing import Any

from bson import ObjectId
from bson.errors import InvalidId
from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo import ReturnDocument

from app.db import collections as col

#: How many refresh sessions one account may hold at once — roughly "devices
#: signed in". The oldest is dropped beyond this, so a long-lived account
#: cannot grow its document without bound.
MAX_REFRESH_SESSIONS = 10


class UserRepository:
    def __init__(self, db: AsyncIOMotorDatabase) -> None:
        self._db = db

    @property
    def _collection(self):
        return self._db[col.USERS]

    # ------------------------------------------------------------- reads

    async def find_by_email(self, email: str) -> dict[str, Any] | None:
        """Look up by normalised email. Uses the `uniq_email` index."""
        return await self._collection.find_one({"email": email.strip().lower()})

    async def find_by_id(self, user_id: str) -> dict[str, Any] | None:
        try:
            object_id = ObjectId(user_id)
        except (InvalidId, TypeError):
            # A token subject that is not a valid ObjectId is simply unknown —
            # not an error worth propagating to the caller.
            return None
        return await self._collection.find_one({"_id": object_id})

    # ------------------------------------------------------------ writes

    async def create(self, document: dict[str, Any]) -> dict[str, Any]:
        """Insert a user and return the stored document.

        The caller must have hashed the password already; this layer neither
        hashes nor validates — that is the service's job.
        """
        result = await self._collection.insert_one(document)
        return {**document, "_id": result.inserted_id}

    async def record_login(self, user_id: ObjectId, when: datetime) -> None:
        await self._collection.update_one(
            {"_id": user_id},
            {"$set": {"last_login_at": when, "updated_at": when}},
        )

    async def add_refresh_session(
        self, user_id: ObjectId, *, jti: str, expires_at: datetime
    ) -> None:
        """Record an issued refresh token and prune stale ones.

        `$push` with `$slice` keeps the newest N in one atomic update, so two
        concurrent sign-ins cannot race each other into an unbounded list.
        """
        now = datetime.now(UTC)
        await self._collection.update_one(
            {"_id": user_id},
            {
                "$push": {
                    "refresh_sessions": {
                        "$each": [
                            {"jti": jti, "expires_at": expires_at, "created_at": now}
                        ],
                        "$slice": -MAX_REFRESH_SESSIONS,
                    }
                },
                "$set": {"updated_at": now},
            },
        )

    async def consume_refresh_session(self, user_id: ObjectId, jti: str) -> bool:
        """Atomically remove one refresh session. True if it was present.

        This is what makes rotation safe. The pull is the *check*: exactly one
        concurrent caller can remove a given jti, so a replayed refresh token
        finds nothing to consume and is refused rather than minting a second
        valid session.
        """
        result = await self._collection.update_one(
            {"_id": user_id, "refresh_sessions.jti": jti},
            {"$pull": {"refresh_sessions": {"jti": jti}}},
        )
        return result.modified_count == 1

    # ------------------------------------------------- one-time codes

    # Verification and reset state is embedded on the user document, the same
    # way refresh sessions are, and for the same reason: it is only ever read
    # with its user, never queried on its own, and it is a single bounded
    # subdocument. Separate `email_otps` / `password_resets` collections would
    # add two collections and a join to store one small object.

    async def set_email_verification(
        self, user_id: ObjectId, *, code_hash: str, expires_at: datetime
    ) -> None:
        """Issue a verification code, replacing any previous one.

        Overwriting is what invalidates the old code: there is exactly one
        `code_hash`, so the previous code stops matching the moment a new one
        is issued. `sent_at` is the cooldown clock.
        """
        now = datetime.now(UTC)
        await self._collection.update_one(
            {"_id": user_id},
            {
                "$set": {
                    "email_verification": {
                        "code_hash": code_hash,
                        "expires_at": expires_at,
                        "attempts": 0,
                        "sent_at": now,
                    },
                    "updated_at": now,
                }
            },
        )

    async def count_verification_attempt(self, user_id: ObjectId) -> int:
        """Record a wrong code and return the new attempt count."""
        updated = await self._collection.find_one_and_update(
            {"_id": user_id},
            {"$inc": {"email_verification.attempts": 1}},
            projection={"email_verification.attempts": 1},
            return_document=True,
        )
        if updated is None:
            return 0
        return int(updated.get("email_verification", {}).get("attempts", 0))

    async def complete_email_verification(
        self, user_id: ObjectId, *, code_hash: str
    ) -> bool:
        """Mark the email verified and consume the code. True if this call won.

        The filter on `code_hash` is what makes single use real: two requests
        carrying the same correct code both reach here, and only the first
        matches — the second finds the subdocument already gone. Without it,
        both would "succeed" and the code would remain usable.
        """
        result = await self._collection.update_one(
            {"_id": user_id, "email_verification.code_hash": code_hash},
            {
                "$set": {"email_verified": True, "updated_at": datetime.now(UTC)},
                "$unset": {"email_verification": ""},
            },
        )
        return result.modified_count == 1

    async def clear_email_verification(self, user_id: ObjectId) -> None:
        """Burn the code after too many wrong attempts. A resend is required."""
        await self._collection.update_one(
            {"_id": user_id},
            {
                "$unset": {"email_verification": ""},
                "$set": {"updated_at": datetime.now(UTC)},
            },
        )

    async def set_password_reset(
        self, user_id: ObjectId, *, code_hash: str, expires_at: datetime
    ) -> None:
        now = datetime.now(UTC)
        await self._collection.update_one(
            {"_id": user_id},
            {
                "$set": {
                    "password_reset": {
                        "code_hash": code_hash,
                        "expires_at": expires_at,
                        "attempts": 0,
                        "sent_at": now,
                    },
                    "updated_at": now,
                }
            },
        )

    async def count_reset_attempt(self, user_id: ObjectId) -> int:
        updated = await self._collection.find_one_and_update(
            {"_id": user_id},
            {"$inc": {"password_reset.attempts": 1}},
            projection={"password_reset.attempts": 1},
            return_document=True,
        )
        if updated is None:
            return 0
        return int(updated.get("password_reset", {}).get("attempts", 0))

    async def clear_password_reset(self, user_id: ObjectId) -> None:
        await self._collection.update_one(
            {"_id": user_id},
            {
                "$unset": {"password_reset": ""},
                "$set": {"updated_at": datetime.now(UTC)},
            },
        )

    async def complete_password_reset(
        self, user_id: ObjectId, *, code_hash: str, password_hash: str
    ) -> bool:
        """Set the new password, consume the code, and sign out everywhere.

        All three in one conditional update. Revoking the refresh sessions
        here rather than in a second call is deliberate: a reset that changed
        the password but left an attacker's thirty-day session alive would be
        worse than no reset at all, and two writes can be interrupted between.
        """
        result = await self._collection.update_one(
            {"_id": user_id, "password_reset.code_hash": code_hash},
            {
                "$set": {
                    "password_hash": password_hash,
                    "refresh_sessions": [],
                    "updated_at": datetime.now(UTC),
                },
                "$unset": {"password_reset": ""},
            },
        )
        return result.modified_count == 1

    async def update_full_name(
        self, user_id: ObjectId, full_name: str
    ) -> dict[str, Any] | None:
        """Rename the account, returning the document as it now stands.

        Scoped to one `_id`, which is the caller's own and comes from the
        token — there is no code path that takes an id from a request body.
        """
        return await self._collection.find_one_and_update(
            {"_id": user_id},
            {"$set": {"full_name": full_name, "updated_at": datetime.now(UTC)}},
            return_document=ReturnDocument.AFTER,
        )

    async def change_password(
        self, user_id: ObjectId, *, password_hash: str
    ) -> bool:
        """Set a new password and sign out everywhere, in one write.

        Same reasoning as `complete_password_reset`: a change that left the
        old thirty-day refresh sessions alive would not actually lock anybody
        out, and two separate writes can be interrupted between.
        """
        result = await self._collection.update_one(
            {"_id": user_id},
            {
                "$set": {
                    "password_hash": password_hash,
                    "refresh_sessions": [],
                    "updated_at": datetime.now(UTC),
                }
            },
        )
        return result.modified_count == 1

    async def revoke_all_refresh_sessions(self, user_id: ObjectId) -> None:
        """Sign out everywhere. Also the response to a replayed refresh token."""
        await self._collection.update_one(
            {"_id": user_id},
            {
                "$set": {
                    "refresh_sessions": [],
                    "updated_at": datetime.now(UTC),
                }
            },
        )
