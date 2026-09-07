"""Health slice tests — also the reference for how every feature is tested."""

from app.features.health.service import HealthService
from tests.conftest import FakeHealthRepository


async def test_health_endpoint_reports_ok_when_database_is_reachable(client):
    response = await client.get("/api/v1/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["database"]["connected"] is True
    assert body["database"]["version"] == "8.0.0"


async def test_service_reports_degraded_when_ping_fails():
    service = HealthService(FakeHealthRepository(healthy=False))

    result = await service.check()

    assert result.status == "degraded"
    assert result.database.connected is False


async def test_unknown_route_uses_the_standard_error_envelope(client):
    response = await client.get("/api/v1/does-not-exist")

    assert response.status_code == 404
    error = response.json()["error"]
    assert set(error) == {"code", "message", "details"}


async def test_openapi_schema_is_served(client):
    response = await client.get("/openapi.json")

    assert response.status_code == 200
    assert "/api/v1/health" in response.json()["paths"]
