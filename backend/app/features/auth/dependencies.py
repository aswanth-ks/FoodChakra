"""Reusable authentication and authorization dependencies.

Every protected endpoint in FoodLoop declares its requirement here rather than
re-checking a role in its body. One implementation means one place to audit,
and a route physically cannot forget the check — the dependency is in its
signature.

    get_current_user   authenticated, active account
    require_consumer   consumer-only endpoints
    require_partner    partner-only endpoints
    require_staff      operations console endpoints
"""

from typing import Annotated

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.core.email import EmailService, get_email_service
from app.core.exceptions import ForbiddenError, UnauthorizedError
from app.db.mongo import get_db
from app.features.auth.repository import UserRepository
from app.features.auth.schemas import AccountRole, UserResponse
from app.features.auth.service import AuthService

#: `auto_error=False` so a missing header raises our own `UnauthorizedError`
#: and returns the standard envelope, rather than FastAPI's bare 403 shape.
_bearer = HTTPBearer(auto_error=False)


def get_auth_service(
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
    email: Annotated[EmailService, Depends(get_email_service)],
) -> AuthService:
    """Injected rather than constructed, so tests can substitute a recording
    double at the boundary and never touch a real mail server."""
    return AuthService(UserRepository(db), email)


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
    service: Annotated[AuthService, Depends(get_auth_service)],
) -> UserResponse:
    """The authenticated, active user behind the bearer token.

    The token is only an assertion of identity; the role and status attached
    to the returned user come from the database on every request.
    """
    if credentials is None or not credentials.credentials:
        raise UnauthorizedError("Authentication is required.")
    return await service.user_for_access_token(credentials.credentials)


CurrentUser = Annotated[UserResponse, Depends(get_current_user)]


def require_role(*allowed: AccountRole):
    """Build a dependency admitting only the given account roles."""

    async def dependency(user: CurrentUser) -> UserResponse:
        if user.role not in allowed:
            raise ForbiddenError(
                "You do not have permission to perform this action."
            )
        return user

    return dependency


require_consumer = require_role(AccountRole.CONSUMER)
require_partner = require_role(AccountRole.PARTNER)


async def require_staff(user: CurrentUser) -> UserResponse:
    """Operations console access.

    Checked independently of `role`, because staff access is a capability
    rather than an account type — an operator may hold a consumer account and
    still need the console. See `StaffLevel` for why the two are kept apart.
    """
    if not user.is_staff:
        raise ForbiddenError("Operations access is required.")
    return user
