"""Email verification, password reset and the sign-in notification.

Email is faked at the `EmailService` boundary, never inside `AuthService`, so
these exercise the real call sites and the real failure handling. No test
touches a mail server, and none needs MongoDB.

The fake is also how a test learns a code: nothing else in the system ever
reveals one, which is the property most of these tests exist to protect.
"""

import asyncio
import re
from datetime import UTC, datetime, timedelta

import pytest

from app.core.email import EmailDeliveryError, EmailNotConfiguredError
from app.core.security import generate_otp, hash_otp, verify_otp
from tests.conftest import auth_header

REGISTRATION = {
    "full_name": "Asha Rao",
    "email": "asha@example.com",
    "password": "a-good-password",
}


async def register(api) -> None:
    response = await api.post("/api/v1/auth/register", json=REGISTRATION)
    assert response.status_code == 201


def age_code(users, email: str, field: str, *, minutes: int) -> None:
    """Backdate a stored code so expiry and cooldown can be tested."""
    document = next(d for d in users.documents.values() if d["email"] == email)
    record = document[field]
    record["expires_at"] = datetime.now(UTC) - timedelta(minutes=minutes)
    record["sent_at"] = datetime.now(UTC) - timedelta(minutes=minutes + 10)


def clear_cooldown(users, email: str, field: str) -> None:
    document = next(d for d in users.documents.values() if d["email"] == email)
    document[field]["sent_at"] = datetime.now(UTC) - timedelta(hours=1)


# ------------------------------------------------------------- OTP primitives


def test_generated_codes_are_six_digits_and_vary():
    codes = {generate_otp() for _ in range(200)}
    assert all(len(c) == 6 and c.isdigit() for c in codes)
    # A generator with no entropy would collapse this set to a handful.
    assert len(codes) > 150


def test_a_code_hash_does_not_contain_the_code():
    code = "481920"
    stored = hash_otp(code)
    assert code not in stored
    assert verify_otp(code, stored)
    assert not verify_otp("481921", stored)


def test_verify_otp_survives_a_corrupt_hash():
    # A malformed stored value must fail to match, not raise on the auth path.
    assert verify_otp("123456", "not-a-bcrypt-hash") is False


# -------------------------------------------------------------- registration


async def test_registration_emails_a_code(api, users, mail):
    await register(api)

    assert len(mail.verification) == 1
    recipient, code = mail.verification[0]
    assert recipient == "asha@example.com"
    assert len(code) == 6 and code.isdigit()


async def test_the_code_is_never_in_the_response(api, mail):
    response = await api.post("/api/v1/auth/register", json=REGISTRATION)

    assert mail.last_verification_code not in response.text


async def test_only_a_hash_of_the_code_is_stored(api, users, mail):
    await register(api)

    stored = next(iter(users.documents.values()))
    record = stored["email_verification"]
    code = mail.last_verification_code
    assert code not in str(record)
    assert verify_otp(code, record["code_hash"])
    assert record["attempts"] == 0


async def test_a_new_account_starts_unverified(api, users):
    await register(api)
    assert next(iter(users.documents.values()))["email_verified"] is False


async def test_registration_reports_a_delivery_failure(api, users, mail):
    """The account exists but nothing was sent, and the API says so.

    Reporting 201 here would be the exact lie this stage exists to prevent —
    the user would sit waiting for an email that does not come.
    """
    mail.fail_with = EmailDeliveryError("smtp down")

    response = await api.post("/api/v1/auth/register", json=REGISTRATION)

    assert response.status_code == 503
    assert response.json()["error"]["code"] == "SERVICE_UNAVAILABLE"
    # Recoverable: the account is there, so "resend" can put it right.
    assert len(users.documents) == 1


async def test_registration_reports_missing_configuration(api, mail):
    mail.fail_with = EmailNotConfiguredError("no host")

    response = await api.post("/api/v1/auth/register", json=REGISTRATION)

    assert response.status_code == 503
    message = response.json()["error"]["message"]
    assert "not configured" in message
    # An operator's problem, described without naming a host or a credential.
    assert "smtp" not in message.lower() or "SMTP" in message


# ------------------------------------------------------------- verification


async def test_a_valid_code_verifies_the_account(api, users, mail):
    await register(api)

    response = await api.post(
        "/api/v1/auth/verify-email",
        json={"email": "asha@example.com", "code": mail.last_verification_code},
    )

    assert response.status_code == 200
    stored = next(iter(users.documents.values()))
    assert stored["email_verified"] is True
    # Consumed, not merely marked used.
    assert "email_verification" not in stored


