"""Activity recording — the seam every future feature writes its audit through.

Usage from another feature's service, once those features exist:

    await self._activity.record(
        actor=system_actor("Smart Escalation"),
        category=EventCategory.ESCALATION,
        action="Expanded rescue coverage",
        subject=EventSubject(type=SubjectType.LISTING, id=..., reference="FL-20481"),
        detail="No rescuer within 3 km after 12 minutes; radius raised to 5 km.",
        zone_id=...,
    )

No concrete event types (`listing_created`, `rescue_completed`, …) are defined
here yet. They belong to the features that emit them, in the stages that build
those features — declaring them now would be guessing at fields that do not
exist.
"""

import logging
from typing import Any

from pymongo.errors import PyMongoError

from app.features.activity.repository import ActivityEventRepository
from app.features.activity.schemas import (
    ActivityEvent,
    ActorKind,
    EventActor,
    EventCategory,
    EventOutcome,
    EventSubject,
)

logger = logging.getLogger(__name__)


class ActivityService:
    """Records audit events.

    **Recording never raises.** A failed audit write must not roll back the
    business operation that triggered it — losing one log line is bad, but
    failing a rescue claim because the audit collection hiccuped is worse, and
    would make the audit trail a single point of failure for the whole product.
    Failures are logged at ERROR so they stay visible.

    That trade-off is only acceptable because nothing enforces business rules
    from this collection. If anything ever reads `activity_events` to make a
    decision, this policy has to be revisited.
    """

    def __init__(self, repository: ActivityEventRepository) -> None:
        self._repository = repository

    async def record(
        self,
        *,
        actor: EventActor,
        category: EventCategory,
        action: str,
        subject: EventSubject | None = None,
        outcome: EventOutcome = EventOutcome.OK,
        detail: str | None = None,
        zone_id: str | None = None,
        context: dict[str, Any] | None = None,
    ) -> str | None:
        """Append one event. Returns its id, or None if the write failed."""
        event = ActivityEvent(
            actor=actor,
            category=category,
            action=action,
            subject=subject,
            outcome=outcome,
            detail=detail,
            zone_id=zone_id,
            context=context or {},
        )
        try:
            return await self._repository.append(event)
        except PyMongoError as exc:
            logger.error(
                "Activity event dropped (%s/%s on %s): %s",
                category,
                action,
                subject.id if subject else "-",
                exc,
            )
            return None


# ------------------------------------------------------------ actor helpers
#
# Actors are constructed the same way everywhere so the console's "who did
# this" filter stays trustworthy.


def system_actor(name: str) -> EventActor:
    """Automation acting on its own rules. Has no user record, so no id."""
    return EventActor(kind=ActorKind.SYSTEM, name=name)


def operator_actor(user_id: str, name: str) -> EventActor:
    """A named person at an operations console."""
    return EventActor(kind=ActorKind.OPERATOR, id=user_id, name=name)


def rescuer_actor(user_id: str, name: str) -> EventActor:
    """A consumer acting through the mobile app."""
    return EventActor(kind=ActorKind.RESCUER, id=user_id, name=name)


def partner_actor(partner_id: str, name: str) -> EventActor:
    """A business acting through the partner app."""
    return EventActor(kind=ActorKind.PARTNER, id=partner_id, name=name)
