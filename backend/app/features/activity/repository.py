"""Activity event repository — the ONLY layer permitted to touch the driver."""

from motor.motor_asyncio import AsyncIOMotorDatabase

from app.db import collections as col
from app.features.activity.schemas import ActivityEvent


class ActivityEventRepository:
    def __init__(self, db: AsyncIOMotorDatabase) -> None:
        self._db = db

    @property
    def _collection(self):
        return self._db[col.ACTIVITY_EVENTS]

    async def append(self, event: ActivityEvent) -> str:
        """Insert one event and return its id.

        Append is the only write this repository offers. There is no update and
        no delete, deliberately: an audit trail that can be rewritten is not
        evidence of anything.
        """
        result = await self._collection.insert_one(event.model_dump(mode="python"))
        return str(result.inserted_id)

    async def append_many(self, events: list[ActivityEvent]) -> int:
        if not events:
            return 0
        result = await self._collection.insert_many(
            [event.model_dump(mode="python") for event in events]
        )
        return len(result.inserted_ids)
