"""Authentication and authorization tests.

The repository is faked in memory, including the `uniq_email` constraint, so
these run without MongoDB. Everything above the driver — hashing, token
issuing, rotation, status checks, role guards — is the real implementation.
"""

from datetime import UTC, datetime, timedelta

import jwt
import pytest

from app.core.config import get_settings
from app.core.security import (
    TokenType,
    create_access_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.features.auth.schemas import AccountRole, AccountStatus, StaffLevel
from tests.conftest import auth_header

# ------------------------------------------------------------- registration


async def test_registration_creates_an_active_consumer(api, users):
    response = await api.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Asha Rao",
            "email": "Asha@Example.com",
            "password": "a-good-password",
        },
    )

    assert response.status_code == 201
    body = response.json()
    # Email is normalised so a second registration cannot vary only by case.
    assert body["email"] == "asha@example.com"

    stored = next(iter(users.documents.values()))
    assert stored["role"] == "consumer"
    assert stored["status"] == "active"
    assert stored["staff"] is None
    assert stored["email_verified"] is False


async def test_registration_issues_no_session(api, users):
    """The account exists, but nothing signs the caller in.

    Handing over tokens here would make verification optional in practice,
    whatever the login rule says.
    """
    response = await api.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Asha Rao",
            "email": "asha@example.com",
            "password": "a-good-password",
        },
    )

    body = response.json()
    assert "access_token" not in body
    assert "refresh_token" not in body
    assert "user" not in body


async def test_public_registration_cannot_create_a_partner(api, users):
    """The escalation attempt is rejected outright, not silently downgraded."""
    response = await api.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Sneaky",
            "email": "sneaky@example.com",
            "password": "a-good-password",
            "role": "partner",
        },
    )

    assert response.status_code == 422
    assert users.documents == {}


@pytest.mark.parametrize("field", ["status", "staff", "partner_id", "is_staff"])
async def test_registration_rejects_every_privileged_field(api, users, field):
    response = await api.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Sneaky",
            "email": "sneaky@example.com",
            "password": "a-good-password",
            field: "active",
        },
    )

    assert response.status_code == 422
    assert users.documents == {}


async def test_a_foodloop_address_does_not_grant_partner_access(api, users):
    """The exact hole `roleForEmail()` opened on the client."""
    response = await api.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Not A Partner",
            "email": "someone@foodloop.com",
            "password": "a-good-password",
        },
    )

    assert response.status_code == 201
    stored = next(iter(users.documents.values()))
    assert stored["role"] == "consumer"
    assert stored["staff"] is None


async def test_duplicate_email_is_a_conflict(api, users):
    users.seed(email="taken@example.com")

    response = await api.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Second",
            "email": "taken@example.com",
            "password": "a-good-password",
        },
    )

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "CONFLICT"


@pytest.mark.parametrize(
    "email", ["not-an-email", "", "missing@", "@example.com", "a b@example.com"]
)
async def test_invalid_email_is_rejected(api, email):
    response = await api.post(
        "/api/v1/auth/register",
        json={"full_name": "X", "email": email, "password": "a-good-password"},
    )
    assert response.status_code == 422


@pytest.mark.parametrize("password", ["", "short", "1234567"])
async def test_weak_password_is_rejected(api, password):
    response = await api.post(
        "/api/v1/auth/register",
        json={"full_name": "X", "email": "x@example.com", "password": password},
    )
    assert response.status_code == 422


async def test_password_beyond_bcrypts_limit_is_rejected(api):
    # Truncating instead would let two different passwords open one account.
    response = await api.post(
        "/api/v1/auth/register",
        json={
            "full_name": "X",
            "email": "x@example.com",
            "password": "p" * 73,
        },
    )
    assert response.status_code == 422


async def test_blank_full_name_is_rejected(api):
    response = await api.post(
        "/api/v1/auth/register",
        json={"full_name": "   ", "email": "x@example.com", "password": "a-good-password"},
    )
    assert response.status_code == 422


# --------------------------------------------------------------------- login


async def test_login_with_correct_credentials(api, users):
    users.seed(email="user@example.com", password="correct-horse")

    response = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )

    assert response.status_code == 200
    assert response.json()["user"]["email"] == "user@example.com"


async def test_login_records_last_login(api, users):
    stored = users.seed(email="user@example.com", password="correct-horse")
    assert stored["last_login_at"] is None

    await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )

    assert stored["last_login_at"] is not None


async def test_wrong_password_is_rejected(api, users):
    users.seed(email="user@example.com", password="correct-horse")

    response = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "wrong-horse"},
    )

    assert response.status_code == 401


async def test_unknown_account_and_wrong_password_are_indistinguishable(api, users):
    """Differing messages would be a free account-enumeration oracle."""
    users.seed(email="user@example.com", password="correct-horse")

    wrong = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "wrong-horse"},
    )
    missing = await api.post(
        "/api/v1/auth/login",
        json={"email": "nobody@example.com", "password": "wrong-horse"},
    )

    assert wrong.status_code == missing.status_code == 401
    assert wrong.json() == missing.json()


