"""Index bootstrap.

Every index FoodLoop relies on is declared here and created idempotently at
startup, so a fresh environment is never silently missing one. Schemas are in
`docs/BACKEND_CONTRACT.md` §3; this file is the executable half of that
document.

Two categories carry real weight rather than being routine tuning:

* **`2dsphere`** — the Explore screen's entire query is a `$near`, and the
  dynamic rescue radius is a `$geoWithin`. Without these indexes those
  features cannot be written at all, not merely written slowly.
* **The rescue claim index** — see `_rescue_indexes`, which explains at length
  why a partial unique index is the only correct place to enforce
  "one active rescue per listing".

Index creation is idempotent: MongoDB ignores a `create_index` whose name and
definition already match. Changing an existing index's *definition* under the
same name is an error, so every index here is explicitly named — an unnamed
index gets an auto-generated name that changes when the keys change, which
silently leaves the old index behind.
"""

import logging

from motor.motor_asyncio import AsyncIOMotorDatabase
from pymongo import ASCENDING, DESCENDING, GEOSPHERE, IndexModel

from app.db import collections as col
from app.shared.lifecycle import RESCUE_ACTIVE_STATES

logger = logging.getLogger(__name__)


def _user_indexes() -> list[IndexModel]:
    return [
        # Login, and the uniqueness guarantee behind registration.
        IndexModel([("email", ASCENDING)], name="uniq_email", unique=True),
        IndexModel([("role", ASCENDING)], name="by_role"),
        # Finding consumers near a listing when it is published.
        IndexModel([("rescuer.last_location", GEOSPHERE)], name="geo_rescuer_location"),
        # The console's Rescuers directory filters on exactly this pair.
        IndexModel(
            [("rescuer.status", ASCENDING), ("rescuer.verification", ASCENDING)],
            name="by_rescuer_status_verification",
        ),
    ]


def _partner_indexes() -> list[IndexModel]:
    return [
        IndexModel([("location", GEOSPHERE)], name="geo_location"),
        IndexModel([("status", ASCENDING)], name="by_status"),
        IndexModel([("zone_id", ASCENDING)], name="by_zone"),
    ]


def _listing_indexes() -> list[IndexModel]:
    return [
        # Explore: "surplus near me". The single most-hit query in the product.
        IndexModel(
            [("pickup_location.point", GEOSPHERE)], name="geo_pickup_location"
        ),
        # The expiry / escalation sweep. Without this compound index the sweep
        # is a full collection scan on every tick, which is the difference
        # between a background job and an outage.
        IndexModel(
            [("status", ASCENDING), ("expires_at", ASCENDING)],
            name="by_status_expires_at",
        ),
        # "My listings", newest first — Activity tab and Partner Surplus tabs.
        IndexModel(
            [("owner_user_id", ASCENDING), ("created_at", DESCENDING)],
            name="by_owner_created",
        ),
        IndexModel(
            [("partner_id", ASCENDING), ("status", ASCENDING)],
            name="by_partner_status",
        ),
        # Human-facing reference ("FL-20481") used across the console.
        IndexModel([("reference", ASCENDING)], name="uniq_reference", unique=True),
    ]


def _rescue_indexes() -> list[IndexModel]:
    """Rescue indexes, including the one that prevents double-booking.

    **The claim race.** Two consumers open the same listing and both tap
    "Rescue this" within the same few milliseconds. Application-level
    protection ("check for an existing rescue, then insert") loses this race:
    both requests read "no active rescue", both insert, and the surplus is
    promised to two people. The window is small, which makes it worse — it
    passes every manual test and fails in production.

    Correctness therefore has to come from the database, and it takes two
    cooperating pieces:

    1. **This partial unique index** — at most one rescue document per
       `listing_id` may exist in a non-terminal state. The `partialFilterExpression`
       is what makes it usable: a plain unique index on `listing_id` would also
       forbid a *second* rescue after the first was cancelled, permanently
       burning the listing. Cancelled, completed, expired and no-show rescues
       fall outside the filter and stop occupying their listing, so a listing
       can legitimately be re-claimed after a failed attempt.

    2. **An atomic claim on the listing** (Stage E) — a single
       `find_one_and_update` moving the listing from `published`/`searching` to
       `matched`. Exactly one concurrent caller sees the pre-update document.

    Together the loser of the race gets a duplicate-key error, which the
    repository translates into `ConflictError` → `409 CONFLICT`. That is
    exactly what the mobile app's rescue confirmation sheet needs to show
    "someone just claimed this".

    The filter's state list is derived from `RESCUE_ACTIVE_STATES` rather than
    hardcoded, so adding a lifecycle state cannot leave the index behind.
    """
    active = sorted(state.value for state in RESCUE_ACTIVE_STATES)
    return [
        IndexModel(
            [("listing_id", ASCENDING)],
            name="uniq_active_rescue_per_listing",
            unique=True,
            partialFilterExpression={"status": {"$in": active}},
        ),
        # A consumer's own rescue history — Activity and History tabs.
        IndexModel(
            [("rescuer_id", ASCENDING), ("created_at", DESCENDING)],
            name="by_rescuer_created",
        ),
        # The console's rescue queue.
        IndexModel(
            [("status", ASCENDING), ("updated_at", DESCENDING)],
            name="by_status_updated",
        ),
        # Live map: where the rescuers currently are.
        IndexModel([("rescuer_location", GEOSPHERE)], name="geo_rescuer_location"),
    ]


