"""Password hashing and JWT issuing/verification.

All cryptography lives here. No other module imports `bcrypt` or `jwt` — that
containment is what makes "are we hashing correctly?" a question with one place
to look, and what lets the algorithm change without touching a service.

Nothing in this module logs, and nothing in it returns a password or a hash in
a string representation, so a stray log line cannot leak one.
"""

import secrets
from datetime import UTC, datetime, timedelta
from enum import StrEnum
from typing import Any
from uuid import uuid4

import bcrypt
import jwt
from jwt import ExpiredSignatureError, InvalidTokenError

from app.core.config import get_settings

#: bcrypt hashes at most 72 bytes and raises on longer input. Rejecting the
#: password at validation time is the honest option: silently truncating means
#: two different passwords can unlock the same account.
MAX_PASSWORD_BYTES = 72

#: Below this, a password is guessable enough that the hashing cost is wasted.
MIN_PASSWORD_LENGTH = 8


class TokenType(StrEnum):
    """Access and refresh tokens are not interchangeable.

    The type is a claim, and verification demands the expected one. Without it
    a refresh token — long-lived by design — would be accepted as an access
    token, quietly turning a 30-minute exposure window into a 30-day one.
    """

    ACCESS = "access"
    REFRESH = "refresh"


# --------------------------------------------------------------- passwords


def hash_password(password: str) -> str:
    """Hash a plaintext password with bcrypt (per-hash random salt)."""
    encoded = password.encode("utf-8")
    if len(encoded) > MAX_PASSWORD_BYTES:
        raise ValueError("Password exceeds the maximum supported length.")
    return bcrypt.hashpw(encoded, bcrypt.gensalt(rounds=12)).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    """Constant-time verification. Returns False rather than raising.

    A malformed or empty stored hash must not blow up the login path: it
    should simply fail to match, the same as a wrong password.
    """
    try:
        return bcrypt.checkpw(
            password.encode("utf-8"), password_hash.encode("utf-8")
        )
    except (ValueError, TypeError):
        return False


#: A real hash at the production cost factor, generated once at import against
#: a value nothing can log in with. Computed rather than hardcoded so it can
#: never drift out of sync with `hash_password`'s cost — and so a typo in a
#: literal cannot turn the timing defence into an exception on the login path.
_DUMMY_HASH: bytes = bcrypt.hashpw(uuid4().hex.encode("utf-8"), bcrypt.gensalt(rounds=12))


def dummy_verify() -> None:
    """Burn roughly one bcrypt verification's worth of time.

    Called when login finds no user. Without it, a missing account answers
    much faster than a wrong password, and that timing difference alone tells
    an attacker which email addresses are registered — the exact thing the
    deliberately vague "Invalid email or password" message exists to hide.
    """
    bcrypt.checkpw(b"timing-equalisation", _DUMMY_HASH)


# ---------------------------------------------------------- handover codes

#: Digits in a handover code. Six, per `docs/BACKEND_CONTRACT.md` §3.4.
HANDOVER_CODE_LENGTH = 6


def generate_handover_code() -> str:
    """A cryptographically random 6-digit handover code.

    `secrets`, not `random`: the latter is seeded predictably and its output
    can be reconstructed from earlier values, which for a code that authorises
    a handover would be a real weakness.
    """
    upper = 10**HANDOVER_CODE_LENGTH
    return str(secrets.randbelow(upper)).zfill(HANDOVER_CODE_LENGTH)


