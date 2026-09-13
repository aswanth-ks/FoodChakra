"""Authentication business logic.

The backend is the sole authority on identity, role and status. Every value
that decides what an account may do is set here from the stored record — never
from anything the client sent.
"""

import logging
from datetime import UTC, datetime, timedelta
from typing import Any

from bson import ObjectId
from pymongo.errors import DuplicateKeyError

from app.core.config import get_settings
from app.core.email import EmailError, EmailNotConfiguredError, EmailService
from app.core.exceptions import (
    ConflictError,
    EmailNotVerifiedError,
    ForbiddenError,
    ServiceUnavailableError,
    TooManyAttemptsError,
    UnauthorizedError,
    ValidationError,
)
from app.core.security import (
    TokenError,
    TokenType,
    create_access_token,
    create_refresh_token,
    decode_token,
    dummy_verify,
    generate_otp,
    hash_otp,
    hash_password,
    verify_otp,
    verify_password,
)
from app.features.auth.repository import UserRepository
from app.features.auth.schemas import (
    LOGIN_ALLOWED_STATUSES,
    AccountRole,
    AccountStatus,
    RegisterRequest,
    RegistrationResponse,
    TokenResponse,
    UserResponse,
)

logger = logging.getLogger(__name__)

#: Deliberately identical for "no such account" and "wrong password". Telling
#: the two apart hands an attacker a free account-enumeration oracle.
_INVALID_CREDENTIALS = "Invalid email or password."

#: Deliberately identical for a wrong code, an expired code and a code that was
#: never issued. Which of the three it was is not the caller's business, and
#: telling them apart helps only someone guessing.
_INVALID_CODE = "That code is not valid or has expired. Request a new one."