def _escalation_indexes() -> list[IndexModel]:
    return [
        IndexModel([("listing_id", ASCENDING)], name="by_listing"),
        IndexModel(
            [("state", ASCENDING), ("stage", ASCENDING)], name="by_state_stage"
        ),
        IndexModel(
            [("zone_id", ASCENDING), ("state", ASCENDING)], name="by_zone_state"
        ),
    ]


def _fallback_case_indexes() -> list[IndexModel]:
    return [
        # The routing sweep: open cases, most urgent first.
        IndexModel(
            [("state", ASCENDING), ("recoverable_until", ASCENDING)],
            name="by_state_recoverable_until",
        ),
        IndexModel([("zone_id", ASCENDING)], name="by_zone"),
        # Recovery history, grouped by the tier the surplus landed on.
        IndexModel(
            [("final_tier", ASCENDING), ("created_at", DESCENDING)],
            name="by_tier_created",
        ),
    ]


def _recovery_partner_indexes() -> list[IndexModel]:
    return [
        IndexModel([("location", GEOSPHERE)], name="geo_location"),
        IndexModel([("tier", ASCENDING), ("state", ASCENDING)], name="by_tier_state"),
    ]


def _zone_indexes() -> list[IndexModel]:
    return [
        IndexModel([("boundary", GEOSPHERE)], name="geo_boundary"),
        IndexModel([("status", ASCENDING)], name="by_status"),
    ]


def _notification_indexes() -> list[IndexModel]:
    return [
        IndexModel(
            [("user_id", ASCENDING), ("created_at", DESCENDING)],
            name="by_user_created",
        ),
        # The unread badge count.
        IndexModel(
            [("user_id", ASCENDING), ("read_at", ASCENDING)], name="by_user_read"
        ),
    ]


def _activity_event_indexes() -> list[IndexModel]:
    return [
        # The audit feed is always chronological, newest first.
        IndexModel([("created_at", DESCENDING)], name="by_created"),
        IndexModel(
            [("category", ASCENDING), ("created_at", DESCENDING)],
            name="by_category_created",
        ),
        # "Everything that happened to this listing/rescue".
        IndexModel([("subject.id", ASCENDING)], name="by_subject"),
    ]


#: Collection name -> its indexes. Iterated at startup.
INDEX_SPECS: dict[str, list[IndexModel]] = {
    col.USERS: _user_indexes(),
    col.PARTNERS: _partner_indexes(),
    col.LISTINGS: _listing_indexes(),
    col.RESCUES: _rescue_indexes(),
    col.ESCALATIONS: _escalation_indexes(),
    col.FALLBACK_CASES: _fallback_case_indexes(),
    col.RECOVERY_PARTNERS: _recovery_partner_indexes(),
    col.ZONES: _zone_indexes(),
    col.NOTIFICATIONS: _notification_indexes(),
    col.ACTIVITY_EVENTS: _activity_event_indexes(),
}


async def ensure_indexes(db: AsyncIOMotorDatabase) -> None:
    """Create every required index that is not already there.

    The upfront ping is not redundant. Each call against an unreachable server
    blocks for the full server-selection timeout, so without this probe a
    database outage would stall startup for ten times that — and `/health` is
    meant to come up fast and *report* the outage, not disappear behind it. One
    failed probe short-circuits the whole bootstrap.

    Missing indexes are created; existing ones are left alone. This used to
    call `create_indexes` unconditionally for all ten collections, which is
    idempotent but not free: measured against the deployed database it cost
    **6.4 seconds on every boot**, re-validating thirty-one index
    specifications that were already in place. On a host that scales to zero
    that is 6.4 seconds added to the first request after every idle period.
    Listing what exists first turns the common case — everything already
    present — into ten cheap reads and no writes.

    The check is by index *name*. An index whose definition changes while
    keeping its name will therefore be skipped rather than rejected, so a
    changed definition needs a new name or a deliberate migration. That is the
    usual trade for this pattern, and it is worth stating: the previous code
    would have raised `IndexOptionsConflict` and refused to start.
    """
    await db.command("ping")

    created_total = 0
    for collection_name, models in INDEX_SPECS.items():
        collection = db[collection_name]
        existing = {index["name"] async for index in collection.list_indexes()}
        missing = [
            model for model in models if model.document["name"] not in existing
        ]
        if not missing:
            continue

        created = await collection.create_indexes(missing)
        created_total += len(created)
        logger.info(
            "Indexes created on %r: %s", collection_name, ", ".join(created)
        )

    logger.info(
        "Index bootstrap complete — %d created, %d required across %d collections",
        created_total,
        sum(len(models) for models in INDEX_SPECS.values()),
        len(INDEX_SPECS),
    )
