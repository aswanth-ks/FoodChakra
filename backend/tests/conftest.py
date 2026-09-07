"""Shared test fixtures.

Tests must not depend on a reachable MongoDB. The database is faked at the
repository boundary — which is only possible because the layering forbids
routes from touching the driver directly.
"""

import os

import pytest

# Settings are read at import time, so the environment must be primed first.
os.environ.setdefault("MONGO_URI", "mongodb://localhost:27017")
os.environ.setdefault("JWT_SECRET", "test-secret-that-is-at-least-32-characters-long")
os.environ.setdefault("ENVIRONMENT", "local")

from httpx import ASGITransport, AsyncClient  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.features.health.repository import HealthRepository  # noqa: E402
from app.features.health.router import get_health_service  # noqa: E402
from app.features.health.service import HealthService  # noqa: E402
from app.main import create_app  # noqa: E402


class FakeHealthRepository(HealthRepository):
    """Stands in for MongoDB. `healthy=False` simulates an outage."""

    def __init__(self, *, healthy: bool = True) -> None:  # noqa: D107
        self._healthy = healthy

    async def ping(self) -> bool:
        return self._healthy

    async def server_version(self) -> str:
        return "8.0.0"


@pytest.fixture
def app():
    application = create_app()
    application.dependency_overrides[get_health_service] = lambda: HealthService(
        FakeHealthRepository(healthy=True)
    )
    return application


@pytest.fixture
async def client(app):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def settings():
    return get_settings()
