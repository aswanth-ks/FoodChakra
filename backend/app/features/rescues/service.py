"""Rescue business logic — tap-to-claim.

## Consistency strategy

Claiming involves two writes to two collections: the listing must become
`matched`, and a rescue document must exist. MongoDB gives no cross-collection
atomicity without a transaction, and a transaction needs a replica set that
this project cannot currently reach (see `docs/PROJECT_STATUS.md`), so
correctness here does not depend on one. The order is chosen so that no
interleaving can produce a rescue without a claimed listing:

1. A rescue id is minted client-side (`ObjectId()`), before either write.
2. **The listing is claimed atomically**, stamped with that id. This single
   `find_one_and_update` is the mutual exclusion — see
   `ListingRepository.claim`. Losing it means someone else got there first.
3. The rescue document is inserted with that id.
4. If step 3 fails, step 2 is **compensated**: the listing is released back to
   the status it held, guarded on the rescue id so a later, legitimate claim
   is never clobbered.

The worst case is therefore a listing briefly marked `matched` with no rescue —
visible to nobody, since the claim is refused and the compensating write
follows immediately. The inverse (a rescue with no claimed listing) cannot
occur, because the rescue is only written after the claim has succeeded.

The `uniq_active_rescue_per_listing` partial index is the independent second
line of defence: even if the listing claim were somehow bypassed, the database
still refuses a second active rescue for the same listing.
"""

import logging
from datetime import UTC, datetime, timedelta
from typing import Any

from bson import ObjectId
from bson.errors import InvalidId
from pymongo.errors import DuplicateKeyError, PyMongoError

from app.core.exceptions import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ValidationError,
)
from app.core.security import (
    generate_handover_code,
    hash_handover_code,
    verify_handover_code,
)
from app.features.activity.schemas import EventCategory, EventSubject, SubjectType
from app.features.activity.service import (
    ActivityService,
    partner_actor,
    rescuer_actor,
)
from app.features.auth.schemas import AccountRole, UserResponse
from app.features.listings.repository import ListingRepository
from app.features.listings.schemas import PickupLocationResponse
from app.features.listings.service import ListingService
from app.features.rescues.repository import RescueRepository
from app.features.rescues.schemas import (
    RescueListingSnapshot,
    RescuePage,
    RescueResponse,
)
from app.shared.lifecycle import (
    RESCUE_ACTIVE_STATES,
    RESCUE_TRANSITIONS,
    LifecycleState,
    can_transition,
    to_rescue_stage,
)

logger = logging.getLogger(__name__)

MAX_PAGE_SIZE = 50
DEFAULT_PAGE_SIZE = 20

#: How long a handover code stays usable. Short, because it is only needed
#: while the two people are standing together — and because six digits is not
#: much entropy, so a narrow window is doing real work here.
HANDOVER_CODE_TTL = timedelta(minutes=30)

#: Wrong guesses before the code is locked. At six digits, an uncapped
#: endpoint is brute-forceable in minutes; this is what makes that infeasible.
MAX_HANDOVER_ATTEMPTS = 5