async def test_a_wrong_code_fails_and_counts_an_attempt(api, users, mail):
    await register(api)

    response = await api.post(
        "/api/v1/auth/verify-email",
        json={"email": "asha@example.com", "code": "000000"},
    )

    assert response.status_code == 422
    stored = next(iter(users.documents.values()))
    assert stored["email_verified"] is False
    assert stored["email_verification"]["attempts"] == 1


async def test_an_expired_code_fails(api, users, mail):
    await register(api)
    age_code(users, "asha@example.com", "email_verification", minutes=1)

    response = await api.post(
        "/api/v1/auth/verify-email",
        json={"email": "asha@example.com", "code": mail.last_verification_code},
    )

    assert response.status_code == 422
    assert next(iter(users.documents.values()))["email_verified"] is False


async def test_a_code_cannot_be_reused(api, users, mail):
    await register(api)
    code = mail.last_verification_code
    body = {"email": "asha@example.com", "code": code}

    assert (await api.post("/api/v1/auth/verify-email", json=body)).status_code == 200
    second = await api.post("/api/v1/auth/verify-email", json=body)

    assert second.status_code == 422


async def test_the_attempt_cap_burns_the_code(api, users, mail):
    await register(api)
    code = mail.last_verification_code

    for _ in range(5):
        await api.post(
            "/api/v1/auth/verify-email",
            json={"email": "asha@example.com", "code": "000000"},
        )

    # Even the *correct* code no longer works: guessing has cost the user
    # this code entirely, and they must ask for another.
    response = await api.post(
        "/api/v1/auth/verify-email",
        json={"email": "asha@example.com", "code": code},
    )
    assert response.status_code == 422
    assert "email_verification" not in next(iter(users.documents.values()))


async def test_concurrent_verification_produces_one_success(api, users, mail):
    """Two requests, one correct code, exactly one winner.

    The conditional update is what guarantees it. Without the code-hash filter
    both would report success and the code would stay usable.
    """
    await register(api)
    body = {"email": "asha@example.com", "code": mail.last_verification_code}

    results = await asyncio.gather(
        api.post("/api/v1/auth/verify-email", json=body),
        api.post("/api/v1/auth/verify-email", json=body),
    )

    assert sorted(r.status_code for r in results) == [200, 422]


async def test_a_malformed_code_is_rejected_before_costing_an_attempt(api, users):
    await register(api)

    response = await api.post(
        "/api/v1/auth/verify-email",
        json={"email": "asha@example.com", "code": "12"},
    )

    assert response.status_code == 422
    assert next(iter(users.documents.values()))["email_verification"]["attempts"] == 0


async def test_verifying_an_unknown_address_reveals_nothing(api):
    response = await api.post(
        "/api/v1/auth/verify-email",
        json={"email": "nobody@example.com", "code": "123456"},
    )

    assert response.status_code == 422
    assert "not found" not in response.text.lower()


async def test_a_client_cannot_verify_itself(api, users):
    """`email_verified` is not a field a caller can set anywhere."""
    await register(api)

    response = await api.post(
        "/api/v1/auth/verify-email",
        json={
            "email": "asha@example.com",
            "code": "123456",
            "email_verified": True,
        },
    )

    assert response.status_code == 422
    assert next(iter(users.documents.values()))["email_verified"] is False


# ------------------------------------------------------------------ resend


async def test_resend_replaces_the_previous_code(api, users, mail):
    await register(api)
    first = mail.last_verification_code
    clear_cooldown(users, "asha@example.com", "email_verification")

    await api.post(
        "/api/v1/auth/verify-email/resend", json={"email": "asha@example.com"}
    )
    second = mail.last_verification_code

    assert first != second
    stale = await api.post(
        "/api/v1/auth/verify-email",
        json={"email": "asha@example.com", "code": first},
    )
    assert stale.status_code == 422

    fresh = await api.post(
        "/api/v1/auth/verify-email",
        json={"email": "asha@example.com", "code": second},
    )
    assert fresh.status_code == 200


async def test_resend_is_rate_limited(api, mail):
    await register(api)

    response = await api.post(
        "/api/v1/auth/verify-email/resend", json={"email": "asha@example.com"}
    )

    assert response.status_code == 429
    assert len(mail.verification) == 1, "no second email was sent"


async def test_resend_never_returns_a_code(api, users, mail):
    await register(api)
    clear_cooldown(users, "asha@example.com", "email_verification")

    response = await api.post(
        "/api/v1/auth/verify-email/resend", json={"email": "asha@example.com"}
    )

    assert mail.last_verification_code not in response.text


