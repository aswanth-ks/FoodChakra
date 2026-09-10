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

from datetime import UTC, datetime  # noqa: E402
from typing import Any  # noqa: E402

from bson import ObjectId  # noqa: E402
from fastapi import Depends, FastAPI  # noqa: E402
from httpx import ASGITransport, AsyncClient  # noqa: E402
from pymongo.errors import DuplicateKeyError  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.core.email import EmailService  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.features.auth.dependencies import (  # noqa: E402
    CurrentUser,
    get_auth_service,
    require_consumer,
    require_partner,
    require_staff,
)
from app.features.auth.repository import UserRepository  # noqa: E402
from app.features.auth.schemas import (  # noqa: E402
    AccountRole,
    AccountStatus,
)
from app.features.auth.service import AuthService  # noqa: E402
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


# ---------------------------------------------------- authentication

class FakeUserRepository(UserRepository):
    """In-memory users, reproducing the unique-email index."""

    def __init__(self) -> None:
        self.documents: dict[ObjectId, dict[str, Any]] = {}

    async def find_by_email(self, email: str) -> dict[str, Any] | None:
        target = email.strip().lower()
        return next(
            (d for d in self.documents.values() if d["email"] == target), None
        )

    async def find_by_id(self, user_id: str) -> dict[str, Any] | None:
        try:
            return self.documents.get(ObjectId(user_id))
        except Exception:
            return None

    async def create(self, document: dict[str, Any]) -> dict[str, Any]:
        if await self.find_by_email(document["email"]) is not None:
            raise DuplicateKeyError("E11000 duplicate key error: email")
        object_id = ObjectId()
        stored = {**document, "_id": object_id}
        self.documents[object_id] = stored
        return stored

    async def record_login(self, user_id: ObjectId, when: datetime) -> None:
        self.documents[user_id]["last_login_at"] = when

    async def add_refresh_session(
        self, user_id: ObjectId, *, jti: str, expires_at: datetime
    ) -> None:
        self.documents[user_id].setdefault("refresh_sessions", []).append(
            {"jti": jti, "expires_at": expires_at}
        )

    async def consume_refresh_session(self, user_id: ObjectId, jti: str) -> bool:
        sessions = self.documents[user_id].get("refresh_sessions", [])
        remaining = [s for s in sessions if s["jti"] != jti]
        if len(remaining) == len(sessions):
            return False
        self.documents[user_id]["refresh_sessions"] = remaining
        return True

    async def revoke_all_refresh_sessions(self, user_id: ObjectId) -> None:
        self.documents[user_id]["refresh_sessions"] = []

    # ----- one-time codes -----

    async def set_email_verification(
        self, user_id: ObjectId, *, code_hash: str, expires_at: datetime
    ) -> None:
        self.documents[user_id]["email_verification"] = {
            "code_hash": code_hash,
            "expires_at": expires_at,
            "attempts": 0,
            "sent_at": datetime.now(UTC),
        }

    async def count_verification_attempt(self, user_id: ObjectId) -> int:
        record = self.documents[user_id].get("email_verification")
        if not record:
            return 0
        record["attempts"] += 1
        return record["attempts"]

    async def complete_email_verification(
        self, user_id: ObjectId, *, code_hash: str
    ) -> bool:
        document = self.documents[user_id]
        record = document.get("email_verification")
        # Mirrors the conditional update: only the caller that still sees this
        # exact code hash wins, so two correct guesses produce one success.
        if not record or record["code_hash"] != code_hash:
            return False
        document.pop("email_verification")
        document["email_verified"] = True
        return True

    async def clear_email_verification(self, user_id: ObjectId) -> None:
        self.documents[user_id].pop("email_verification", None)

    async def set_password_reset(
        self, user_id: ObjectId, *, code_hash: str, expires_at: datetime
    ) -> None:
        self.documents[user_id]["password_reset"] = {
            "code_hash": code_hash,
            "expires_at": expires_at,
            "attempts": 0,
            "sent_at": datetime.now(UTC),
        }

    async def count_reset_attempt(self, user_id: ObjectId) -> int:
        record = self.documents[user_id].get("password_reset")
        if not record:
            return 0
        record["attempts"] += 1
        return record["attempts"]

    async def clear_password_reset(self, user_id: ObjectId) -> None:
        self.documents[user_id].pop("password_reset", None)

    async def complete_password_reset(
        self, user_id: ObjectId, *, code_hash: str, password_hash: str
    ) -> bool:
        document = self.documents[user_id]
        record = document.get("password_reset")
        if not record or record["code_hash"] != code_hash:
            return False
        document.pop("password_reset")
        document["password_hash"] = password_hash
        # A reset signs every device out; the fake must do it too or the test
        # that proves it would pass for the wrong reason.
        document["refresh_sessions"] = []
        return True

    # ----- test helper -----
    def seed(
        self,
        *,
        email: str = "seed@example.com",
        password: str = "correct-horse",
        role: AccountRole = AccountRole.CONSUMER,
        status: AccountStatus = AccountStatus.ACTIVE,
        staff: str | None = None,
        partner_id: ObjectId | None = None,
        email_verified: bool = True,
    ) -> dict[str, Any]:
        now = datetime.now(UTC)
        object_id = ObjectId()
        stored = {
            "_id": object_id,
            "email": email,
            "password_hash": hash_password(password),
            "full_name": "Seeded User",
            "role": role.value,
            "status": status.value,
            # Verified by default: a seeded account stands for an existing
            # user, and login now requires a confirmed address.
            "email_verified": email_verified,
            "staff": staff,
            "partner_id": partner_id,
            "refresh_sessions": [],
            "created_at": now,
            "updated_at": now,
            "last_login_at": None,
        }
        self.documents[object_id] = stored
        return stored


