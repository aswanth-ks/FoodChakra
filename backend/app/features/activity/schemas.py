"""The activity event contract.

`activity_events` is append-only. It serves three purposes at once, which is
why it is worth getting the shape right before anything writes to it:

1. **Audit** — the console's Activity Log answers "who decided this", which is
   only possible if actor kind is recorded rather than inferred.
2. **Analytics** — the funnel, conversion rates and bottleneck views are
   aggregations over this collection. There is no second events table.
3. **Predictive Demand** (much later) — needs a timestamped, zone-tagged
   history of what happened where. Capturing it from day one costs almost
   nothing; reconstructing it retroactively is impossible.

The vocabulary below deliberately mirrors `dashboard/src/features/activity/data/
activityTypes.ts` value-for-value so the console parses these documents with no
translation layer.
"""

from datetime import UTC, datetime
from enum import StrEnum
from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class ActorKind(StrEnum):
    """Who or what caused the entry.

    The distinction is the point of the audit log: `OPERATOR` is a named person
    at a console, `SYSTEM` is automation acting on its own rules, `PARTNER` and
    `RESCUER` are the apps. A log that blurs these cannot answer "who decided
    this" — which is the only question anyone asks it in an incident.
    """

    OPERATOR = "operator"
    SYSTEM = "system"
    PARTNER = "partner"
    RESCUER = "rescuer"


class EventCategory(StrEnum):
    """What kind of thing happened. Drives the console's category filter."""

    RESCUE = "rescue"
    ESCALATION = "escalation"
    COVERAGE = "coverage"
    ACCOUNT = "account"
    AUTH = "auth"


class EventOutcome(StrEnum):
    """How the entry ended."""

    OK = "ok"
    WARNING = "warning"
    FAILED = "failed"


class SubjectType(StrEnum):
    """The kind of thing an event acted on."""

    LISTING = "listing"
    RESCUE = "rescue"
    USER = "user"
    PARTNER = "partner"
    ESCALATION = "escalation"
    FALLBACK_CASE = "fallback_case"
    ZONE = "zone"


class EventActor(BaseModel):
    """Who acted. `id` is absent for `SYSTEM`, which has no user record."""

    kind: ActorKind
    id: str | None = None
    #: Display name: "ops-desk-2", "Smart Escalation", "Green Leaf Kitchen".
    name: str


class EventSubject(BaseModel):
    """What was acted upon."""

    type: SubjectType
    id: str
    #: Human-facing reference, e.g. "FL-20481". Denormalised on purpose: the
    #: audit log must stay readable even if the subject is later deleted.
    reference: str | None = None


class ActivityEvent(BaseModel):
    """One append-only audit record.

    Immutable by construction (`frozen=True`): an audit entry that can be
    edited is not an audit entry. There is deliberately no update or delete
    path anywhere in this feature.
    """

    model_config = ConfigDict(frozen=True)

    actor: EventActor
    category: EventCategory
    outcome: EventOutcome = EventOutcome.OK
    subject: EventSubject | None = None

    #: Imperative summary: "Expanded rescue coverage".
    action: str
    #: Full sentence shown in the console's inspection panel.
    detail: str | None = None
    #: Where it happened, when that is known. Predictive Demand needs this.
    zone_id: str | None = None
    #: Anything category-specific. Kept loose on purpose — a rigid schema here
    #: would force a migration every time a feature records something new.
    context: dict[str, Any] = Field(default_factory=dict)

    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
