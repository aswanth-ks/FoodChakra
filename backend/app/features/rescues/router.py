"""Rescue routes.

HTTP wiring only. The atomic claim lives in the repository, and every rule
about who may do what lives in the service.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.db.mongo import get_db
from app.features.activity.repository import ActivityEventRepository
from app.features.activity.service import ActivityService
from app.features.auth.dependencies import CurrentUser
from app.features.listings.repository import ListingRepository
from app.features.rescues.repository import RescueRepository
from app.features.rescues.schemas import (
    CancelRescueRequest,
    CreateRescueRequest,
    RescuePage,
    RescueResponse,
    VerifyHandoverRequest,
)
from app.features.rescues.service import (
    DEFAULT_PAGE_SIZE,
    MAX_PAGE_SIZE,
    RescueService,
    require_consumer_account,
    validate_object_id,
)

router = APIRouter(prefix="/rescues", tags=["rescues"])


def get_rescue_service(
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> RescueService:
    return RescueService(
        RescueRepository(db),
        ListingRepository(db),
        ActivityService(ActivityEventRepository(db)),
    )


ServiceDep = Annotated[RescueService, Depends(get_rescue_service)]


@router.post(
    "",
    response_model=RescueResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Claim a listing (tap-to-claim)",
    description=(
        "Atomically claims an available listing for the authenticated "
        "consumer. Exactly one of two concurrent claims succeeds; the other "
        "receives 409 and no rescue is created for it."
    ),
)
async def create_rescue(
    payload: CreateRescueRequest, user: CurrentUser, service: ServiceDep
) -> RescueResponse:
    require_consumer_account(user)
    validate_object_id(payload.listing_id, field="listing_id")
    return await service.claim(payload.listing_id, user=user)


@router.get(
    "/mine",
    response_model=RescuePage,
    summary="The authenticated consumer's rescues",
    description="Backs the Activity screen's Active and History tabs.",
)
async def my_rescues(
    user: CurrentUser,
    service: ServiceDep,
    active: Annotated[bool, Query()] = False,
    limit: Annotated[int, Query(ge=1, le=MAX_PAGE_SIZE)] = DEFAULT_PAGE_SIZE,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> RescuePage:
    return await service.mine(
        user=user, active_only=active, limit=limit, offset=offset
    )


@router.get(
    "/for-listing/{listing_id}",
    response_model=RescueResponse,
    summary="The rescue currently holding one of your listings",
    description=(
        "For the listing's owner (or a colleague at the owning business). "
        "Without this an owner has no way to find the rescue they are being "
        "asked to confirm — `GET /rescues/{id}` is scoped to the rescuer. The "
        "handover code is never included."
    ),
)
async def rescue_for_listing(
    listing_id: str, user: CurrentUser, service: ServiceDep
) -> RescueResponse:
    validate_object_id(listing_id, field="listing_id")
    return await service.active_for_listing(listing_id, user=user)


@router.get(
    "/{rescue_id}",
    response_model=RescueResponse,
    summary="One rescue",
    description=(
        "Only the rescuer may read their own rescue. Another account's rescue "
        "returns 404 rather than 403, because a rescue id is not public."
    ),
)
async def rescue_detail(
    rescue_id: str, user: CurrentUser, service: ServiceDep
) -> RescueResponse:
    return await service.detail(rescue_id, user=user)


@router.post(
    "/{rescue_id}/on-the-way",
    response_model=RescueResponse,
    summary="Start travelling to the pickup point",
)
async def start_travel(
    rescue_id: str, user: CurrentUser, service: ServiceDep
) -> RescueResponse:
    return await service.start_travel(rescue_id, user=user)


@router.post(
    "/{rescue_id}/arrived",
    response_model=RescueResponse,
    summary="Rescuer has arrived at the pickup point",
    description=(
        "`onTheWay -> arrived`. Issues a six-digit handover code and returns "
        "it **to the rescuer only**, in this response. The rescuer reads it "
        "out to the listing's owner, who submits it to `/verify`. The code is "
        "stored hashed, expires in 30 minutes, and is single-use."
    ),
)
async def mark_arrived(
    rescue_id: str, user: CurrentUser, service: ServiceDep
) -> RescueResponse:
    return await service.mark_arrived(rescue_id, user=user)


@router.post(
    "/{rescue_id}/verify",
    response_model=RescueResponse,
    summary="Owner confirms the handover",
    description=(
        "`arrived -> verified`, performed by the listing's owner (or a "
        "colleague at the owning business). The rescuer cannot confirm their "
        "own handover — that separation is the point of the step."
    ),
)
async def verify_handover(
    rescue_id: str,
    payload: VerifyHandoverRequest,
    user: CurrentUser,
    service: ServiceDep,
) -> RescueResponse:
    return await service.verify_handover(rescue_id, user=user, code=payload.code)


@router.post(
    "/{rescue_id}/collected",
    response_model=RescueResponse,
    summary="Rescuer confirms they have the food",
    description=(
        "`verified -> collected -> completed`. Completion is applied in the "
        "same call: once the handover is confirmed and the rescuer has the "
        "food, no actor remains to advance it further. Requires a verified "
        "handover — an unverified rescue is refused with 409."
    ),
)
async def mark_collected(
    rescue_id: str, user: CurrentUser, service: ServiceDep
) -> RescueResponse:
    return await service.mark_collected(rescue_id, user=user)


@router.post(
    "/{rescue_id}/cancel",
    response_model=RescueResponse,
    summary="Give up a rescue",
    description=(
        "Returns the listing to the pool as `searching` so another consumer "
        "can claim it."
    ),
)
async def cancel_rescue(
    rescue_id: str,
    user: CurrentUser,
    service: ServiceDep,
    payload: CancelRescueRequest | None = None,
) -> RescueResponse:
    return await service.cancel(
        rescue_id, user=user, reason=payload.reason if payload else None
    )