class FakeEmailService(EmailService):
    """Records what would have been sent. No SMTP, ever.

    Substituted at the `EmailService` boundary rather than inside the auth
    service, so the tests exercise the real call sites and the real failure
    handling. `fail_with` makes a send raise, which is how the "SMTP is down"
    paths are covered without an unreachable mail server.
    """

    def __init__(self) -> None:
        self.verification: list[tuple[str, str]] = []
        self.password_reset: list[tuple[str, str]] = []
        self.logins: list[str] = []
        self.fail_with: Exception | None = None

    @property
    def configured(self) -> bool:
        return True

    async def send_verification_otp(
        self, *, to: str, full_name: str, code: str
    ) -> None:
        self._maybe_fail()
        self.verification.append((to, code))

    async def send_password_reset_otp(
        self, *, to: str, full_name: str, code: str
    ) -> None:
        self._maybe_fail()
        self.password_reset.append((to, code))

    async def send_login_notification(self, *, to: str, full_name: str) -> None:
        self._maybe_fail()
        self.logins.append(to)

    def _maybe_fail(self) -> None:
        if self.fail_with is not None:
            raise self.fail_with

    # ----- helpers -----

    @property
    def last_verification_code(self) -> str:
        return self.verification[-1][1]

    @property
    def last_reset_code(self) -> str:
        return self.password_reset[-1][1]


@pytest.fixture
def users() -> FakeUserRepository:
    return FakeUserRepository()


@pytest.fixture
def mail() -> FakeEmailService:
    return FakeEmailService()


@pytest.fixture
def auth_app(users: FakeUserRepository, mail: FakeEmailService) -> FastAPI:
    """The real app, with guarded probe routes mounted for the guard tests."""
    application = create_app()
    application.dependency_overrides[get_auth_service] = lambda: AuthService(
        users, mail
    )

    @application.get("/probe/any")
    async def _any(user: CurrentUser):  # pragma: no cover - exercised via HTTP
        return {"id": user.id, "role": user.role}

    @application.get("/probe/consumer")
    async def _consumer(user=Depends(require_consumer)):  # pragma: no cover
        return {"ok": True}

    @application.get("/probe/partner")
    async def _partner(user=Depends(require_partner)):  # pragma: no cover
        return {"ok": True}

    @application.get("/probe/staff")
    async def _staff(user=Depends(require_staff)):  # pragma: no cover
        return {"ok": True}

    return application


@pytest.fixture
async def api(auth_app):
    transport = ASGITransport(app=auth_app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


def auth_header(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