class RescueService:
    def __init__(
        self,
        repository: RescueRepository,
        listings: ListingRepository,
        activity: ActivityService,
    ) -> None:
        self._repository = repository
        self._listings = listings
        self._activity = activity

    # --------------------------------------------------------------- claim

    async def claim(self, listing_id: str, *, user: UserResponse) -> RescueResponse:
        """Claim a listing for the authenticated consumer."""
        listing = await self._listings.find_by_id(listing_id)
        if listing is None:
            raise NotFoundError("That listing does not exist.")

        if str(listing["owner_user_id"]) == user.id:
            raise ConflictError("You cannot rescue food you published yourself.")

        rescue_id = ObjectId()

        # Step 2: the atomic claim. Everything after this point either
        # completes or is compensated.
        previous = await self._listings.claim(listing["_id"], rescue_id=rescue_id)
        if previous is None:
            raise self._claim_refused(listing)

        previous_status = LifecycleState(previous["status"])
        now = datetime.now(UTC)
        document: dict[str, Any] = {
            "_id": rescue_id,
            "reference": listing["reference"],
            "listing_id": listing["_id"],
            # Identity comes from the authenticated session, never the body.
            "rescuer_id": ObjectId(user.id),
            "rescuer_display_name": user.full_name,
            "status": LifecycleState.MATCHED.value,
            "lifecycle": [{"step": LifecycleState.MATCHED.value, "at": now}],
            "distance_km": None,
            "cancel_reason": None,
            "matched_at": now,
            "created_at": now,
            "updated_at": now,
        }

        try:
            stored = await self._repository.create(document)
        except DuplicateKeyError as exc:
            # The partial index refused a second active rescue. The listing
            # claim said otherwise, so the two disagree — release the listing
            # and report the conflict rather than leaving it stuck.
            await self._release(listing["_id"], rescue_id, previous_status)
            raise ConflictError(
                "Someone else has just rescued this food."
            ) from exc
        except PyMongoError:
            await self._release(listing["_id"], rescue_id, previous_status)
            raise

        await self._activity.record(
            actor=rescuer_actor(user.id, user.full_name),
            category=EventCategory.RESCUE,
            action="rescue_created",
            subject=EventSubject(
                type=SubjectType.RESCUE,
                id=str(rescue_id),
                reference=listing["reference"],
            ),
            detail=f"{listing['title']} claimed for pickup at "
            f"{listing['pickup_location']['label']}.",
            context={
                "listing_id": str(listing["_id"]),
                "previous_listing_status": previous_status.value,
            },
        )

        return self._to_response(stored, listing)

    def _claim_refused(self, listing: dict[str, Any]) -> ConflictError:
        """Explain a lost claim without leaking who won it."""
        status = LifecycleState(listing["status"])
        if status is LifecycleState.CANCELLED:
            return ConflictError("This listing has been withdrawn.")
        if status is LifecycleState.EXPIRED:
            return ConflictError("This listing has expired.")
        return ConflictError("Someone else has just rescued this food.")

    async def _release(
        self,
        listing_id: ObjectId,
        rescue_id: ObjectId,
        previous_status: LifecycleState,
    ) -> None:
        """Compensating write for a claim whose rescue could not be created."""
        try:
            await self._listings.release(
                listing_id, rescue_id=rescue_id, restore_to=previous_status
            )
        except PyMongoError:
            # Logged loudly: the listing is stuck `matched` with no rescue and
            # needs the expiry sweep or an operator to free it.
            logger.error(
                "Failed to release listing %s after rescue %s could not be created",
                listing_id,
                rescue_id,
            )

    # --------------------------------------------------------- transitions

    async def start_travel(
        self, rescue_id: str, *, user: UserResponse
    ) -> RescueResponse:
        """`matched -> onTheWay`, confirmed explicitly by the rescuer.

        Deliberately not triggered by the maps hand-off: opening a maps app
        proves only that someone looked at a route. The rescuer confirms they
        are actually travelling, and until they do the listing stays `matched`
        with the rescue unstarted.
        """
        return await self._transition(
            rescue_id, user=user, target=LifecycleState.ON_THE_WAY
        )

    async def mark_arrived(
        self, rescue_id: str, *, user: UserResponse
    ) -> RescueResponse:
        """`onTheWay -> arrived`, and issue the handover code.

        The code is minted here rather than at claim time so it exists only in
        the window it is needed, which is what makes a short expiry sensible.
        The plaintext is returned to the rescuer once, in this response.
        """
        rescue, listing = await self._require_own_rescue(rescue_id, user)
        updated = await self._apply_transition(rescue, LifecycleState.ARRIVED)

        code = generate_handover_code()
        expires_at = datetime.now(UTC) + HANDOVER_CODE_TTL
        await self._repository.set_handover_code(
            rescue["_id"], code_hash=hash_handover_code(code), expires_at=expires_at
        )
        updated["handover_code_expires_at"] = expires_at

        await self._activity.record(
            actor=rescuer_actor(user.id, user.full_name),
            category=EventCategory.RESCUE,
            action="rescue_arrived",
            subject=self._subject(rescue),
            detail=f"Rescuer arrived at {listing['pickup_location']['label']}.",
            context={"listing_id": str(listing["_id"])},
        )

        # The one place the plaintext is ever exposed.
        return self._to_response(updated, listing, handover_code=code)

    async def verify_handover(
        self, rescue_id: str, *, user: UserResponse, code: str
    ) -> RescueResponse:
        """`arrived -> verified`, performed by the listing's owner.

        The rescuer cannot call this — that separation is the entire point of
        the step. Someone must confirm the food actually changed hands, and a
        rescuer confirming their own handover would prove nothing.
        """
        rescue = await self._repository.find_by_id(rescue_id)
        if rescue is None:
            raise NotFoundError("That rescue does not exist.")

        listing = await self._listings.find_by_id(str(rescue["listing_id"]))
        if listing is None:
            raise NotFoundError("The listing for that rescue no longer exists.")

        self._require_handover_authority(rescue, listing, user)

        current = LifecycleState(rescue["status"])
        if current is not LifecycleState.ARRIVED:
            raise ConflictError(
                "This rescue is not waiting for a handover confirmation."
            )

        code_hash = rescue.get("handover_code_hash")
        expires_at = rescue.get("handover_code_expires_at")
        if not code_hash or expires_at is None:
            raise ConflictError("No handover code has been issued for this rescue.")

        if _as_utc(expires_at) <= datetime.now(UTC):
            raise ConflictError("That handover code has expired.")

        if int(rescue.get("handover_attempts", 0)) >= MAX_HANDOVER_ATTEMPTS:
            raise ConflictError(
                "Too many incorrect attempts. Ask the rescuer for a new code."
            )

        if not verify_handover_code(code, code_hash):
            attempts = await self._repository.count_handover_attempt(rescue["_id"])
            logger.warning(
                "Failed handover verification for rescue %s (attempt %d)",
                rescue["_id"],
                attempts,
            )
            # No lifecycle activity event: a failed guess is not a transition.
            raise ForbiddenError("That handover code is not correct.")

        # The state guard is what makes verification single-use and
        # replay-proof. Two callers with the same valid code both reach here,
        # but only one finds the rescue still `arrived` — the other's update
        # matches nothing. Clearing the hash in the same write means the code
        # cannot be presented again even if the state guard were removed.
        updated = await self._repository.set_status(
            rescue["_id"],
            expected=[LifecycleState.ARRIVED],
            status=LifecycleState.VERIFIED,
            extra={
                "handover_code_hash": None,
                "handover_code_expires_at": None,
                "verified_at": datetime.now(UTC),
                "verified_by": ObjectId(user.id),
            },
        )
        if updated is None:
            raise ConflictError("This handover has already been confirmed.")

        await self._activity.record(
            actor=self._owner_actor(user),
            category=EventCategory.RESCUE,
            action="rescue_verified",
            subject=self._subject(rescue),
            detail=f"Handover of {listing['title']} confirmed by the owner.",
            context={"listing_id": str(listing["_id"])},
        )

        return self._to_response(updated, listing)

    async def mark_collected(
        self, rescue_id: str, *, user: UserResponse
    ) -> RescueResponse:
        """`verified -> collected -> completed`, closing the loop.

        Completion is not a separate endpoint. Once the owner has confirmed the
        handover and the rescuer has the food, nothing further can happen and
        there is no actor left to act — so `completed` is an internal step
        applied in the same call rather than a button nobody would press.
        """
        rescue, listing = await self._require_own_rescue(rescue_id, user)

        # Checked explicitly so the rescuer is told what is actually missing.
        # The generic transition error ("a rescue that is matched cannot become
        # collected") is accurate but says nothing a user can act on.
        if LifecycleState(rescue["status"]) is not LifecycleState.VERIFIED:
            raise ConflictError(
                "The handover has not been confirmed yet. Ask the food's owner "
                "to confirm it with your handover code."
            )

        collected = await self._apply_transition(
            rescue, LifecycleState.COLLECTED, extra={"collected_at": datetime.now(UTC)}
        )
        await self._activity.record(
            actor=rescuer_actor(user.id, user.full_name),
            category=EventCategory.RESCUE,
            action="rescue_collected",
            subject=self._subject(rescue),
            context={"listing_id": str(listing["_id"])},
        )

        completed = await self._apply_transition(
            collected,
            LifecycleState.COMPLETED,
            extra={"completed_at": datetime.now(UTC)},
        )

        # The listing follows the same canonical path: matched -> collected
        # -> completed.
        await self._listings.set_status(
            listing["_id"],
            expected=[LifecycleState.MATCHED],
            status=LifecycleState.COLLECTED,
        )
        await self._listings.set_status(
            listing["_id"],
            expected=[LifecycleState.COLLECTED],
            status=LifecycleState.COMPLETED,
        )

        await self._activity.record(
            actor=rescuer_actor(user.id, user.full_name),
            category=EventCategory.RESCUE,
            action="rescue_completed",
            subject=self._subject(rescue),
            detail=f"{listing['title']} rescued.",
            context={"listing_id": str(listing["_id"])},
        )

        refreshed = await self._listings.find_by_id(str(listing["_id"])) or listing
        return self._to_response(completed, refreshed)

    def _require_handover_authority(
        self,
        rescue: dict[str, Any],
        listing: dict[str, Any],
        user: UserResponse,
    ) -> None:
        """Who may confirm a handover.

        Answered entirely from fields the data model already carries, with
        nothing invented:

        * **The listing's owner** (`listings.owner_user_id`) — set on every
          listing, whether a consumer or a partner published it. For a
          consumer-published listing this is that consumer: the person actually
          handing the food over.
        * **A colleague at the owning business** — a user whose
          `users.partner_id` matches `listings.partner_id`. A restaurant's
          surplus is rarely handed over by whoever posted it.

        `partner_id` comes from the authenticated user record, never the
        request, so it cannot be forged.

        The rescuer is refused first and unconditionally, even in the edge case
        where they would otherwise qualify.
        """
        if str(rescue["rescuer_id"]) == user.id:
            raise ForbiddenError(
                "A rescuer cannot confirm their own handover."
            )

        if str(listing.get("owner_user_id")) == user.id:
            return

        listing_partner = listing.get("partner_id")
        if (
            listing_partner is not None
            and user.partner_id is not None
            and str(listing_partner) == user.partner_id
        ):
            return

        # 403 rather than 404: the caller had to know the rescue id to get
        # here, and the rescue's existence is not the secret — the authority
        # to confirm it is.
        raise ForbiddenError("You cannot confirm this handover.")

    @staticmethod
    def _owner_actor(user: UserResponse):
        return (
            partner_actor(user.partner_id or user.id, user.full_name)
            if user.role is AccountRole.PARTNER
            else rescuer_actor(user.id, user.full_name)
        )

    @staticmethod
    def _subject(rescue: dict[str, Any]) -> EventSubject:
        return EventSubject(
            type=SubjectType.RESCUE,
            id=str(rescue["_id"]),
            reference=rescue["reference"],
        )

    async def cancel(
        self, rescue_id: str, *, user: UserResponse, reason: str | None
    ) -> RescueResponse:
        """Give up a rescue, returning the listing to the pool."""
        rescue, listing = await self._require_own_rescue(rescue_id, user)

        updated = await self._apply_transition(
            rescue, LifecycleState.CANCELLED, extra={"cancel_reason": reason}
        )

        # The listing goes back to searching rather than its original status:
        # it has been offered once already, so it re-enters the pool actively
        # looking. `LISTING_TRANSITIONS` permits matched -> searching for
        # exactly this case.
        await self._listings.release(
            listing["_id"],
            rescue_id=rescue["_id"],
            restore_to=LifecycleState.SEARCHING,
        )

        await self._activity.record(
            actor=rescuer_actor(user.id, user.full_name),
            category=EventCategory.RESCUE,
            action="rescue_cancelled",
            subject=EventSubject(
                type=SubjectType.RESCUE,
                id=str(rescue["_id"]),
                reference=rescue["reference"],
            ),
            detail=reason or "Cancelled by the rescuer.",
            context={"listing_id": str(listing["_id"])},
        )

        refreshed = await self._listings.find_by_id(str(listing["_id"])) or listing
        return self._to_response(updated, refreshed)

    async def _transition(
        self, rescue_id: str, *, user: UserResponse, target: LifecycleState
    ) -> RescueResponse:
        rescue, listing = await self._require_own_rescue(rescue_id, user)
        updated = await self._apply_transition(rescue, target)

        await self._activity.record(
            actor=rescuer_actor(user.id, user.full_name),
            category=EventCategory.RESCUE,
            action=f"rescue_{target.value.lower()}",
            subject=EventSubject(
                type=SubjectType.RESCUE,
                id=str(rescue["_id"]),
                reference=rescue["reference"],
            ),
            context={"listing_id": str(listing["_id"])},
        )
        return self._to_response(updated, listing)

    async def _apply_transition(
        self,
        rescue: dict[str, Any],
        target: LifecycleState,
        *,
        extra: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Validate against the canonical table, then write under a guard."""
        current = LifecycleState(rescue["status"])
        if not can_transition(current, target, transitions=RESCUE_TRANSITIONS):
            raise ConflictError(
                f"A rescue that is {current.value} cannot become {target.value}."
            )

        updated = await self._repository.set_status(
            rescue["_id"], expected=[current], status=target, extra=extra
        )
        if updated is None:
            raise ConflictError("The rescue changed before that could be applied.")
        return updated

    # --------------------------------------------------------------- reads

    async def detail(self, rescue_id: str, *, user: UserResponse) -> RescueResponse:
        rescue, listing = await self._require_own_rescue(rescue_id, user)
        return self._to_response(rescue, listing)

    async def active_for_listing(
        self, listing_id: str, *, user: UserResponse
    ) -> RescueResponse:
        """The rescue currently holding one of the caller's listings.

        Without this the handover cannot happen at all: `GET /rescues/{id}` is
        scoped to the rescuer, so an owner has no way to discover the rescue
        they are being asked to confirm. Authorised by the same rule as
        verification, so it exposes nothing the owner could not already act on.

        The handover code is deliberately **not** included — the owner types in
        what the rescuer reads out, and an owner who could read the code would
        make the whole step meaningless.
        """
        listing = await self._listings.find_by_id(listing_id)
        if listing is None:
            raise NotFoundError("That listing does not exist.")

        rescue = await self._repository.find_active_for_listing(listing["_id"])
        if rescue is None:
            raise NotFoundError("Nobody is currently rescuing this listing.")

        self._require_handover_authority(rescue, listing, user)
        return self._to_response(rescue, listing)

    async def mine(
        self, *, user: UserResponse, active_only: bool, limit: int, offset: int
    ) -> RescuePage:
        limit = max(1, min(limit, MAX_PAGE_SIZE))
        offset = max(offset, 0)

        rows = await self._repository.find_by_rescuer(
            rescuer_id=ObjectId(user.id),
            active_only=active_only,
            limit=limit + 1,
            offset=offset,
        )
        has_more = len(rows) > limit
        rows = rows[:limit]

        items = []
        for row in rows:
            listing = await self._listings.find_by_id(str(row["listing_id"]))
            if listing is not None:
                items.append(self._to_response(row, listing))

        return RescuePage(
            items=items, limit=limit, offset=offset, has_more=has_more
        )

    # ------------------------------------------------------------- helpers

    async def _require_own_rescue(
        self, rescue_id: str, user: UserResponse
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        rescue = await self._repository.find_by_id(rescue_id)
        if rescue is None:
            raise NotFoundError("That rescue does not exist.")

        if str(rescue["rescuer_id"]) != user.id:
            # 404, not 403: a rescue id is not public, so confirming that this
            # one exists would tell a stranger something they had no way to
            # know. Listings are the opposite case and use 403.
            raise NotFoundError("That rescue does not exist.")

        listing = await self._listings.find_by_id(str(rescue["listing_id"]))
        if listing is None:
            raise NotFoundError("The listing for that rescue no longer exists.")
        return rescue, listing

    @staticmethod
    def _to_response(
        rescue: dict[str, Any],
        listing: dict[str, Any],
        *,
        handover_code: str | None = None,
    ) -> RescueResponse:
        """Explicit allowlist projection — no account fields, ever.

        `handover_code_hash` is deliberately not among the fields read here, so
        the stored secret has no route into a response. The plaintext appears
        only when a caller explicitly passes it, which happens in exactly one
        place: the rescuer's own `arrived` response.
        """
        status = LifecycleState(rescue["status"])
        location = listing["pickup_location"]
        longitude, latitude = location["point"]["coordinates"]
        summary = ListingService._summary_fields(listing, None)

        return RescueResponse(
            id=str(rescue["_id"]),
            reference=rescue["reference"],
            status=status,
            stage=to_rescue_stage(status),
            is_active=status in RESCUE_ACTIVE_STATES,
            distance_km=rescue.get("distance_km"),
            handover_code=handover_code,
            handover_code_expires_at=(
                rescue.get("handover_code_expires_at") if handover_code else None
            ),
            cancel_reason=rescue.get("cancel_reason"),
            created_at=rescue["created_at"],
            updated_at=rescue["updated_at"],
            listing=RescueListingSnapshot(
                id=str(listing["_id"]),
                reference=listing["reference"],
                title=listing["title"],
                category=summary["category"],
                quantity_label=summary["quantity_label"],
                servings=summary["servings"],
                pickup_location=PickupLocationResponse(
                    label=location["label"],
                    locality=location.get("locality"),
                    latitude=latitude,
                    longitude=longitude,
                    pickup_point=location.get("pickup_point"),
                ),
                pickup_from=listing["pickup_from"],
                pickup_until=listing["pickup_until"],
                shared_by=listing.get("owner_display_name", "FoodLoop member"),
                shared_by_verified=summary["shared_by_verified"],
                photo_url=listing.get("photo_url"),
                description=listing.get("description"),
                tags=listing.get("tags", []),
            ),
        )


def _as_utc(value: datetime) -> datetime:
    """MongoDB returns naive UTC datetimes; comparisons need them aware."""
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def require_consumer_account(user: UserResponse) -> None:
    """Rescuing is a consumer action.

    A partner is a business publishing surplus, not collecting it. The check is
    here rather than as a route guard only because the same service is reused
    by reads that both roles may perform.
    """
    if user.role is not AccountRole.CONSUMER:
        raise ForbiddenError("Only consumer accounts can rescue food.")


def validate_object_id(value: str, *, field: str) -> None:
    try:
        ObjectId(value)
    except (InvalidId, TypeError) as exc:
        raise ValidationError(f"{field} is not a valid identifier.") from exc
