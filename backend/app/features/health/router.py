"""Health routes.

Reference implementation of the mandatory layering:

    Router -> Schema -> Service -> Repository -> MongoDB

The router only wires dependencies and returns the service result. It contains
no business logic and never touches the database driver.
"""

from typing import Annotated

from fastapi import APIRouter, Depends
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.db.mongo import get_db
from app.features.health.repository import HealthRepository
from app.features.health.schemas import HealthResponse
from app.features.health.service import HealthService

router = APIRouter(prefix="/health", tags=["health"])


def get_health_service(
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> HealthService:
    return HealthService(HealthRepository(db))


@router.get(
    "",
    response_model=HealthResponse,
    summary="Liveness and MongoDB connectivity check",
)
async def health(
    service: Annotated[HealthService, Depends(get_health_service)],
) -> HealthResponse:
    return await service.check()
