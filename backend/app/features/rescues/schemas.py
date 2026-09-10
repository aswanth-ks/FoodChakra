"""Rescue wire contract.

A rescue is one consumer's claim on one listing. There is no negotiation, no
assignment and no third party: the person who claims the food keeps it
(`docs/BACKEND_CONTRACT.md` §0).

The response carries a denormalised snapshot of the listing because every
rescue screen — Rescuer Found, Active Rescue, Rescue Complete — renders the
food and the pickup point alongside the rescue's own state. Fetching the
listing separately would mean two round trips for one screen.
"""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.core.security import HANDOVER_CODE_LENGTH
from app.features.listings.schemas import PickupLocationResponse
from app.shared.lifecycle import LifecycleState, RescueStage


class CreateRescueRequest(BaseModel):
    """Tap-to-claim. The listing id is the only thing a client may supply.

    Everything else — who is rescuing, when, and what state the rescue opens
    in — comes from the authenticated session, the server clock and
    `lifecycle.py`. `extra="forbid"` makes an attempt to send `rescuer_id`,
    `status` or `created_at` a 422 rather than a silently ignored field.
    """

    model_config = ConfigDict(extra="forbid")

    listing_id: str = Field(min_length=1, max_length=64)


class VerifyHandoverRequest(BaseModel):
    """The listing owner confirms the handover by entering the rescuer's code.

    The code travels in one direction only: the server shows it to the
    **rescuer**, and the **owner** types what the rescuer is holding. That is
    what the code proves — that the two are standing together. A code the owner
    already knew would prove nothing about the rescuer being present.
    """

    model_config = ConfigDict(extra="forbid")

    code: str = Field(min_length=HANDOVER_CODE_LENGTH, max_length=HANDOVER_CODE_LENGTH)

    @field_validator("code")
    @classmethod
    def _digits_only(cls, value: str) -> str:
        if not value.isdigit():
            raise ValueError("The handover code is six digits.")
        return value


class CancelRescueRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reason: str | None = Field(default=None, max_length=280)


class RescueListingSnapshot(BaseModel):
    """The listing, as the rescue screens need it."""

    id: str
    reference: str
    #: "25 Meal Boxes".
    title: str
    category: str
    quantity_label: str
    servings: int
    pickup_location: PickupLocationResponse
    pickup_from: datetime
    pickup_until: datetime
    #: The publisher's display name — never their account id or email.
    shared_by: str
    shared_by_verified: bool
    photo_url: str | None = None
    description: str | None = None
    tags: list[str] = Field(default_factory=list)


class RescueResponse(BaseModel):
    id: str
    reference: str
    #: Canonical lifecycle state — the backend's authoritative answer.
    status: LifecycleState
    #: The mobile app's five-step stepper, projected from `status` by
    #: `lifecycle.py`. A projection, never a second source of truth.
    stage: RescueStage | None
    #: True while the rescue is still running.
    is_active: bool
    listing: RescueListingSnapshot
    #: Straight-line km from the rescuer at claim time, for "1.4 km away".
    distance_km: float | None = None

    #: The plaintext handover code, shown to the **rescuer only** so they can
    #: read it out at the pickup point.
    #:
    #: It is never stored in plaintext, never returned to the person who
    #: verifies, and is cleared the moment the handover succeeds. `None` for
    #: everyone but the rescuer, and for every state other than `arrived`.
    handover_code: str | None = None
    #: When that code stops working.
    handover_code_expires_at: datetime | None = None
    cancel_reason: str | None = None
    created_at: datetime
    updated_at: datetime


class RescuePage(BaseModel):
    items: list[RescueResponse]
    limit: int
    offset: int
    has_more: bool
