"""Listings business logic.

Owns every rule about what a listing is, who may change it, and which
lifecycle moves are legal. Lifecycle legality is delegated to
`app/shared/lifecycle.py` — this module never re-states a transition rule.
"""

import math
import secrets
from datetime import UTC, datetime
from typing import Any

from app.core.exceptions import ConflictError, ForbiddenError, NotFoundError
from app.features.activity.schemas import (
    EventCategory,
    EventSubject,
    SubjectType,
)
from app.features.activity.service import (
    ActivityService,
    partner_actor,
    rescuer_actor,
)
from app.features.auth.schemas import AccountRole, UserResponse
from app.features.listings.repository import ListingRepository
from app.features.listings.schemas import (
    FOOD_TYPE_LABEL,
    PREPARED_NOTE,
    UNIT_SHORT_LABEL,
    CreateListingRequest,
    FoodType,
    ListingDetail,
    ListingSummary,
    ListingUrgency,
    PickupLocationResponse,
    PreparedWhen,
    QuantityUnit,
    SourceKind,
    SurplusSource,
)
from app.shared.lifecycle import (
    LISTING_CLAIMABLE_STATES,
    LISTING_TRANSITIONS,
    LifecycleState,
    can_transition,
)

#: Windows shorter than this read as "expiring" on the Explore card.
EXPIRING_THRESHOLD_MINUTES = 60
#: Below this, the design's only use of red.
CRITICAL_THRESHOLD_MINUTES = 15

MAX_PAGE_SIZE = 50
DEFAULT_PAGE_SIZE = 20
DEFAULT_RADIUS_KM = 5.0
MAX_RADIUS_KM = 50.0