@pytest.mark.parametrize(
    "status", [AccountStatus.SUSPENDED, AccountStatus.DISABLED]
)
async def test_inactive_accounts_cannot_log_in(api, users, status):
    users.seed(email="user@example.com", password="correct-horse", status=status)

    response = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "FORBIDDEN"


# --------------------------------------------------------------------- JWT


async def test_me_returns_the_authenticated_account(api, users):
    users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )
    token = login.json()["access_token"]

    response = await api.get("/api/v1/auth/me", headers=auth_header(token))

    assert response.status_code == 200
    assert response.json()["email"] == "user@example.com"
    assert response.json()["role"] == "consumer"


async def test_missing_token_is_unauthorized(api):
    response = await api.get("/api/v1/auth/me")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"


@pytest.mark.parametrize("token", ["garbage", "a.b.c", ""])
async def test_malformed_token_is_unauthorized(api, token):
    response = await api.get("/api/v1/auth/me", headers=auth_header(token))
    assert response.status_code == 401


async def test_token_signed_with_another_secret_is_rejected(api, users):
    stored = users.seed()
    forged = jwt.encode(
        {
            "sub": str(stored["_id"]),
            "type": "access",
            "jti": "x",
            "exp": datetime.now(UTC) + timedelta(hours=1),
        },
        "an-attackers-own-secret-key-of-sufficient-length",
        algorithm="HS256",
    )

    response = await api.get("/api/v1/auth/me", headers=auth_header(forged))

    assert response.status_code == 401


async def test_expired_token_is_rejected(api, users):
    settings = get_settings()
    stored = users.seed()
    expired = jwt.encode(
        {
            "sub": str(stored["_id"]),
            "type": "access",
            "jti": "x",
            "iat": datetime.now(UTC) - timedelta(hours=2),
            "exp": datetime.now(UTC) - timedelta(hours=1),
        },
        settings.JWT_SECRET,
        algorithm=settings.JWT_ALGORITHM,
    )

    response = await api.get("/api/v1/auth/me", headers=auth_header(expired))

    assert response.status_code == 401


async def test_a_refresh_token_is_not_accepted_as_an_access_token(api, users):
    """Otherwise a 30-minute exposure window silently becomes 30 days."""
    users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )
    refresh_token = login.json()["refresh_token"]

    response = await api.get("/api/v1/auth/me", headers=auth_header(refresh_token))

    assert response.status_code == 401


async def test_access_token_does_not_carry_sensitive_data(users):
    token, _ = create_access_token(user_id="abc", role="consumer")
    payload = decode_token(token, expected_type=TokenType.ACCESS)

    # A JWT is signed, not encrypted — any holder can read the payload.
    assert set(payload) == {"sub", "type", "jti", "iat", "exp", "role", "staff"}
    assert "password_hash" not in payload
    assert "email" not in payload


async def test_role_change_takes_effect_without_waiting_for_expiry(api, users):
    """The user record is authoritative, not the token's role claim."""
    stored = users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )
    token = login.json()["access_token"]

    # Token still says consumer; the record now says partner.
    stored["role"] = AccountRole.PARTNER.value

    consumer = await api.get("/probe/consumer", headers=auth_header(token))
    partner = await api.get("/probe/partner", headers=auth_header(token))

    assert consumer.status_code == 403
    assert partner.status_code == 200


async def test_suspension_revokes_access_immediately(api, users):
    stored = users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )
    token = login.json()["access_token"]
    assert (await api.get("/api/v1/auth/me", headers=auth_header(token))).status_code == 200

    stored["status"] = AccountStatus.SUSPENDED.value

    assert (await api.get("/api/v1/auth/me", headers=auth_header(token))).status_code == 403


# ------------------------------------------------------------------ refresh


async def test_refresh_rotates_and_returns_new_tokens(api, users):
    users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )
    old_refresh = login.json()["refresh_token"]

    response = await api.post(
        "/api/v1/auth/refresh", json={"refresh_token": old_refresh}
    )

    assert response.status_code == 200
    assert response.json()["refresh_token"] != old_refresh


async def test_a_replayed_refresh_token_revokes_every_session(api, users):
    """Replay means the token was captured; refusing one request is not enough."""
    stored = users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )
    old_refresh = login.json()["refresh_token"]

    first = await api.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
    new_refresh = first.json()["refresh_token"]

    replay = await api.post("/api/v1/auth/refresh", json={"refresh_token": old_refresh})
    assert replay.status_code == 401
    assert stored["refresh_sessions"] == []

    # The legitimately rotated token is collateral damage, by design.
    after = await api.post("/api/v1/auth/refresh", json={"refresh_token": new_refresh})
    assert after.status_code == 401


async def test_access_token_cannot_be_used_to_refresh(api, users):
    users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )

    response = await api.post(
        "/api/v1/auth/refresh", json={"refresh_token": login.json()["access_token"]}
    )

    assert response.status_code == 401