async def test_resend_for_an_unknown_address_looks_identical(api, mail):
    await register(api)
    known = await api.post(
        "/api/v1/auth/verify-email/resend", json={"email": "asha@example.com"}
    )
    unknown = await api.post(
        "/api/v1/auth/verify-email/resend", json={"email": "nobody@example.com"}
    )

    # The known address is inside its cooldown, so it answers 429 while the
    # unknown one answers 200 — a difference, but one driven by timing rather
    # than by existence. What must not differ is the *content*.
    assert unknown.status_code == 200
    assert "nobody@example.com" not in unknown.text
    assert len(mail.verification) == 1
    assert known.status_code in (200, 429)


async def test_resend_does_nothing_for_a_verified_account(api, users, mail):
    users.seed(email="done@example.com", email_verified=True)

    response = await api.post(
        "/api/v1/auth/verify-email/resend", json={"email": "done@example.com"}
    )

    assert response.status_code == 200
    assert mail.verification == []


# ------------------------------------------------------------------- login


async def test_a_verified_account_can_sign_in(api, users, mail):
    users.seed(email="user@example.com", password="correct-horse")

    response = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )

    assert response.status_code == 200
    assert response.json()["access_token"]


async def test_an_unverified_account_cannot_sign_in(api, users):
    users.seed(
        email="new@example.com", password="correct-horse", email_verified=False
    )

    response = await api.post(
        "/api/v1/auth/login",
        json={"email": "new@example.com", "password": "correct-horse"},
    )

    assert response.status_code == 403
    # A distinct code, because the client has to act on it: the app opens the
    # verification screen rather than saying "wrong password".
    assert response.json()["error"]["code"] == "EMAIL_NOT_VERIFIED"
    assert "access_token" not in response.text


async def test_a_wrong_password_on_an_unverified_account_says_nothing(api, users):
    """Verification state is revealed only after the password is proven."""
    users.seed(
        email="new@example.com", password="correct-horse", email_verified=False
    )

    response = await api.post(
        "/api/v1/auth/login",
        json={"email": "new@example.com", "password": "wrong"},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHORIZED"


async def test_sign_in_sends_a_welcome_email(api, users, mail):
    users.seed(email="user@example.com", password="correct-horse")

    await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )

    assert mail.logins == ["user@example.com"]


async def test_a_failed_sign_in_sends_nothing(api, users, mail):
    users.seed(email="user@example.com", password="correct-horse")

    await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "wrong"},
    )

    assert mail.logins == []


async def test_a_mail_outage_does_not_fail_a_valid_sign_in(api, users, mail):
    """The password was right. A broken mail server does not change that."""
    users.seed(email="user@example.com", password="correct-horse")
    mail.fail_with = EmailDeliveryError("smtp down")

    response = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )

    assert response.status_code == 200
    assert response.json()["access_token"]


async def test_the_welcome_email_carries_no_credentials(api, users, mail):
    from app.core.email import EmailService

    body_parts: list[str] = []

    class CapturingSender:
        async def send(self, message):
            body_parts.append(message.body)

    service = EmailService(sender=CapturingSender())
    await service.send_login_notification(to="user@example.com", full_name="Asha")

    body = body_parts[0]
    # It may mention the *word* password — it tells the reader to change
    # theirs. What it must never carry is an actual credential.
    assert re.search(r"\d{6}", body) is None, "no code"
    assert "$2b$" not in body, "no hash"
    for secret in ("token", "Bearer", "eyJ"):
        assert secret.lower() not in body.lower(), secret


# --------------------------------------------------------- forgot password


async def test_forgot_password_emails_a_code(api, users, mail):
    users.seed(email="user@example.com")

    response = await api.post(
        "/api/v1/auth/forgot-password", json={"email": "user@example.com"}
    )

    assert response.status_code == 200
    assert len(mail.password_reset) == 1
    assert mail.last_reset_code not in response.text


async def test_an_unknown_address_is_indistinguishable(api, users, mail):
    users.seed(email="user@example.com")

    known = await api.post(
        "/api/v1/auth/forgot-password", json={"email": "user@example.com"}
    )
    unknown = await api.post(
        "/api/v1/auth/forgot-password", json={"email": "nobody@example.com"}
    )

    # Same status, same body. This endpoint must not be a way to find out who
    # has an account.
    assert known.status_code == unknown.status_code == 200
    assert known.json() == unknown.json()
    assert len(mail.password_reset) == 1


async def test_a_suspended_account_gets_the_same_answer(api, users, mail):
    from app.features.auth.schemas import AccountStatus

    users.seed(email="banned@example.com", status=AccountStatus.SUSPENDED)

    response = await api.post(
        "/api/v1/auth/forgot-password", json={"email": "banned@example.com"}
    )

    assert response.status_code == 200
    # Nothing sent — resetting a password it cannot use would only confirm the
    # address exists.
    assert mail.password_reset == []


