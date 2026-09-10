"""Authentication routes.

HTTP wiring only — no business logic, no driver access. Every rule about who
may do what lives in `service.py` and `dependencies.py`.
"""

from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, status

from app.features.auth.dependencies import CurrentUser, get_auth_service
from app.features.auth.schemas import (
    ForgotPasswordRequest,
    LoginRequest,
    MessageResponse,
    RefreshRequest,
    RegisterRequest,
    RegistrationResponse,
    ResendVerificationRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserResponse,
    VerifyEmailRequest,
)
from app.features.auth.service import AuthService

router = APIRouter(prefix="/auth", tags=["auth"])

ServiceDep = Annotated[AuthService, Depends(get_auth_service)]


@router.post(
    "/register",
    response_model=RegistrationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a consumer account",
    description=(
        "Public registration. Always creates an active **consumer** — role, "
        "status and staff access cannot be set by the caller. Partner "
        "accounts are provisioned through the operations console.\n\n"
        "Returns **no tokens**: the account is created unverified and a "
        "6-digit code is emailed. Call `/auth/verify-email`, then `/auth/login`."
    ),
)
async def register(
    payload: RegisterRequest, service: ServiceDep
) -> RegistrationResponse:
    return await service.register(payload)


@router.post(
    "/verify-email",
    response_model=MessageResponse,
    summary="Confirm an email address with a 6-digit code",
    description=(
        "Single use. The code expires, is capped at a small number of "
        "attempts, and is invalidated as soon as a newer one is issued."
    ),
)
async def verify_email(
    payload: VerifyEmailRequest, service: ServiceDep
) -> MessageResponse:
    await service.verify_email(payload.email, payload.code)
    return MessageResponse(message="Email verified. You can now sign in.")


@router.post(
    "/verify-email/resend",
    response_model=MessageResponse,
    summary="Send a fresh verification code",
    description=(
        "Invalidates the previous code. Answers the same way whether or not "
        "the address is registered, so it cannot be used to discover accounts."
    ),
)
async def resend_verification(
    payload: ResendVerificationRequest, service: ServiceDep
) -> MessageResponse:
    await service.resend_verification(payload.email)
    return MessageResponse(
        message="If that account still needs verifying, a new code is on its way."
    )


@router.post(
    "/forgot-password",
    response_model=MessageResponse,
    summary="Request a password reset code",
    description=(
        "Always answers identically, registered address or not. Anything else "
        "would make this endpoint an account-enumeration oracle."
    ),
)
async def forgot_password(
    payload: ForgotPasswordRequest, service: ServiceDep
) -> MessageResponse:
    await service.forgot_password(payload.email)
    # One message for every address, registered or not.
    return MessageResponse(
        message=(
            "If that email address has a FoodLoop account, a reset code is "
            "on its way."
        )
    )


@router.post(
    "/reset-password",
    response_model=MessageResponse,
    summary="Set a new password with a reset code",
    description=(
        "Revokes every existing session on success. No tokens are issued: the "
        "user signs in again with the new password."
    ),
)
async def reset_password(
    payload: ResetPasswordRequest, service: ServiceDep
) -> MessageResponse:
    await service.reset_password(
        payload.email, payload.code, payload.new_password
    )
    return MessageResponse(
        message="Password updated. Sign in with your new password."
    )


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Exchange credentials for tokens",
    description=(
        "Requires a verified email address; an unverified account is refused "
        "with `EMAIL_NOT_VERIFIED`. A confirmation email is sent afterwards, "
        "in the background — mail trouble never fails a valid sign-in."
    ),
)
async def login(
    payload: LoginRequest,
    service: ServiceDep,
    background: BackgroundTasks,
) -> TokenResponse:
    tokens = await service.login(payload.email, payload.password)
    # Scheduled, not awaited. The response is already correct at this point,
    # and a slow mail server must not hold it open.
    background.add_task(service.send_login_notification, tokens.user)
    return tokens


@router.post(
    "/refresh",
    response_model=TokenResponse,
    summary="Rotate a refresh token",
)
async def refresh(payload: RefreshRequest, service: ServiceDep) -> TokenResponse:
    return await service.refresh(payload.refresh_token)


@router.post(
    "/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Revoke the current session",
    description=(
        "Revokes the supplied refresh token, or every session for the account "
        "when no token is given."
    ),
)
async def logout(
    user: CurrentUser,
    service: ServiceDep,
    payload: RefreshRequest | None = None,
) -> None:
    await service.logout(user.id, payload.refresh_token if payload else None)


@router.get(
    "/me",
    response_model=UserResponse,
    summary="The authenticated account",
    description=(
        "The client's only source of truth for who is signed in and what role "
        "they hold. Roles must never be inferred from the email address."
    ),
)
async def me(user: CurrentUser) -> UserResponse:
    return user
