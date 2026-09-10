"""Listing routes.

HTTP wiring only. Authorization is declared through the Stage C dependencies;
every rule lives in the service.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from motor.motor_asyncio import AsyncIOMotorDatabase

from app.db.mongo import get_db
from app.features.activity.repository import ActivityEventRepository
from app.features.activity.service import ActivityService
from app.features.auth.dependencies import CurrentUser
from app.features.listings.repository import ListingRepository
from app.features.listings.schemas import (
    CancelListingRequest,
    CreateListingRequest,
    FoodType,
    ListingDetail,
    ListingPage,
    SurplusSource,
)
from app.features.listings.service import (
    DEFAULT_PAGE_SIZE,
    MAX_PAGE_SIZE,
    ListingService,
)
from app.shared.lifecycle import LifecycleState

router = APIRouter(prefix="/listings", tags=["listings"])


def get_listing_service(
    db: Annotated[AsyncIOMotorDatabase, Depends(get_db)],
) -> ListingService:
    return ListingService(
        ListingRepository(db),
        ActivityService(ActivityEventRepository(db)),
    )


ServiceDep = Annotated[ListingService, Depends(get_listing_service)]


@router.post(
    "",
    response_model=ListingDetail,
    status_code=status.HTTP_201_CREATED,
    summary="Publish surplus food",
    description=(
        "Creates a listing owned by the authenticated account. Ownership, "
        "lifecycle state, reference and all timestamps are assigned by the "
        "server; sending any of them is rejected."
    ),
)
async def create_listing(
    payload: CreateListingRequest, user: CurrentUser, service: ServiceDep
) -> ListingDetail:
    return await service.create(payload, user=user)


@router.get(
    "/nearby",
    response_model=ListingPage,
    summary="Claimable listings near a point",
    description=(
        "Backs the Explore screen. Returns only listings that can still be "
        "claimed, nearest first, using the `geo_pickup_location` 2dsphere "
        "index."
    ),
)
async def nearby_listings(
    user: CurrentUser,
    service: ServiceDep,
    lat: Annotated[float, Query(ge=-90, le=90)],
    lng: Annotated[float, Query(ge=-180, le=180)],
    radius_km: Annotated[float | None, Query(gt=0, le=50)] = None,
    food_type: Annotated[list[FoodType] | None, Query()] = None,
    source: SurplusSource | None = None,
    limit: Annotated[int, Query(ge=1, le=MAX_PAGE_SIZE)] = DEFAULT_PAGE_SIZE,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> ListingPage:
    items, limit, offset, has_more = await service.nearby(
        latitude=lat,
        longitude=lng,
        radius_km=radius_km,
        food_types=food_type,
        source=source,
        limit=limit,
        offset=offset,
    )
    return ListingPage(items=items, limit=limit, offset=offset, has_more=has_more)


@router.get(
    "/mine",
    response_model=ListingPage,
    summary="The authenticated account's own listings",
    description="Backs the Activity tabs and the partner Surplus screen.",
)
async def my_listings(
    user: CurrentUser,
    service: ServiceDep,
    listing_status: Annotated[list[LifecycleState] | None, Query(alias="status")] = None,
    limit: Annotated[int, Query(ge=1, le=MAX_PAGE_SIZE)] = DEFAULT_PAGE_SIZE,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> ListingPage:
    items, limit, offset, has_more = await service.mine(
        user=user, statuses=listing_status, limit=limit, offset=offset
    )
    return ListingPage(items=items, limit=limit, offset=offset, has_more=has_more)


@router.get(
    "/{listing_id}",
    response_model=ListingDetail,
    summary="One listing",
)
async def listing_detail(
    listing_id: str, user: CurrentUser, service: ServiceDep
) -> ListingDetail:
    return await service.detail(listing_id)


@router.post(
    "/{listing_id}/cancel",
    response_model=ListingDetail,
    summary="Withdraw a listing",
    description=(
        "Owner only. Permitted while the listing is still published or "
        "searching; once a rescuer has claimed it, withdrawal is a rescue-side "
        "cancellation instead."
    ),
)
async def cancel_listing(
    listing_id: str,
    user: CurrentUser,
    service: ServiceDep,
    payload: CancelListingRequest | None = None,
) -> ListingDetail:
    return await service.cancel(
        listing_id, user=user, reason=payload.reason if payload else None
    )
