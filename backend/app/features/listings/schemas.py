"""Listings wire contract.

Every enum here mirrors a value the Flutter Give flow already produces
(`mobile/lib/features/give/domain/surplus_draft.dart`), and every response
field feeds something the Explore or Food Details screen already renders
(`mobile/lib/features/rescue/domain/food_listing.dart`). Nothing was invented
for the backend's convenience.

Request and response models are kept apart: a client may not send anything
that decides ownership, lifecycle or time.
"""

from datetime import datetime
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.shared.lifecycle import LifecycleState


class SurplusSource(StrEnum):
    """Where the surplus came from — the Give entry screen's only question."""

    HOME = "home"
    EVENT = "event"


class FoodType(StrEnum):
    """Dietary category. `non_veg` and `other` are the design's own wording."""

    VEGETARIAN = "vegetarian"
    VEGAN = "vegan"
    NON_VEG = "non_veg"
    OTHER = "other"


class QuantityUnit(StrEnum):
    """How the amount is counted."""

    MEAL_BOXES = "meal_boxes"
    SERVINGS = "servings"
    KILOGRAMS = "kilograms"


class PreparedWhen(StrEnum):
    """When the food was made."""

    JUST_PREPARED = "just_prepared"
    EARLIER_TODAY = "earlier_today"
    YESTERDAY = "yesterday"
    OTHER = "other"


class SourceKind(StrEnum):
    """Who published. Derived from the authenticated account, never sent."""

    CONSUMER = "consumer"
    PARTNER = "partner"


class ListingUrgency(StrEnum):
    """How pressing collection is.

    **Computed on every read, never stored.** It is a pure function of the
    pickup window against the current time, so storing it would guarantee it
    goes stale between the write and the next read — a listing would show
    "Available today" hours after its window shut.
    """

    AVAILABLE = "available"
    EXPIRING = "expiring"
    CRITICAL = "critical"
    SCHEDULED = "scheduled"


#: Display labels, so the two clients cannot disagree about wording.
FOOD_TYPE_LABEL: dict[FoodType, str] = {
    FoodType.VEGETARIAN: "Vegetarian",
    FoodType.VEGAN: "Vegan",
    FoodType.NON_VEG: "Non-veg",
    FoodType.OTHER: "Other",
}

UNIT_SHORT_LABEL: dict[QuantityUnit, str] = {
    QuantityUnit.MEAL_BOXES: "Meal Boxes",
    QuantityUnit.SERVINGS: "Servings",
    QuantityUnit.KILOGRAMS: "kg",
}

PREPARED_NOTE: dict[PreparedWhen, str] = {
    PreparedWhen.JUST_PREPARED: "Just prepared",
    PreparedWhen.EARLIER_TODAY: "Prepared earlier today",
    PreparedWhen.YESTERDAY: "Prepared yesterday",
    PreparedWhen.OTHER: "Prepared earlier",
}


# ---------------------------------------------------------------- requests


class PickupLocationRequest(BaseModel):
    """Where the food is collected from.

    Coordinates are required. The Explore screen is entirely a `$near` query,
    so a listing without a point is one nobody can ever find — and
    `BACKEND_CONTRACT.md` §3.3 already specifies `pickup_location.point` as
    required. The Give flow's "Current location" action supplies them.
    """

    model_config = ConfigDict(extra="forbid")

    label: str = Field(min_length=1, max_length=120)
    locality: str | None = Field(default=None, max_length=120)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    #: "Pickup counter · Main entrance" — the partner handover point.
    pickup_point: str | None = Field(default=None, max_length=160)


class CreateListingRequest(BaseModel):
    """The Give flow's Review & publish step.

    Deliberately absent: `owner_user_id`, `source_kind`, `partner_id`,
    `status`, `reference`, `created_at`, `published_at`. All are assigned by
    the server. `extra="forbid"` turns an attempt to send one into a 422
    rather than a silently ignored field.
    """

    model_config = ConfigDict(extra="forbid")

    food_name: str = Field(min_length=1, max_length=120)
    food_type: FoodType
    quantity: int = Field(gt=0, le=100_000)
    unit: QuantityUnit = QuantityUnit.MEAL_BOXES
    source: SurplusSource | None = None
    prepared_when: PreparedWhen = PreparedWhen.EARLIER_TODAY

    #: The mandatory "safe and suitable to share" confirmation. Enforced as a
    #: business rule in the service, not merely as a type.
    safety_confirmed: bool

    #: Optional at creation, on purpose. The Give UI does not ask for a weight,
    #: and requiring one would break the existing flow. Zero-Waste tier routing
    #: needs it, so a fallback stage must obtain it before routing — see
    #: `docs/API.md`.
    weight_kg: float | None = Field(default=None, gt=0, le=10_000)

    description: str | None = Field(default=None, max_length=2000)
    tags: list[str] = Field(default_factory=list, max_length=12)
    photo_url: str | None = Field(default=None, max_length=500)

    pickup_location: PickupLocationRequest
    pickup_from: datetime
    pickup_until: datetime

    @model_validator(mode="after")
    def _check_window(self) -> "CreateListingRequest":
        if self.pickup_until <= self.pickup_from:
            raise ValueError("pickup_until must be after pickup_from.")
        return self


class CancelListingRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reason: str | None = Field(default=None, max_length=280)


# --------------------------------------------------------------- responses


class PickupLocationResponse(BaseModel):
    label: str
    locality: str | None = None
    latitude: float
    longitude: float
    pickup_point: str | None = None


class ListingSummary(BaseModel):
    """One Explore card. Carries what the card renders and nothing more.

    The publisher appears as a display name only — never their email, id or
    any other account field.
    """

    id: str
    reference: str
    #: "25 Meal Boxes" — composed from quantity and unit.
    title: str
    food_name: str
    food_type: FoodType
    #: "Vegetarian" — the card's one-line food kind.
    category: str
    quantity: int
    unit: QuantityUnit
    #: "Approx. 25 servings".
    quantity_label: str
    servings: int
    status: LifecycleState
    #: Computed per request from the pickup window. Never stored.
    urgency: ListingUrgency
    pickup_from: datetime
    pickup_until: datetime
    expires_at: datetime
    pickup_location: PickupLocationResponse
    #: Straight-line kilometres from the query point. Only set by `/nearby`.
    distance_km: float | None = None
    shared_by: str
    shared_by_verified: bool = False
    source: SurplusSource | None = None
    source_kind: SourceKind
    photo_url: str | None = None
    is_live: bool = False
    #: True while the listing can still be claimed.
    is_available: bool
    created_at: datetime


class ListingDetail(ListingSummary):
    """The Food Details screen. Adds the fields the card has no room for."""

    description: str | None = None
    tags: list[str] = Field(default_factory=list)
    #: "Prepared earlier today".
    prepared_note: str
    prepared_when: PreparedWhen
    weight_kg: float | None = None


class ListingPage(BaseModel):
    """A page of listings.

    Offset paging, matching how the Explore list is scrolled. `total` is
    omitted deliberately: counting every match on each page is expensive and
    nothing in the UI displays it.
    """

    items: list[ListingSummary]
    limit: int
    offset: int
    has_more: bool
