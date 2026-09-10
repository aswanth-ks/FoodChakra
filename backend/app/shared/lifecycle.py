"""The canonical FoodLoop lifecycle. THE single source of truth for state.

There is exactly one state machine in this system. Everything else is a
*projection* of it.

The audit (`docs/BACKEND_CONTRACT.md` §2) found three separate lifecycle enums
already in the codebase: the console's nine `LifecycleStep`s, the mobile app's
five `RescueStage`s, and the partner app's six `PartnerSurplusStatus`es. They
describe the same journey at three levels of detail. If the backend stored any
one of the narrow ones, the other two could not be reconstructed; if it stored
all three, they would drift apart the first time a transition was added.

So the backend stores the **widest** one — the console's — and this module
provides pure functions that narrow it for the other two clients. Adding a
state means editing this file, and only this file.

Wire values deliberately use the console's exact spelling (`"onTheWay"`, not
`"on_the_way"`) so the dashboard's TypeScript union types parse the API
response with no translation layer.
"""

from enum import StrEnum


class LifecycleState(StrEnum):
    """Every state a piece of surplus can be in, from draft to terminal.

    Listings and rescues both draw from this one enum rather than defining
    their own — see `LISTING_STATES` and `RESCUE_STATES` for which subset each
    document is allowed to hold.
    """

    # ----- The nine forward steps (console `LifecycleStep`) -----
    DRAFT = "draft"
    PUBLISHED = "published"
    SEARCHING = "searching"
    MATCHED = "matched"
    ON_THE_WAY = "onTheWay"
    ARRIVED = "arrived"
    VERIFIED = "verified"
    COLLECTED = "collected"
    COMPLETED = "completed"

    # ----- Terminal failure states -----
    CANCELLED = "cancelled"
    EXPIRED = "expired"
    NO_SHOW = "no_show"
    FALLBACK = "fallback"


#: The forward path, in order. The index doubles as progress, which is what the
#: console's horizontal tracker renders.
LIFECYCLE_ORDER: tuple[LifecycleState, ...] = (
    LifecycleState.DRAFT,
    LifecycleState.PUBLISHED,
    LifecycleState.SEARCHING,
    LifecycleState.MATCHED,
    LifecycleState.ON_THE_WAY,
    LifecycleState.ARRIVED,
    LifecycleState.VERIFIED,
    LifecycleState.COLLECTED,
    LifecycleState.COMPLETED,
)

#: Nothing leaves these. Used by the rescue-claim partial index (see
#: `app/db/indexes.py`) to decide which rescues still occupy their listing.
TERMINAL_STATES: frozenset[LifecycleState] = frozenset(
    {
        LifecycleState.COMPLETED,
        LifecycleState.CANCELLED,
        LifecycleState.EXPIRED,
        LifecycleState.NO_SHOW,
        LifecycleState.FALLBACK,
    }
)

#: Ownership of the journey changes hands at `matched`: before it, the listing
#: drives; after it, the rescue does. These two sets encode that split.
LISTING_STATES: frozenset[LifecycleState] = frozenset(
    {
        LifecycleState.DRAFT,
        LifecycleState.PUBLISHED,
        LifecycleState.SEARCHING,
        LifecycleState.MATCHED,
        LifecycleState.COLLECTED,
        LifecycleState.COMPLETED,
        LifecycleState.CANCELLED,
        LifecycleState.EXPIRED,
        LifecycleState.FALLBACK,
    }
)

RESCUE_STATES: frozenset[LifecycleState] = frozenset(
    {
        LifecycleState.MATCHED,
        LifecycleState.ON_THE_WAY,
        LifecycleState.ARRIVED,
        LifecycleState.VERIFIED,
        LifecycleState.COLLECTED,
        LifecycleState.COMPLETED,
        LifecycleState.CANCELLED,
        LifecycleState.NO_SHOW,
    }
)

#: A rescue in one of these still holds its listing — no other consumer may
#: claim it. This is the exact predicate behind the partial unique index.
RESCUE_ACTIVE_STATES: frozenset[LifecycleState] = RESCUE_STATES - TERMINAL_STATES

#: A listing in one of these is claimable. The atomic claim in Stage E filters
#: on precisely this set.
LISTING_CLAIMABLE_STATES: frozenset[LifecycleState] = frozenset(
    {LifecycleState.PUBLISHED, LifecycleState.SEARCHING}
)


# --------------------------------------------------------------- transitions

#: Legal forward moves for a listing. Absent keys are terminal.
LISTING_TRANSITIONS: dict[LifecycleState, frozenset[LifecycleState]] = {
    LifecycleState.DRAFT: frozenset(
        {LifecycleState.PUBLISHED, LifecycleState.CANCELLED}
    ),
    LifecycleState.PUBLISHED: frozenset(
        {
            LifecycleState.SEARCHING,
            LifecycleState.MATCHED,
            LifecycleState.CANCELLED,
            LifecycleState.EXPIRED,
        }
    ),
    LifecycleState.SEARCHING: frozenset(
        {
            LifecycleState.MATCHED,
            LifecycleState.CANCELLED,
            LifecycleState.EXPIRED,
            LifecycleState.FALLBACK,
        }
    ),
    LifecycleState.MATCHED: frozenset(
        {
            LifecycleState.COLLECTED,
            # A cancelled rescue returns the listing to the pool.
            LifecycleState.SEARCHING,
            LifecycleState.EXPIRED,
        }
    ),
    LifecycleState.COLLECTED: frozenset({LifecycleState.COMPLETED}),
}

