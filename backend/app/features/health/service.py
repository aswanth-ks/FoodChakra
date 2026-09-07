"""Health business logic. Owns the decision of what 'healthy' means."""

import logging

from pymongo.errors import PyMongoError

from app.core.config import get_settings
from app.features.health.repository import HealthRepository
from app.features.health.schemas import DatabaseHealth, HealthResponse

logger = logging.getLogger(__name__)


class HealthService:
    def __init__(self, repository: HealthRepository) -> None:
        self._repository = repository

    async def check(self) -> HealthResponse:
        settings = get_settings()
        database = await self._check_database()
        return HealthResponse(
            status="ok" if database.connected else "degraded",
            app=settings.APP_NAME,
            environment=settings.ENVIRONMENT,
            database=database,
        )

    async def _check_database(self) -> DatabaseHealth:
        try:
            connected = await self._repository.ping()
            version = await self._repository.server_version() if connected else None
            return DatabaseHealth(connected=connected, version=version)
        except PyMongoError as exc:
            # A failing dependency must not crash the health endpoint — the whole
            # point is to report the failure.
            logger.warning("MongoDB health check failed: %s", exc)
            return DatabaseHealth(connected=False, error=str(exc))
