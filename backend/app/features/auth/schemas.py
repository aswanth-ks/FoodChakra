"""Authentication wire contract.

Three kinds of model, kept apart on purpose:

* `*Request`  — what a client may send. Anything absent here is unsettable.
* `*Response` — what a client may see. `password_hash` appears in none of them.
* `UserDocument` — the stored shape, never returned directly.

Mixing the three is how hashes leak into responses and how clients acquire
fields they should not control.
"""

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.core.security import MAX_PASSWORD_BYTES, MIN_PASSWORD_LENGTH


class AccountRole(StrEnum):
    """What kind of account this is. Matches the built product, not the plan.

    Only two, because the app only has two (`docs/BACKEND_CONTRACT.md` §0): a
    consumer both rescues and shares, and a partner is a business. There is no
    volunteer, donor or receiver role.

    Operations staff are deliberately **not** a role here — see `StaffLevel`.
    """

    CONSUMER = "consumer"
    PARTNER = "partner"


class StaffLevel(StrEnum):
    """Internal console access, modelled as a capability rather than a role.

    Ops access is orthogonal to what kind of account someone holds: an
    operator still signs in, and may well also be a consumer who rescues food
    at the weekend. Making `ops_admin` a third value of `AccountRole` would
    force that person into one or the other and would put console permissions
    on the same axis as "is this a business" — two unrelated questions sharing
    one field is how privilege bugs happen.

    So `role` answers "what kind of account", and this optional field answers
    "may they open the operations console". Absent for every ordinary user.
    """

    OPERATOR = "operator"
    ADMIN = "admin"


class AccountStatus(StrEnum):
    """Backend-controlled. No client may set or change it."""

    ACTIVE = "active"
    SUSPENDED = "suspended"
    DISABLED = "disabled"


#: Only `ACTIVE` accounts may authenticate. Suspended and disabled accounts
#: hold valid credentials that must still be refused.
LOGIN_ALLOWED_STATUSES: frozenset[AccountStatus] = frozenset({AccountStatus.ACTIVE})


# ---------------------------------------------------------------- requests


class RegisterRequest(BaseModel):
    """Public registration.

    There is deliberately no `role`, `status`, `staff` or `partner_id` field.
    Not "ignored if sent" — absent from the model, so `extra="forbid"` rejects
    the request outright rather than silently dropping a privilege escalation
    attempt. Public registration can only ever produce an active consumer.
    """

    model_config = ConfigDict(extra="forbid")

    full_name: str = Field(min_length=1, max_length=120)
    email: EmailStr
    password: str

    @field_validator("password")
    @classmethod
    def _check_password(cls, value: str) -> str:
        # bcrypt silently ignores bytes past 72; rejecting is the honest
        # option, since truncation would let two passwords open one account.
        return _validate_password(value)

    @field_validator("full_name")
    @classmethod
    def _strip_name(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("Full name is required.")
        return stripped


class LoginRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr
    #: No length rules on login. Enforcing them here would reject a legitimate
    #: older password and, worse, reveal the current policy to an attacker.
    password: str


class RefreshRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    refresh_token: str


def _validate_password(value: str) -> str:
    """The one password policy, shared by registration and reset.

    Duplicating it would let the two drift, and a reset path with weaker
    rules than sign-up is a way round the policy rather than a convenience.
    """
    if len(value) < MIN_PASSWORD_LENGTH:
        raise ValueError(
            f"Password must be at least {MIN_PASSWORD_LENGTH} characters."
        )
    if len(value.encode("utf-8")) > MAX_PASSWORD_BYTES:
        raise ValueError(f"Password must be at most {MAX_PASSWORD_BYTES} bytes.")
    return value


class OtpCode(BaseModel):
    """Shared shape for the two code-bearing requests.

    The code is constrained to exactly six digits at the edge, so a malformed
    guess is rejected before it can consume one of the account's attempts.
    """

    model_config = ConfigDict(extra="forbid")

    email: EmailStr
    code: str = Field(pattern=r"^\d{6}$")


class VerifyEmailRequest(OtpCode):
    """Identity comes from the email plus the code, never from a client id."""


class ResendVerificationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr


class ForgotPasswordRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    email: EmailStr


class ResetPasswordRequest(OtpCode):
    new_password: str

    @field_validator("new_password")
    @classmethod
    def _check_password(cls, value: str) -> str:
        return _validate_password(value)


# --------------------------------------------------------------- responses


class UserResponse(BaseModel):
    """The safe projection of a user. The only user shape any client sees.

    Built explicitly field by field from the stored document rather than by
    excluding secrets from it — an allowlist stays safe when someone later
    adds a field to the document, whereas a denylist quietly starts leaking.
    """

    id: str
    email: EmailStr
    full_name: str
    role: AccountRole
    status: AccountStatus
    email_verified: bool
    #: True when the account may open the operations console. The level itself
    #: is not exposed — clients only need to know whether the door opens.
    is_staff: bool = False
    partner_id: str | None = None
    created_at: datetime
    last_login_at: datetime | None = None


class MessageResponse(BaseModel):
    """A plain acknowledgement.

    Carries no account information at all. `forgot-password` returns exactly
    this whether or not the address is registered, so the response cannot be
    used to discover who has an account.
    """

    message: str


class RegistrationResponse(BaseModel):
    """The answer to a successful sign-up.

    Deliberately **not** a `TokenResponse`. The account exists but its address
    is unproven, so no session is issued: handing over tokens here would make
    verification optional in practice, whatever the login rule says.
    """

    message: str
    email: EmailStr
    #: Lets the client show an accurate countdown instead of guessing.
    expires_in_minutes: int


class TokenResponse(BaseModel):
    """Issued by login and refresh."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_at: datetime
    user: UserResponse