async def test_suspended_account_cannot_refresh(api, users):
    stored = users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )
    stored["status"] = AccountStatus.SUSPENDED.value

    response = await api.post(
        "/api/v1/auth/refresh", json={"refresh_token": login.json()["refresh_token"]}
    )

    assert response.status_code == 403


# ------------------------------------------------------------------- logout


async def test_logout_revokes_the_supplied_session(api, users):
    users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )
    tokens = login.json()

    logout = await api.post(
        "/api/v1/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
        headers=auth_header(tokens["access_token"]),
    )
    assert logout.status_code == 204

    reuse = await api.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert reuse.status_code == 401


async def test_logout_requires_authentication(api):
    response = await api.post("/api/v1/auth/logout")
    assert response.status_code == 401


# ------------------------------------------------------------ authorization


async def test_consumer_guard_admits_consumers_and_refuses_partners(api, users):
    users.seed(email="c@example.com", password="pw-pw-pw-pw", role=AccountRole.CONSUMER)
    users.seed(email="p@example.com", password="pw-pw-pw-pw", role=AccountRole.PARTNER)

    async def token_for(email: str) -> str:
        login = await api.post(
            "/api/v1/auth/login", json={"email": email, "password": "pw-pw-pw-pw"}
        )
        return login.json()["access_token"]

    consumer_token = await token_for("c@example.com")
    partner_token = await token_for("p@example.com")

    async def probe(path: str, token: str) -> int:
        return (await api.get(path, headers=auth_header(token))).status_code

    assert await probe("/probe/consumer", consumer_token) == 200
    assert await probe("/probe/consumer", partner_token) == 403
    assert await probe("/probe/partner", partner_token) == 200
    assert await probe("/probe/partner", consumer_token) == 403


async def test_guarded_routes_reject_anonymous_callers(api):
    for path in ("/probe/any", "/probe/consumer", "/probe/partner", "/probe/staff"):
        assert (await api.get(path)).status_code == 401


async def test_staff_access_is_independent_of_account_role(api, users):
    """An operator may hold a consumer account; the console still opens."""
    users.seed(
        email="ops@example.com",
        password="pw-pw-pw-pw",
        role=AccountRole.CONSUMER,
        staff=StaffLevel.OPERATOR.value,
    )
    login = await api.post(
        "/api/v1/auth/login", json={"email": "ops@example.com", "password": "pw-pw-pw-pw"}
    )
    token = login.json()["access_token"]

    assert (await api.get("/probe/staff", headers=auth_header(token))).status_code == 200
    # Still a consumer for everything else.
    assert (await api.get("/probe/consumer", headers=auth_header(token))).status_code == 200


async def test_ordinary_accounts_are_refused_staff_access(api, users):
    users.seed(email="c@example.com", password="pw-pw-pw-pw")
    login = await api.post(
        "/api/v1/auth/login", json={"email": "c@example.com", "password": "pw-pw-pw-pw"}
    )

    response = await api.get(
        "/probe/staff", headers=auth_header(login.json()["access_token"])
    )

    assert response.status_code == 403


# ---------------------------------------------------------------- security


async def test_passwords_are_hashed_never_stored_plaintext(api, users):
    await api.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Asha",
            "email": "asha@example.com",
            "password": "a-good-password",
        },
    )

    [stored] = users.documents.values()
    assert "password" not in stored
    assert stored["password_hash"] != "a-good-password"
    assert stored["password_hash"].startswith("$2b$")
    assert verify_password("a-good-password", stored["password_hash"])


async def test_the_same_password_produces_different_hashes():
    # Per-hash salt: identical passwords must not yield identical hashes.
    assert hash_password("a-good-password") != hash_password("a-good-password")


@pytest.mark.parametrize("path", ["register", "login"])
async def test_password_hash_never_appears_in_a_response(api, users, path):
    users.seed(email="user@example.com", password="correct-horse")
    payload = (
        {"full_name": "New", "email": "new@example.com", "password": "a-good-password"}
        if path == "register"
        else {"email": "user@example.com", "password": "correct-horse"}
    )

    response = await api.post(f"/api/v1/auth/{path}", json=payload)

    assert "password_hash" not in response.text
    assert "password" not in response.text
    assert "refresh_sessions" not in response.text


async def test_me_never_exposes_internal_fields(api, users):
    users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )

    response = await api.get(
        "/api/v1/auth/me", headers=auth_header(login.json()["access_token"])
    )

    assert set(response.json()) == {
        "id",
        "email",
        "full_name",
        "role",
        "status",
        "email_verified",
        "is_staff",
        "partner_id",
        "created_at",
        "last_login_at",
    }


async def test_verify_password_survives_a_corrupt_stored_hash():
    # Must fail closed, not raise, or one bad row breaks the login endpoint.
    assert verify_password("anything", "") is False
    assert verify_password("anything", "not-a-bcrypt-hash") is False