class ListingService:
    def __init__(
        self,
        repository: ListingRepository,
        activity: ActivityService,
    ) -> None:
        self._repository = repository
        self._activity = activity

    # -------------------------------------------------------------- create

    async def create(
        self, payload: CreateListingRequest, *, user: UserResponse
    ) -> ListingDetail:
        """Publish surplus.

        Identity, lifecycle state and every timestamp are assigned here from
        the authenticated user and the server clock. None is read from the
        request — `CreateListingRequest` has no such fields.
        """
        if not payload.safety_confirmed:
            raise ConflictError(
                "The food safety confirmation is required before publishing."
            )

        now = datetime.now(UTC)
        if payload.pickup_until <= now:
            raise ConflictError("The pickup window has already closed.")

        source_kind = (
            SourceKind.PARTNER
            if user.role is AccountRole.PARTNER
            else SourceKind.CONSUMER
        )

        document: dict[str, Any] = {
            "reference": await self._next_reference(),
            "source_kind": source_kind.value,
            # Ownership comes from the token-resolved account, never the body.
            "owner_user_id": _object_id(user.id),
            "owner_display_name": user.full_name,
            "partner_id": _object_id(user.partner_id) if user.partner_id else None,
            "source": payload.source.value if payload.source else None,
            "title": _title_for(payload.quantity, payload.unit),
            "food_name": payload.food_name.strip(),
            "food_type": payload.food_type.value,
            "quantity": payload.quantity,
            "unit": payload.unit.value,
            "servings_estimate": _servings_for(payload.quantity, payload.unit),
            "weight_kg": payload.weight_kg,
            "prepared_when": payload.prepared_when.value,
            "description": payload.description,
            "tags": payload.tags,
            "photo_url": payload.photo_url,
            "safety_confirmed": True,
            "pickup_location": {
                "label": payload.pickup_location.label,
                "locality": payload.pickup_location.locality,
                "pickup_point": payload.pickup_location.pickup_point,
                # GeoJSON is longitude-first. Getting this backwards puts every
                # listing in the wrong hemisphere and the query still "works".
                "point": {
                    "type": "Point",
                    "coordinates": [
                        payload.pickup_location.longitude,
                        payload.pickup_location.latitude,
                    ],
                },
            },
            "pickup_from": payload.pickup_from,
            "pickup_until": payload.pickup_until,
            # The window closing is what makes surplus unrecoverable, so expiry
            # tracks it rather than being a separate client-supplied date.
            "expires_at": payload.pickup_until,
            # The canonical lifecycle decides the opening state; a client
            # cannot name one.
            "status": LifecycleState.PUBLISHED.value,
            "active_rescue_id": None,
            "search_radius_km": DEFAULT_RADIUS_KM,
            "escalation_id": None,
            "is_live": False,
            "published_at": now,
            "created_at": now,
            "updated_at": now,
        }

        stored = await self._repository.create(document)

        await self._activity.record(
            actor=self._actor_for(user),
            category=EventCategory.RESCUE,
            action="listing_created",
            subject=EventSubject(
                type=SubjectType.LISTING,
                id=str(stored["_id"]),
                reference=stored["reference"],
            ),
            detail=f"{stored['title']} published for pickup at "
            f"{payload.pickup_location.label}.",
            context={
                "food_type": stored["food_type"],
                "quantity": stored["quantity"],
                "unit": stored["unit"],
                "source_kind": source_kind.value,
            },
        )

        return self.to_detail(stored)

    # -------------------------------------------------------------- cancel

    async def cancel(
        self, listing_id: str, *, user: UserResponse, reason: str | None
    ) -> ListingDetail:
        """Withdraw a listing. Only its owner may, and only before it is claimed."""
        stored = await self._require_listing(listing_id)
        self._require_owner(stored, user)

        current = LifecycleState(stored["status"])
        if not can_transition(
            current, LifecycleState.CANCELLED, transitions=LISTING_TRANSITIONS
        ):
            # A matched listing has a rescuer already on their way; withdrawing
            # it from under them is a rescue-side cancellation, not this.
            raise ConflictError(
                f"A listing that is {current.value} can no longer be withdrawn."
            )

        updated = await self._repository.set_status(
            stored["_id"],
            expected=[current],
            status=LifecycleState.CANCELLED,
            extra={"cancel_reason": reason},
        )
        if updated is None:
            # Someone changed it between the read and the write.
            raise ConflictError("The listing changed before it could be withdrawn.")

        await self._activity.record(
            actor=self._actor_for(user),
            category=EventCategory.RESCUE,
            action="listing_cancelled",
            subject=EventSubject(
                type=SubjectType.LISTING,
                id=str(updated["_id"]),
                reference=updated["reference"],
            ),
            detail=reason or "Withdrawn by the publisher.",
            context={"previous_status": current.value},
        )

        return self.to_detail(updated)

    # --------------------------------------------------------------- reads

    async def nearby(
        self,
        *,
        latitude: float,
        longitude: float,
        radius_km: float | None,
        food_types: list[FoodType] | None,
        source: SurplusSource | None,
        limit: int,
        offset: int,
    ) -> tuple[list[ListingSummary], int, int, bool]:
        """Claimable listings near a point, nearest first."""
        limit = _clamp(limit, 1, MAX_PAGE_SIZE)
        offset = max(offset, 0)
        radius = _clamp(radius_km or DEFAULT_RADIUS_KM, 0.1, MAX_RADIUS_KM)

        # One extra row answers "is there another page?" without a count().
        rows = await self._repository.find_nearby(
            longitude=longitude,
            latitude=latitude,
            radius_km=radius,
            limit=limit + 1,
            offset=offset,
            food_types=[t.value for t in food_types] if food_types else None,
            source=source.value if source else None,
        )
        has_more = len(rows) > limit
        rows = rows[:limit]

        items = [
            self.to_summary(row, origin=(latitude, longitude)) for row in rows
        ]
        return items, limit, offset, has_more

    async def mine(
        self,
        *,
        user: UserResponse,
        statuses: list[LifecycleState] | None,
        limit: int,
        offset: int,
    ) -> tuple[list[ListingSummary], int, int, bool]:
        limit = _clamp(limit, 1, MAX_PAGE_SIZE)
        offset = max(offset, 0)

        rows = await self._repository.find_by_owner(
            owner_id=_object_id(user.id),
            statuses=[s.value for s in statuses] if statuses else None,
            limit=limit + 1,
            offset=offset,
        )
        has_more = len(rows) > limit
        rows = rows[:limit]

        return [self.to_summary(row) for row in rows], limit, offset, has_more

    async def detail(self, listing_id: str) -> ListingDetail:
        return self.to_detail(await self._require_listing(listing_id))

    # ------------------------------------------------------------- helpers

    async def _require_listing(self, listing_id: str) -> dict[str, Any]:
        stored = await self._repository.find_by_id(listing_id)
        if stored is None:
            raise NotFoundError("That listing does not exist.")
        return stored

    @staticmethod
    def _require_owner(stored: dict[str, Any], user: UserResponse) -> None:
        if str(stored.get("owner_user_id")) != user.id:
            # Deliberately 403 rather than 404: the caller already holds the id
            # from a public listing, so hiding existence achieves nothing.
            raise ForbiddenError("This listing belongs to another account.")

    @staticmethod
    def _actor_for(user: UserResponse):
        return (
            partner_actor(user.partner_id or user.id, user.full_name)
            if user.role is AccountRole.PARTNER
            else rescuer_actor(user.id, user.full_name)
        )

    async def _next_reference(self) -> str:
        """A short human-facing reference, e.g. "FL-20481".

        Random rather than sequential: a sequence would need a counter
        document, and would leak how many listings the platform has. The
        `uniq_reference` index is the real guarantee; this loop just avoids
        handing it an obvious collision.
        """
        for _ in range(5):
            candidate = f"FL-{secrets.randbelow(90_000) + 10_000}"
            if not await self._repository.reference_exists(candidate):
                return candidate
        return f"FL-{secrets.token_hex(4).upper()}"

    # --------------------------------------------------------- projections

    @classmethod
    def to_summary(
        cls,
        stored: dict[str, Any],
        *,
        origin: tuple[float, float] | None = None,
    ) -> ListingSummary:
        return ListingSummary(**cls._summary_fields(stored, origin))

    @classmethod
    def to_detail(
        cls,
        stored: dict[str, Any],
        *,
        origin: tuple[float, float] | None = None,
    ) -> ListingDetail:
        prepared_when = PreparedWhen(
            stored.get("prepared_when", PreparedWhen.EARLIER_TODAY.value)
        )
        return ListingDetail(
            **cls._summary_fields(stored, origin),
            description=stored.get("description"),
            tags=stored.get("tags", []),
            prepared_when=prepared_when,
            prepared_note=PREPARED_NOTE[prepared_when],
            weight_kg=stored.get("weight_kg"),
        )

    @staticmethod
    def _summary_fields(
        stored: dict[str, Any], origin: tuple[float, float] | None
    ) -> dict[str, Any]:
        """Build the safe projection.

        Fields are listed explicitly rather than spreading the document, so a
        field added to storage later cannot leak into a response by default.
        `owner_user_id` and `partner_id` are intentionally not exposed — only
        the publisher's display name is.
        """
        unit = QuantityUnit(stored["unit"])
        food_type = FoodType(stored["food_type"])
        status = LifecycleState(stored["status"])
        location = stored["pickup_location"]
        longitude, latitude = location["point"]["coordinates"]

        source = stored.get("source")
        return {
            "id": str(stored["_id"]),
            "reference": stored["reference"],
            "title": stored["title"],
            "food_name": stored["food_name"],
            "food_type": food_type,
            "category": FOOD_TYPE_LABEL[food_type],
            "quantity": stored["quantity"],
            "unit": unit,
            "quantity_label": _quantity_label(stored["quantity"], unit),
            "servings": stored.get("servings_estimate", stored["quantity"]),
            "status": status,
            "urgency": _urgency_for(
                stored["pickup_from"], stored["pickup_until"]
            ),
            "pickup_from": stored["pickup_from"],
            "pickup_until": stored["pickup_until"],
            "expires_at": stored["expires_at"],
            "pickup_location": PickupLocationResponse(
                label=location["label"],
                locality=location.get("locality"),
                latitude=latitude,
                longitude=longitude,
                pickup_point=location.get("pickup_point"),
            ),
            "distance_km": (
                _distance_km(origin, (latitude, longitude)) if origin else None
            ),
            "shared_by": stored.get("owner_display_name", "FoodLoop member"),
            "shared_by_verified": stored["source_kind"] == SourceKind.PARTNER.value,
            "source": SurplusSource(source) if source else None,
            "source_kind": SourceKind(stored["source_kind"]),
            "photo_url": stored.get("photo_url"),
            "is_live": bool(stored.get("is_live", False)),
            "is_available": _is_available(status, stored["expires_at"]),
            "created_at": stored["created_at"],
        }


