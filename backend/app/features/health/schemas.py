"""Health API contracts. Schemas define the wire format — nothing else."""

from typing import Literal

from pydantic import BaseModel, Field


class DatabaseHealth(BaseModel):
    connected: bool = Field(..., description="Whether a live ping succeeded")
    version: str | None = Field(None, description="MongoDB server version")
    error: str | None = Field(None, description="Failure reason when not connected")


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded"]
    app: str
    environment: str
    database: DatabaseHealth