class AuthService:
    def __init__(
        self,
        repository: UserRepository,
        email: EmailService | None = None,
    ) -> None:
        self._repository = repository
        self._email = email or EmailService()
        self._settings = get_settings()

    # -------------------------------------------------------- registration

    async def register(
        self, payload: RegisterRequest
    ) -> RegistrationResponse:
        """Create a consumer account.

        `role`, `status` and staff access are assigned here as constants. They
        are not read from the request — `RegisterRequest` has no such fields —
        so there is no code path by which a public caller creates a partner or
        a staff member, whatever they post.
        """
        email = payload.email.strip().lower()
        now = datetime.now(UTC)

        document: dict[str, Any] = {
            "email": email,
            "password_hash": hash_password(payload.password),
            "full_name": payload.full_name,
            # Hardcoded, not client-supplied. This is the whole guarantee.
            "role": AccountRole.CONSUMER.value,
            "status": AccountStatus.ACTIVE.value,
            "email_verified": False,
            "staff": None,
            "partner_id": None,
            "refresh_sessions": [],
            "created_at": now,
            "updated_at": now,
            "last_login_at": None,
        }

        try:
            stored = await self._repository.create(document)
        except DuplicateKeyError as exc:
            # The `uniq_email` index is the real check. A read-then-insert
            # would let two simultaneous registrations both pass.
            raise ConflictError("An account with this email already exists.") from exc

        # No tokens. The account exists but the address is unproven, and
        # issuing a session here would make verification optional in practice
        # whatever the login rule says. The client goes to the code screen.
        await self._issue_verification_code(stored)

        return RegistrationResponse(
            message=(
                "Account created. Check your email for a 6-digit "
                "verification code."
            ),
            email=email,
            expires_in_minutes=self._settings.OTP_EXPIRE_MINUTES,
        )

    # -------------------------------------------------- email verification

    async def _issue_verification_code(self, stored: dict[str, Any]) -> None:
        """Generate, store and send a verification code.

        Order matters. The hash is written *before* the send, so a code that
        reaches someone's inbox is always one the database will accept -- the
        reverse order can email a code that was never stored.
        """
        code = generate_otp()
        await self._repository.set_email_verification(
            stored["_id"],
            code_hash=hash_otp(code),
            expires_at=self._code_expiry(),
        )
        await self._deliver(
            self._email.send_verification_otp(
                to=stored["email"],
                full_name=stored.get("full_name", ""),
                code=code,
            )
        )

    async def verify_email(self, email: str, code: str) -> None:
        """Confirm an address with a one-time code.

        The account is found from the email plus the code. Nothing the client
        sends can name a *different* account, set `email_verified` directly, or
        alter status or role.
        """
        stored = await self._repository.find_by_email(email)
        record = (stored or {}).get("email_verification")

        if stored is None or not record:
            # Including the "already verified" case: re-running the flow with a
            # stale code must not confirm that the account exists.
            raise ValidationError(_INVALID_CODE)

        if self._expired(record):
            await self._repository.clear_email_verification(stored["_id"])
            raise ValidationError(_INVALID_CODE)

        if not verify_otp(code, record["code_hash"]):
            await self._register_failed_attempt(
                stored["_id"],
                self._repository.count_verification_attempt,
                self._repository.clear_email_verification,
            )
            raise ValidationError(_INVALID_CODE)

        # Conditional on the code hash still being present, so two requests
        # carrying the same correct code produce exactly one success.
        won = await self._repository.complete_email_verification(
            stored["_id"], code_hash=record["code_hash"]
        )
        if not won:
            raise ValidationError(_INVALID_CODE)

    async def resend_verification(self, email: str) -> None:
        """Issue a fresh code, invalidating the previous one.

        Silent about whether the address is registered or already verified, for
        the same reason `forgot-password` is: the caller is unauthenticated.
        """
        stored = await self._repository.find_by_email(email)
        if stored is None or stored.get("email_verified"):
            return

        self._assert_not_too_soon(stored.get("email_verification"))
        await self._issue_verification_code(stored)

    # ------------------------------------------------------ password reset

    async def forgot_password(self, email: str) -> None:
        """Send a reset code, if and only if there is an eligible account.

        Returns None in every case. The caller sends the same message either
        way, so nothing about the address leaks -- not existence, not status,
        not role.
        """
        stored = await self._repository.find_by_email(email)
        if stored is None:
            return
        if AccountStatus(stored.get("status", "")) not in LOGIN_ALLOWED_STATUSES:
            # A suspended account cannot sign in, so resetting its password
            # would achieve nothing except telling the sender it exists.
            return

        try:
            self._assert_not_too_soon(stored.get("password_reset"))
        except TooManyAttemptsError:
            # Swallowed on purpose: a 429 here, when an unknown address gets a
            # 200, would say "this address is registered and asked recently".
            return

        code = generate_otp()
        await self._repository.set_password_reset(
            stored["_id"],
            code_hash=hash_otp(code),
            expires_at=self._code_expiry(),
        )
        try:
            await self._deliver(
                self._email.send_password_reset_otp(
                    to=stored["email"],
                    full_name=stored.get("full_name", ""),
                    code=code,
                )
            )
        except ServiceUnavailableError:
            # Also swallowed. The generic answer is the whole point of this
            # endpoint, and a delivery failure is visible in the server logs.
            logger.warning("Password reset email could not be delivered")

    async def reset_password(
        self, email: str, code: str, new_password: str
    ) -> None:
        """Set a new password with a valid reset code.

        No session is issued. Proving control of the mailbox is enough to
        *change* the password; signing in still requires knowing it, which is
        what keeps a stolen inbox from being a silent account takeover.
        """
        stored = await self._repository.find_by_email(email)
        record = (stored or {}).get("password_reset")

        if stored is None or not record:
            raise ValidationError(_INVALID_CODE)

        if self._expired(record):
            await self._repository.clear_password_reset(stored["_id"])
            raise ValidationError(_INVALID_CODE)

        if not verify_otp(code, record["code_hash"]):
            await self._register_failed_attempt(
                stored["_id"],
                self._repository.count_reset_attempt,
                self._repository.clear_password_reset,
            )
            raise ValidationError(_INVALID_CODE)

        # One conditional write sets the password, consumes the code and
        # revokes every refresh session -- see the repository for why those
        # cannot be three separate calls.
        won = await self._repository.complete_password_reset(
            stored["_id"],
            code_hash=record["code_hash"],
            password_hash=hash_password(new_password),
        )
        if not won:
            raise ValidationError(_INVALID_CODE)

    # ------------------------------------------------- one-time code rules

    def _code_expiry(self) -> datetime:
        return datetime.now(UTC) + timedelta(
            minutes=self._settings.OTP_EXPIRE_MINUTES
        )

    @staticmethod
    def _expired(record: dict[str, Any]) -> bool:
        expires_at = record.get("expires_at")
        if expires_at is None:
            return True
        if expires_at.tzinfo is None:
            # Mongo hands back naive UTC datetimes.
            expires_at = expires_at.replace(tzinfo=UTC)
        return expires_at <= datetime.now(UTC)

    def _assert_not_too_soon(self, record: dict[str, Any] | None) -> None:
        """Enforce the gap between two code emails to one address.

        Without it, one address is an unlimited outbound mail generator --
        annoying for its owner and, if the address belongs to someone else, a
        way to use FoodLoop to harass them.
        """
        if not record:
            return
        sent_at = record.get("sent_at")
        if sent_at is None:
            return
        if sent_at.tzinfo is None:
            sent_at = sent_at.replace(tzinfo=UTC)
        cooldown = timedelta(seconds=self._settings.OTP_RESEND_COOLDOWN_SECONDS)
        if datetime.now(UTC) - sent_at < cooldown:
            raise TooManyAttemptsError(
                "A code was sent recently. Wait a moment before asking again."
            )

    async def _register_failed_attempt(
        self, user_id: ObjectId, counter, clearer
    ) -> None:
        """Count a wrong guess and burn the code once the cap is reached.

        Six digits is a million possibilities, which sounds ample until an
        automated client tries a few thousand a second. The cap, not the
        length, is what makes guessing impractical.
        """
        attempts = await counter(user_id)
        if attempts >= self._settings.OTP_MAX_ATTEMPTS:
            await clearer(user_id)

    async def _deliver(self, coroutine) -> None:
        """Await a send and convert its failures into an API error.

        The distinction is kept: a missing configuration is an operator problem
        and a delivery failure is usually transient. Neither is ever reported
        to the client as a success.
        """
        try:
            await coroutine
        except EmailNotConfiguredError as exc:
            logger.error("Email is not configured; no message was sent")
            raise ServiceUnavailableError(
                "Email delivery is not configured on this server. "
                "No code was sent."
            ) from exc
        except EmailError as exc:
            raise ServiceUnavailableError(
                "We could not send the email just now. Please try again."
            ) from exc

    # --------------------------------------------------------------- login

    async def login(self, email: str, password: str) -> TokenResponse:
        stored = await self._repository.find_by_email(email)

        if stored is None:
            # Spend the same time a real verification would, so a missing
            # account is not distinguishable by response time.
            dummy_verify()
            raise UnauthorizedError(_INVALID_CREDENTIALS)

        if not verify_password(password, stored.get("password_hash", "")):
            raise UnauthorizedError(_INVALID_CREDENTIALS)

        # Status is checked only after the password is proven correct.
        # Answering "this account is suspended" to an unauthenticated caller
        # would confirm the address exists.
        self._assert_may_login(stored)

        # Same ordering rule: only someone who has already proven the password
        # learns that the address is unverified.
        if not stored.get("email_verified", False):
            raise EmailNotVerifiedError()

        now = datetime.now(UTC)
        await self._repository.record_login(stored["_id"], now)
        stored["last_login_at"] = now

        return await self._issue_tokens(stored)

    async def send_login_notification(self, user: UserResponse) -> None:
        """Best effort, and never on the request's critical path.

        Scheduled as a background task by the router *after* the tokens are
        returned. A mail server outage must not turn a correct password into a
        failed sign-in, so every failure is logged and swallowed here.
        """
        try:
            await self._email.send_login_notification(
                to=user.email, full_name=user.full_name
            )
        except EmailError as exc:
            logger.warning(
                "Login notification not delivered (%s)", type(exc).__name__
            )

    def _assert_may_login(self, stored: dict[str, Any]) -> None:
        status = AccountStatus(stored.get("status", AccountStatus.DISABLED.value))
        if status not in LOGIN_ALLOWED_STATUSES:
            raise ForbiddenError(
                "This account is not active. Contact support for help."
            )

    # ------------------------------------------------------------- refresh

    async def refresh(self, refresh_token: str) -> TokenResponse:
        """Rotate a refresh token.

        Rotation is single-use: the old jti is consumed atomically. If it is
        already gone the token is a replay — which means it was captured — so
        every session for that account is revoked rather than just refusing
        this one request.
        """
        try:
            payload = decode_token(refresh_token, expected_type=TokenType.REFRESH)
        except TokenError as exc:
            raise UnauthorizedError("Invalid or expired session.") from exc

        stored = await self._repository.find_by_id(payload["sub"])
        if stored is None:
            raise UnauthorizedError("Invalid or expired session.")

        consumed = await self._repository.consume_refresh_session(
            stored["_id"], payload["jti"]
        )
        if not consumed:
            logger.warning(
                "Refresh token replay detected for user %s — revoking all sessions",
                stored["_id"],
            )
            await self._repository.revoke_all_refresh_sessions(stored["_id"])
            raise UnauthorizedError("Invalid or expired session.")

        # Re-checked on every rotation: an account suspended after signing in
        # must not keep minting access tokens for the next thirty days.
        self._assert_may_login(stored)

        return await self._issue_tokens(stored)

    # ------------------------------------------------------------- profile

    async def update_profile(self, user_id: str, *, full_name: str) -> UserResponse:
        """Rename the caller's own account.

        `user_id` comes from the verified token, never from a request body, so
        there is no shape of request that can name somebody else's account.
        """
        stored = await self._repository.find_by_id(user_id)
        if stored is None:
            raise UnauthorizedError("Invalid or expired session.")

        updated = await self._repository.update_full_name(
            stored["_id"], full_name
        )
        if updated is None:
            raise UnauthorizedError("Invalid or expired session.")

        return self.to_response(updated)

    async def change_password(
        self, user_id: str, *, current_password: str, new_password: str
    ) -> None:
        """Replace the password for someone who can prove they know it.

        Knowing the current password is the proof. Without that check an
        unlocked phone left on a table would be enough to take an account over
        permanently, which is a bigger hole than any of this is worth.

        Every refresh session is revoked, so a password change actually ends
        the other sessions rather than only appearing to.
        """
        stored = await self._repository.find_by_id(user_id)
        if stored is None:
            raise UnauthorizedError("Invalid or expired session.")

        if not verify_password(current_password, stored["password_hash"]):
            # Deliberately not "wrong password" vs "no such account": the
            # caller is already authenticated, so the only useful distinction
            # is whether this attempt was right.
            raise UnauthorizedError("Your current password is incorrect.")

        if verify_password(new_password, stored["password_hash"]):
            raise ValidationError("Choose a password you have not used here.")

        changed = await self._repository.change_password(
            stored["_id"], password_hash=hash_password(new_password)
        )
        if not changed:
            raise UnauthorizedError("Invalid or expired session.")

    # -------------------------------------------------------------- logout

    async def logout(self, user_id: str, refresh_token: str | None) -> None:
        """Revoke one session, or all of them when no token is given.

        Never raises for a bad token: signing out must always appear to
        succeed, or a client can be stuck unable to clear its own session.
        """
        stored = await self._repository.find_by_id(user_id)
        if stored is None:
            return

        if refresh_token is None:
            await self._repository.revoke_all_refresh_sessions(stored["_id"])
            return

        try:
            payload = decode_token(refresh_token, expected_type=TokenType.REFRESH)
        except TokenError:
            return
        if payload["sub"] == user_id:
            await self._repository.consume_refresh_session(
                stored["_id"], payload["jti"]
            )

    # ---------------------------------------------------------- current user

    async def user_for_access_token(self, token: str) -> UserResponse:
        """Resolve a bearer token to the *current* stored user.

        The record is re-read on every request rather than trusting the
        token's claims. That costs one indexed lookup and buys correctness:
        a suspension, a role change or a deletion takes effect immediately
        instead of lingering until the access token expires.
        """
        try:
            payload = decode_token(token, expected_type=TokenType.ACCESS)
        except TokenError as exc:
            raise UnauthorizedError("Invalid or expired credentials.") from exc

        stored = await self._repository.find_by_id(payload["sub"])
        if stored is None:
            raise UnauthorizedError("Invalid or expired credentials.")

        self._assert_may_login(stored)
        return self.to_response(stored)

    # ------------------------------------------------------------- helpers

    async def _issue_tokens(self, stored: dict[str, Any]) -> TokenResponse:
        user = self.to_response(stored)
        access_token, expires_at = create_access_token(
            user_id=user.id, role=user.role.value, is_staff=user.is_staff
        )
        refresh_token, jti, refresh_expires_at = create_refresh_token(user_id=user.id)
        await self._repository.add_refresh_session(
            stored["_id"], jti=jti, expires_at=refresh_expires_at
        )
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_at=expires_at,
            user=user,
        )

    @staticmethod
    def to_response(stored: dict[str, Any]) -> UserResponse:
        """Project a stored document onto the safe response shape.

        Fields are listed explicitly. `password_hash` and `refresh_sessions`
        have no route into a response because nothing here reads them.
        """
        partner_id = stored.get("partner_id")
        return UserResponse(
            id=str(stored["_id"]),
            email=stored["email"],
            full_name=stored["full_name"],
            role=AccountRole(stored["role"]),
            status=AccountStatus(stored["status"]),
            email_verified=bool(stored.get("email_verified", False)),
            is_staff=stored.get("staff") is not None,
            partner_id=str(partner_id) if partner_id is not None else None,
            created_at=stored["created_at"],
            last_login_at=stored.get("last_login_at"),
        )
