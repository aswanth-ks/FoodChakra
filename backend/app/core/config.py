"""Typed application configuration.

Every value comes from the environment (or `backend/.env`). No secret is ever
written into tracked source. Import the singleton via `get_settings()` so the
`.env` file is parsed exactly once per process.
"""

from functools import lru_cache
from typing import Annotated, Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # ----- Application -----
    APP_NAME: str = "FoodLoop API"
    API_V1_PREFIX: str = "/api/v1"
    ENVIRONMENT: Literal["local", "dev", "staging", "production"] = "local"
    DEBUG: bool = True

    # ----- Database -----
    MONGO_URI: str = Field(..., description="MongoDB Atlas connection string")
    MONGO_DB_NAME: str = "foodloop"

    # ----- Auth (consumed from Phase 3 onward) -----
    JWT_SECRET: str = Field(..., min_length=32)
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # ----- CORS -----
    # Comma-separated in the environment, e.g. "http://localhost:5173,http://localhost:3000".
    # `NoDecode` stops pydantic-settings from JSON-parsing the raw value so the
    # validator below can accept a plain comma-separated string.
    CORS_ORIGINS: Annotated[list[str], NoDecode] = ["http://localhost:5173"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def _split_origins(cls, value: object) -> object:
        if isinstance(value, str):
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT == "production"


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton. Use this everywhere instead of instantiating."""
    return Settings()  # type: ignore[call-arg]