#: Legal forward moves for a rescue.
RESCUE_TRANSITIONS: dict[LifecycleState, frozenset[LifecycleState]] = {
    LifecycleState.MATCHED: frozenset(
        {
            LifecycleState.ON_THE_WAY,
            LifecycleState.CANCELLED,
            LifecycleState.NO_SHOW,
        }
    ),
    LifecycleState.ON_THE_WAY: frozenset(
        {
            LifecycleState.ARRIVED,
            LifecycleState.CANCELLED,
            LifecycleState.NO_SHOW,
        }
    ),
    LifecycleState.ARRIVED: frozenset(
        {LifecycleState.VERIFIED, LifecycleState.CANCELLED}
    ),
    LifecycleState.VERIFIED: frozenset(
        {LifecycleState.COLLECTED, LifecycleState.CANCELLED}
    ),
    LifecycleState.COLLECTED: frozenset({LifecycleState.COMPLETED}),
}


def can_transition(
    current: LifecycleState,
    target: LifecycleState,
    *,
    transitions: dict[LifecycleState, frozenset[LifecycleState]],
) -> bool:
    """Whether `current -> target` is legal under the given transition table.

    Services call this before writing. It lives here rather than in each
    service so the rules cannot diverge per feature.
    """
    return target in transitions.get(current, frozenset())


def is_terminal(state: LifecycleState) -> bool:
    return state in TERMINAL_STATES


def progress_index(state: LifecycleState) -> int | None:
    """Position on the forward path, or None for a terminal failure state."""
    try:
        return LIFECYCLE_ORDER.index(state)
    except ValueError:
        return None


# --------------------------------------------------------------- projections
#
# These narrow the canonical state for a specific client. They are pure
# functions with no storage of their own — that is what stops them becoming
# competing state machines.


class RescueStage(StrEnum):
    """The mobile app's five-step stepper (`mobile/.../food_listing.dart`)."""

    CONFIRMED = "confirmed"
    PREPARING = "preparing"
    READY = "ready"
    PICKUP = "pickup"
    COLLECTED = "collected"


class PartnerSurplusStatus(StrEnum):
    """The partner app's six statuses (`mobile/.../partner_dashboard.dart`)."""

    DRAFT = "draft"
    LOOKING_FOR_RESCUER = "lookingForRescuer"
    RESCUER_MATCHED = "rescuerMatched"
    AWAITING_HANDOVER = "awaitingHandover"
    COLLECTED = "collected"
    EXPIRED = "expired"


_TO_RESCUE_STAGE: dict[LifecycleState, RescueStage] = {
    LifecycleState.MATCHED: RescueStage.CONFIRMED,
    LifecycleState.ON_THE_WAY: RescueStage.READY,
    LifecycleState.ARRIVED: RescueStage.PICKUP,
    LifecycleState.VERIFIED: RescueStage.PICKUP,
    LifecycleState.COLLECTED: RescueStage.COLLECTED,
    LifecycleState.COMPLETED: RescueStage.COLLECTED,
}

_TO_PARTNER_STATUS: dict[LifecycleState, PartnerSurplusStatus] = {
    LifecycleState.DRAFT: PartnerSurplusStatus.DRAFT,
    LifecycleState.PUBLISHED: PartnerSurplusStatus.LOOKING_FOR_RESCUER,
    LifecycleState.SEARCHING: PartnerSurplusStatus.LOOKING_FOR_RESCUER,
    LifecycleState.MATCHED: PartnerSurplusStatus.RESCUER_MATCHED,
    LifecycleState.ON_THE_WAY: PartnerSurplusStatus.RESCUER_MATCHED,
    LifecycleState.ARRIVED: PartnerSurplusStatus.AWAITING_HANDOVER,
    LifecycleState.VERIFIED: PartnerSurplusStatus.AWAITING_HANDOVER,
    LifecycleState.COLLECTED: PartnerSurplusStatus.COLLECTED,
    LifecycleState.COMPLETED: PartnerSurplusStatus.COLLECTED,
    LifecycleState.EXPIRED: PartnerSurplusStatus.EXPIRED,
}


def to_rescue_stage(state: LifecycleState) -> RescueStage | None:
    """Narrow to the mobile stepper. None when the rescue is not in flight.

    `preparing` is intentionally unreachable from state alone: the mobile app
    shows it while a `matched` listing's owner has not signalled readiness,
    which is a separate flag on the listing rather than a lifecycle state.
    """
    return _TO_RESCUE_STAGE.get(state)


def to_partner_status(state: LifecycleState) -> PartnerSurplusStatus | None:
    """Narrow to the partner app's surplus status."""
    return _TO_PARTNER_STATUS.get(state)
