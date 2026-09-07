"""Health repository — the ONLY layer permitted to touch the MongoDB driver."""

from motor.motor_asyncio import AsyncIOMotorDatabase


class HealthRepository:
    def __init__(self, db: AsyncIOMotorDatabase) -> None:
        self._db = db

    async def ping(self) -> bool:
        """Round-trip a real command to the server. Returns True when healthy."""
        result = await self._db.command("ping")
        return bool(result.get("ok") == 1)

    async def server_version(self) -> str:
        info = await self._db.client.server_info()
        return str(info.get("version", "unknown"))
