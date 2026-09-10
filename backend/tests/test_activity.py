"""Activity event foundation tests."""

from pymongo.errors import PyMongoError

from app.features.activity.repository import ActivityEventRepository
from app.features.activity.schemas import (
    ActivityEvent,
    ActorKind,
    EventCategory,
    EventOutcome,
    EventSubject,
    SubjectType,
)
from app.features.activity.service import (
    ActivityService,
    operator_actor,
    system_actor,
)


class FakeActivityRepository(ActivityEventRepository):
    """Records appends in memory. `failing=True` simulates a database outage."""

    def __init__(self, *, failing: bool = False) -> None:
        self.events: list[ActivityEvent] = []
        self._failing = failing

    async def append(self, event: ActivityEvent) -> str:
        if self._failing:
            raise PyMongoError("connection reset")
        self.events.append(event)
        return f"ev-{len(self.events)}"


async def test_record_appends_the_event():
    repository = FakeActivityRepository()
    service = ActivityService(repository)

    event_id = await service.record(
        actor=system_actor("Smart Escalation"),
        category=EventCategory.ESCALATION,
        action="Expanded rescue coverage",
        subject=EventSubject(
            type=SubjectType.LISTING, id="abc123", reference="FL-20481"
        ),
        detail="No rescuer within 3 km after 12 minutes.",
        zone_id="zone-downtown",
    )

    assert event_id == "ev-1"
    [event] = repository.events
    assert event.actor.kind is ActorKind.SYSTEM
    assert event.category is EventCategory.ESCALATION
    assert event.outcome is EventOutcome.OK
    assert event.subject.reference == "FL-20481"
    assert event.zone_id == "zone-downtown"
    assert event.created_at.tzinfo is not None


async def test_recording_never_raises_when_the_database_fails():
    """A dropped log line must not roll back the operation that triggered it."""
    service = ActivityService(FakeActivityRepository(failing=True))

    result = await service.record(
        actor=operator_actor("u1", "ops-desk-2"),
        category=EventCategory.RESCUE,
        action="Reassigned rescue",
    )

    assert result is None


async def test_events_are_immutable():
    event = ActivityEvent(
        actor=system_actor("Expiry sweep"),
        category=EventCategory.RESCUE,
        action="Expired listing",
    )

    try:
        event.action = "something else"
    except (AttributeError, ValueError) as exc:
        assert "frozen" in str(exc).lower() or isinstance(exc, AttributeError)
    else:  # pragma: no cover - would mean the audit trail is rewritable
        raise AssertionError("ActivityEvent must be immutable")


async def test_system_actor_has_no_id():
    # System automation has no user record; an id would be a fabrication.
    assert system_actor("Expiry sweep").id is None
    assert operator_actor("u1", "ops-desk-2").id == "u1"


def test_vocabulary_matches_the_console():
    # These strings are parsed directly by the dashboard's TypeScript unions.
    assert {a.value for a in ActorKind} == {
        "operator",
        "system",
        "partner",
        "rescuer",
    }
    assert {c.value for c in EventCategory} == {
        "rescue",
        "escalation",
        "coverage",
        "account",
        "auth",
    }
    assert {o.value for o in EventOutcome} == {"ok", "warning", "failed"}