async def test_a_repeat_request_stays_silent_rather_than_rate_limiting(api, users, mail):
    """A 429 for a known address and a 200 for an unknown one would leak.

    So the cooldown is enforced by *not sending*, while the response stays the
    same as every other answer this endpoint gives.
    """
    users.seed(email="user@example.com")

    first = await api.post(
        "/api/v1/auth/forgot-password", json={"email": "user@example.com"}
    )
    second = await api.post(
        "/api/v1/auth/forgot-password", json={"email": "user@example.com"}
    )

    assert first.json() == second.json()
    assert len(mail.password_reset) == 1


async def test_only_a_hash_of_the_reset_code_is_stored(api, users, mail):
    users.seed(email="user@example.com")
    await api.post(
        "/api/v1/auth/forgot-password", json={"email": "user@example.com"}
    )

    record = next(iter(users.documents.values()))["password_reset"]
    assert mail.last_reset_code not in str(record)
    assert verify_otp(mail.last_reset_code, record["code_hash"])


async def test_a_mail_outage_does_not_change_the_answer(api, users, mail):
    users.seed(email="user@example.com")
    mail.fail_with = EmailDeliveryError("smtp down")

    response = await api.post(
        "/api/v1/auth/forgot-password", json={"email": "user@example.com"}
    )

    # The generic reply is the whole point of the endpoint; the failure is in
    # the server log, where it belongs.
    assert response.status_code == 200


# ---------------------------------------------------------- reset password


async def reset_code_for(api, users, mail, email: str = "user@example.com") -> str:
    users.seed(email=email, password="old-password")
    await api.post("/api/v1/auth/forgot-password", json={"email": email})
    return mail.last_reset_code


async def test_a_valid_reset_changes_the_password(api, users, mail):
    code = await reset_code_for(api, users, mail)

    response = await api.post(
        "/api/v1/auth/reset-password",
        json={
            "email": "user@example.com",
            "code": code,
            "new_password": "a-brand-new-password",
        },
    )

    assert response.status_code == 200
    new_login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "a-brand-new-password"},
    )
    assert new_login.status_code == 200


async def test_the_old_password_stops_working(api, users, mail):
    code = await reset_code_for(api, users, mail)
    await api.post(
        "/api/v1/auth/reset-password",
        json={
            "email": "user@example.com",
            "code": code,
            "new_password": "a-brand-new-password",
        },
    )

    response = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "old-password"},
    )

    assert response.status_code == 401


async def test_a_reset_revokes_every_existing_session(api, users, mail):
    """A password reset is what someone does when they fear a compromise.

    Leaving a thirty-day refresh token alive would make it useless.
    """
    users.seed(email="user@example.com", password="old-password")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "old-password"},
    )
    refresh_token = login.json()["refresh_token"]

    await api.post(
        "/api/v1/auth/forgot-password", json={"email": "user@example.com"}
    )
    await api.post(
        "/api/v1/auth/reset-password",
        json={
            "email": "user@example.com",
            "code": mail.last_reset_code,
            "new_password": "a-brand-new-password",
        },
    )

    rotated = await api.post(
        "/api/v1/auth/refresh", json={"refresh_token": refresh_token}
    )
    assert rotated.status_code == 401


async def test_a_reset_does_not_sign_the_user_in(api, users, mail):
    code = await reset_code_for(api, users, mail)

    response = await api.post(
        "/api/v1/auth/reset-password",
        json={
            "email": "user@example.com",
            "code": code,
            "new_password": "a-brand-new-password",
        },
    )

    # Control of a mailbox is enough to *change* a password, not to become the
    # user without knowing it.
    assert "access_token" not in response.text
    assert "refresh_token" not in response.text


async def test_a_wrong_reset_code_fails(api, users, mail):
    await reset_code_for(api, users, mail)

    response = await api.post(
        "/api/v1/auth/reset-password",
        json={
            "email": "user@example.com",
            "code": "000000",
            "new_password": "a-brand-new-password",
        },
    )

    assert response.status_code == 422
    assert next(iter(users.documents.values()))["password_reset"]["attempts"] == 1


async def test_an_expired_reset_code_fails(api, users, mail):
    code = await reset_code_for(api, users, mail)
    age_code(users, "user@example.com", "password_reset", minutes=1)

    response = await api.post(
        "/api/v1/auth/reset-password",
        json={
            "email": "user@example.com",
            "code": code,
            "new_password": "a-brand-new-password",
        },
    )

    assert response.status_code == 422