# ---------------------------------------------------------------- functions


def _title_for(quantity: int, unit: QuantityUnit) -> str:
    """"25 Meal Boxes" — the headline every screen shows."""
    return f"{quantity} {UNIT_SHORT_LABEL[unit]}"


def _quantity_label(quantity: int, unit: QuantityUnit) -> str:
    if unit is QuantityUnit.KILOGRAMS:
        return f"Approx. {quantity} kg"
    return f"Approx. {quantity} {'serving' if quantity == 1 else 'servings'}"


def _servings_for(quantity: int, unit: QuantityUnit) -> int:
    """Kilograms are not portions; the rest map one-to-one."""
    if unit is QuantityUnit.KILOGRAMS:
        # A rough, honest conversion: ~2.5 servings per kilogram of cooked food.
        return max(1, round(quantity * 2.5))
    return quantity


def _as_utc(value: datetime) -> datetime:
    """MongoDB returns naive UTC datetimes; comparisons need them aware."""
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def _urgency_for(pickup_from: datetime, pickup_until: datetime) -> ListingUrgency:
    """Derived on every read — see `ListingUrgency`."""
    now = datetime.now(UTC)
    start = _as_utc(pickup_from)
    end = _as_utc(pickup_until)

    if now < start:
        return ListingUrgency.SCHEDULED

    minutes_left = (end - now).total_seconds() / 60
    if minutes_left <= CRITICAL_THRESHOLD_MINUTES:
        return ListingUrgency.CRITICAL
    if minutes_left <= EXPIRING_THRESHOLD_MINUTES:
        return ListingUrgency.EXPIRING
    return ListingUrgency.AVAILABLE


def _is_available(status: LifecycleState, expires_at: datetime) -> bool:
    return status in LISTING_CLAIMABLE_STATES and _as_utc(expires_at) > datetime.now(
        UTC
    )


def _distance_km(
    origin: tuple[float, float], target: tuple[float, float]
) -> float:
    """Great-circle distance, for display only.

    The *ordering* comes from MongoDB's `$nearSphere`; this only turns the
    result into the "1.4 km away" label the card shows.
    """
    earth_radius_km = 6371.0
    lat1, lon1 = math.radians(origin[0]), math.radians(origin[1])
    lat2, lon2 = math.radians(target[0]), math.radians(target[1])

    delta_lat = lat2 - lat1
    delta_lon = lon2 - lon1
    a = (
        math.sin(delta_lat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2) ** 2
    )
    return round(2 * earth_radius_km * math.asin(math.sqrt(a)), 2)


def _clamp(value: float, low: float, high: float) -> float:
    return max(low, min(value, high))


def _object_id(value: str):
    from bson import ObjectId

    return ObjectId(value)
