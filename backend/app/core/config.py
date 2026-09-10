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

    # ----- External services -----
    # Optional: nothing consumes it until the maps/geocoding work. Declared
    # here so it is configured through the same typed path as everything else
    # rather than read from os.environ ad hoc later. Empty means "not set up".
    GOOGLE_MAPS_API_KEY: str = ""

    # ----- Email (SMTP) -----
    # Credentials live here and nowhere else. Nothing about SMTP is ever sent
    # to a client, and no mobile or dashboard build reads any of it.
    SMTP_HOST: str = ""
    SMTP_PORT: int = 587
    SMTP_USERNAME: str = ""
    SMTP_PASSWORD: str = ""
    SMTP_FROM_EMAIL: str = ""
    SMTP_FROM_NAME: str = "FoodLoop"
    SMTP_USE_TLS: bool = True
    #: Hard ceiling on a single SMTP conversation. Login sends a notification
    #: email, and a hung mail server must not hold a request open.
    SMTP_TIMEOUT_SECONDS: float = 10.0

    # ----- One-time codes -----
    OTP_EXPIRE_MINUTES: int = 10
    OTP_MAX_ATTEMPTS: int = 5
    #: Minimum gap between two code emails to one address.
    OTP_RESEND_COOLDOWN_SECONDS: int = 60

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

    @property
    def email_configured(self) -> bool:
        """Whether outbound email can even be attempted.

        Read before every send. When this is False the API says so plainly —
        it never reports that a code was emailed when nothing left the process.
        """
        return bool(self.SMTP_HOST and self.SMTP_FROM_EMAIL)


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton. Use this everywhere instead of instantiating."""
    return Settings()  # type: ignore[call-arg]