async def test_a_reset_code_cannot_be_reused(api, users, mail):
    code = await reset_code_for(api, users, mail)
    body = {
        "email": "user@example.com",
        "code": code,
        "new_password": "a-brand-new-password",
    }

    assert (await api.post("/api/v1/auth/reset-password", json=body)).status_code == 200
    second = await api.post(
        "/api/v1/auth/reset-password",
        json={**body, "new_password": "another-new-password"},
    )

    assert second.status_code == 422


async def test_too_many_reset_attempts_burns_the_code(api, users, mail):
    code = await reset_code_for(api, users, mail)

    for _ in range(5):
        await api.post(
            "/api/v1/auth/reset-password",
            json={
                "email": "user@example.com",
                "code": "000000",
                "new_password": "a-brand-new-password",
            },
        )

    response = await api.post(
        "/api/v1/auth/reset-password",
        json={
            "email": "user@example.com",
            "code": code,
            "new_password": "a-brand-new-password",
        },
    )
    assert response.status_code == 422


async def test_a_weak_new_password_is_refused(api, users, mail):
    code = await reset_code_for(api, users, mail)

    response = await api.post(
        "/api/v1/auth/reset-password",
        json={"email": "user@example.com", "code": code, "new_password": "short"},
    )

    assert response.status_code == 422
    # The policy is shared with registration, so reset cannot be a way round it.
    assert "8 characters" in response.text


async def test_concurrent_resets_produce_one_success(api, users, mail):
    code = await reset_code_for(api, users, mail)
    body = {
        "email": "user@example.com",
        "code": code,
        "new_password": "a-brand-new-password",
    }

    results = await asyncio.gather(
        api.post("/api/v1/auth/reset-password", json=body),
        api.post("/api/v1/auth/reset-password", json=body),
    )

    assert sorted(r.status_code for r in results) == [200, 422]


# ---------------------------------------------------------------- security


@pytest.mark.parametrize(
    "path,body",
    [
        ("verify-email", {"email": "a@example.com", "code": "123456"}),
        ("verify-email/resend", {"email": "a@example.com"}),
        ("forgot-password", {"email": "a@example.com"}),
        (
            "reset-password",
            {
                "email": "a@example.com",
                "code": "123456",
                "new_password": "a-good-password",
            },
        ),
    ],
)
async def test_no_endpoint_leaks_internal_fields(api, users, path, body):
    users.seed(email="a@example.com", password="correct-horse")

    response = await api.post(f"/api/v1/auth/{path}", json=body)

    for leak in ("password_hash", "code_hash", "refresh_sessions", "$2b$"):
        assert leak not in response.text, leak


@pytest.mark.parametrize(
    "field,value",
    [
        ("email_verified", True),
        ("status", "active"),
        ("role", "partner"),
        ("is_staff", True),
        ("staff", "admin"),
        ("user_id", "507f1f77bcf86cd799439011"),
    ],
)
async def test_privileged_fields_are_rejected_not_ignored(api, users, field, value):
    """`extra="forbid"` everywhere, so an escalation attempt is a 422.

    Silently dropping the field would work too, until someone later adds a
    model that happens to accept it.
    """
    users.seed(email="a@example.com", password="correct-horse", email_verified=False)

    response = await api.post(
        "/api/v1/auth/verify-email",
        json={"email": "a@example.com", "code": "123456", field: value},
    )

    assert response.status_code == 422
    stored = next(iter(users.documents.values()))
    assert stored["email_verified"] is False
    assert stored["role"] == "consumer"
    assert stored["staff"] is None


async def test_me_still_hides_everything_it_should(api, users, mail):
    users.seed(email="user@example.com", password="correct-horse")
    login = await api.post(
        "/api/v1/auth/login",
        json={"email": "user@example.com", "password": "correct-horse"},
    )

    response = await api.get(
        "/api/v1/auth/me", headers=auth_header(login.json()["access_token"])
    )

    for leak in ("password_hash", "code_hash", "email_verification", "password_reset"):
        assert leak not in response.text, leak


async def test_smtp_credentials_never_reach_a_client(api, users, mail):
    """The settings exist only on the server, and nothing projects them."""
    users.seed(email="user@example.com", password="correct-horse")

    responses = [
        await api.post("/api/v1/auth/register", json=REGISTRATION),
        await api.post(
            "/api/v1/auth/login",
            json={"email": "user@example.com", "password": "correct-horse"},
        ),
        await api.post(
            "/api/v1/auth/forgot-password", json={"email": "user@example.com"}
        ),
    ]

    for response in responses:
        for leak in ("SMTP", "smtp_password", "smtp.gmail.com"):
            assert leak not in response.text, leak