def hash_handover_code(code: str) -> str:
    """Hash a handover code for storage.

    Only the hash is ever stored, so a database dump does not hand an attacker
    live codes. Be honest about the limit, though: six digits is about 20 bits,
    so an offline attacker who steals the hash can exhaust the space regardless
    of the cost factor. The hash reduces exposure; the protections that
    actually make the code safe are elsewhere — a short expiry, a hard attempt
    cap, single use, and the lifecycle-state guard on the transition itself.
    """
    return bcrypt.hashpw(code.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode(
        "utf-8"
    )


def verify_handover_code(code: str, code_hash: str) -> bool:
    """Constant-time comparison. False rather than raising on a bad hash."""
    try:
        return bcrypt.checkpw(code.encode("utf-8"), code_hash.encode("utf-8"))
    except (ValueError, TypeError):
        return False


# ------------------------------------------------------- one-time codes

#: Digits in an email verification or password-reset code.
OTP_LENGTH = 6


def generate_otp() -> str:
    """A cryptographically random 6-digit one-time code.

    `secrets.randbelow`, never `random`: the standard PRNG is seeded
    predictably and its stream can be reconstructed from a few earlier
    outputs, which for a code that verifies an identity or authorises a
    password change would be a real weakness.

    `zfill` matters — without it one code in ten would be five digits, and a
    shorter code is a smaller search space.
    """
    return str(secrets.randbelow(10**OTP_LENGTH)).zfill(OTP_LENGTH)


def hash_otp(code: str) -> str:
    """Hash a one-time code for storage. Plaintext is never persisted.

    The same honest caveat as `hash_handover_code`: six digits is about twenty
    bits, so an attacker holding the hash can exhaust it offline whatever the
    cost factor. What actually protects the code is everything around it — a
    ten-minute expiry, a hard attempt cap, single use, and invalidation as
    soon as a newer code is issued.
    """
    return bcrypt.hashpw(code.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode(
        "utf-8"
    )


def verify_otp(code: str, code_hash: str) -> bool:
    """Constant-time comparison. False rather than raising on a bad hash."""
    try:
        return bcrypt.checkpw(code.encode("utf-8"), code_hash.encode("utf-8"))
    except (ValueError, TypeError):
        return False


# ------------------------------------------------------------------ tokens


def _create_token(
    *,
    subject: str,
    token_type: TokenType,
    expires_delta: timedelta,
    extra_claims: dict[str, Any] | None = None,
) -> tuple[str, str, datetime]:
    """Sign a JWT. Returns (token, jti, expiry)."""
    settings = get_settings()
    now = datetime.now(UTC)
    expires_at = now + expires_delta
    jti = uuid4().hex

    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type.value,
        "jti": jti,
        "iat": now,
        "exp": expires_at,
    }
    if extra_claims:
        payload.update(extra_claims)

    token = jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALGORITHM)
    return token, jti, expires_at


def create_access_token(
    *, user_id: str, role: str, is_staff: bool = False
) -> tuple[str, datetime]:
    """Short-lived token carrying identity and role.

    The role is included so ordinary authorization needs no database round
    trip. It is **not** a source of truth: it was written by this server from
    the user record, and anything irreversible re-reads the record. Nothing
    sensitive goes in the payload — a JWT is signed, not encrypted, and any
    holder can read it.
    """
    settings = get_settings()
    token, _, expires_at = _create_token(
        subject=user_id,
        token_type=TokenType.ACCESS,
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        extra_claims={"role": role, "staff": is_staff},
    )
    return token, expires_at


def create_refresh_token(*, user_id: str) -> tuple[str, str, datetime]:
    """Long-lived token used only to mint access tokens.

    Deliberately carries no role: a refresh token outlives role changes, so
    trusting a role claim from one would let a demoted account keep its old
    permissions for up to thirty days. Returns (token, jti, expiry) — the jti
    is recorded on the user so the session can be revoked.
    """
    settings = get_settings()
    return _create_token(
        subject=user_id,
        token_type=TokenType.REFRESH,
        expires_delta=timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
    )


class TokenError(Exception):
    """Raised when a token is missing, malformed, expired, or the wrong type."""


def decode_token(token: str, *, expected_type: TokenType) -> dict[str, Any]:
    """Verify a JWT's signature, expiry and type. Raises `TokenError`.

    Callers get one exception type regardless of what was wrong with the
    token, so no endpoint can accidentally tell a client *why* verification
    failed.
    """
    settings = get_settings()
    try:
        payload: dict[str, Any] = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[settings.JWT_ALGORITHM],
            options={"require": ["exp", "sub", "jti", "type"]},
        )
    except ExpiredSignatureError as exc:
        raise TokenError("Token has expired.") from exc
    except InvalidTokenError as exc:
        raise TokenError("Token is invalid.") from exc

    if payload.get("type") != expected_type.value:
        raise TokenError("Token is not valid for this operation.")

    return payload
