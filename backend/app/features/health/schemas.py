"""Health API contracts. Schemas define the wire format — nothing else."""

from typing import Literal

from pydantic import BaseModel, Field


class DatabaseHealth(BaseModel):
    connected: bool = Field(..., description="Whether a live ping succeeded")
    version: str | None = Field(None, description="MongoDB server version")
    error: str | None = Field(None, description="Failure reason when not connected")


class StartupTimingResponse(BaseModel):
    """How long this process took to become ready, in milliseconds.

    Deployment-visible on purpose: it is the difference between "the platform
    took a long time to start a container" and "the application took a long
    time to connect", and without it the two are indistinguishable from
    outside. Durations only — nothing here identifies a host or a credential.
    """

    connect_ms: int | None = None
    indexes_ms: int | None = None
    total_ms: int | None = None


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded"]
    app: str
    environment: str
    database: DatabaseHealth
    startup: StartupTimingResponse | None = None
