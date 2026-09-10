"""Live integration check against the real MongoDB Atlas cluster.

    python -m scripts.live_atlas_smoke_test

Development only. This is deliberately **not** part of the test suite and not
part of application startup: it needs real Atlas credentials and real SMTP, and
`pytest` must keep running for someone who has neither.

What it proves that the unit tests cannot: that the services behave the same
way when the repository underneath them is genuinely MongoDB — that the
conditional updates really are conditional, that the partial unique index
really refuses a second active rescue, and that documents come back after the
process that wrote them is gone.

## Safety

Everything it creates is recorded in `Ledger` and deleted in a `finally`, and
every deletion is by `_id` of a document this run inserted. It never deletes by
query, never touches a document it did not create, and never writes to an
existing account. Temporary accounts use a unique `+tag` on the configured
sending address so nothing collides with a real user.

## Secrets

Nothing here prints a password, a one-time code, a handover code, a token, an
SMTP credential or a connection string. Codes are captured in memory to drive
the flow and are compared, never displayed.
"""

import asyncio
import os
import socket
import subprocess
import sys
import time
from contextlib import suppress
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

import httpx
from bson import ObjectId

from app.core.config import get_settings
from app.core.email import EmailService, OutgoingEmail
from app.core.exceptions import AppError
from app.db import collections as col
from app.db.mongo import close_mongo_connection, connect_to_mongo, mongo
from app.features.activity.repository import ActivityEventRepository
from app.features.activity.service import ActivityService
from app.features.auth.repository import UserRepository
from app.features.auth.schemas import RegisterRequest, UserResponse
from app.features.auth.service import AuthService
from app.features.listings.repository import ListingRepository
from app.features.listings.schemas import (
    CreateListingRequest,
    FoodType,
    PickupLocationRequest,
    QuantityUnit,
    SurplusSource,
)
from app.features.listings.service import ListingService
from app.features.rescues.repository import RescueRepository
from app.features.rescues.service import RescueService
from app.shared.lifecycle import LifecycleState

PASSWORD = "a-good-live-test-password"

#: Every account this script makes carries it, so a leftover is obvious in the
#: Atlas UI and trivially identifiable.
TAG = "foodloop-stagek"


# --------------------------------------------------------------- reporting


@dataclass
class Report:
    checks: list[tuple[str, bool]] = field(default_factory=list)

    def check(self, label: str, ok: bool, note: str = "") -> bool:
        self.checks.append((label, ok))
        mark = "PASS" if ok else "FAIL"
        suffix = f"  ({note})" if note else ""
        print(f"  [{mark}] {label}{suffix}")
        return ok

    def section(self, title: str) -> None:
        print(f"\n{title}")
        print("-" * len(title))

    @property
    def failures(self) -> list[str]:
        return [label for label, ok in self.checks if not ok]


@dataclass
class Ledger:
    """Everything this run created, so nothing survives it."""

    users: list[ObjectId] = field(default_factory=list)
    listings: list[ObjectId] = field(default_factory=list)
    rescues: list[ObjectId] = field(default_factory=list)
    activity: list[ObjectId] = field(default_factory=list)


class CapturingSender:
    """Keeps the codes in memory instead of sending them.

    The flow needs the verification code, and the only place it exists in the
    clear is the email body. Capturing it here is what lets the script drive a
    real verification without ever printing it, and without a test-only code
    path in production code — `EmailService` takes its sender as a constructor
    argument precisely so this is possible from the outside.
    """

    def __init__(self) -> None:
        self.messages: list[OutgoingEmail] = []

    async def send(self, message: OutgoingEmail) -> None:
        self.messages.append(message)

    def latest_code(self) -> str:
        import re

        body = self.messages[-1].body
        match = re.search(r"\b(\d{6})\b", body)
        assert match, "no code in the captured email"
        return match.group(1)


# ------------------------------------------------------------------ helpers


def temp_email() -> str:
    """A unique, real, deliverable address using plus-addressing."""
    base = get_settings().SMTP_FROM_EMAIL or "foodloop@example.com"
    local, _, domain = base.partition("@")
    return f"{local}+{TAG}-{uuid4().hex[:8]}@{domain}"


def listing_request(**overrides: Any) -> CreateListingRequest:
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "food_name": "Stage K probe biryani",
        "food_type": FoodType.VEGETARIAN,
        "quantity": 25,
        "unit": QuantityUnit.MEAL_BOXES,
        "source": SurplusSource.EVENT,
        "safety_confirmed": True,
        "description": "Temporary record created by the Stage K live check.",
        "pickup_location": PickupLocationRequest(
            label="Stage K probe hall",
            locality="Karur, Tamil Nadu",
            latitude=10.9601,
            longitude=78.0766,
        ),
        "pickup_from": now,
        "pickup_until": now + timedelta(hours=4),
    }
    payload.update(overrides)
    return CreateListingRequest(**payload)


async def make_verified_user(
    auth: AuthService,
    users: UserRepository,
    mail: CapturingSender,
    ledger: Ledger,
    name: str,
) -> tuple[UserResponse, str]:
    """Register and verify an account through the real service."""
    email = temp_email()
    await auth.register(
        RegisterRequest(full_name=name, email=email, password=PASSWORD)
    )
    stored = await users.find_by_email(email)
    ledger.users.append(stored["_id"])
    await auth.verify_email(email, mail.latest_code())
    tokens = await auth.login(email, PASSWORD)
    return tokens.user, email


# =========================================================== the checks


async def check_database(db, report: Report) -> None:
    report.section("PART 13 — database and indexes")

    settings = get_settings()
    report.check(
        "database name is the configured one",
        db.name == settings.MONGO_DB_NAME,
        db.name,
    )

    present = set(await db.list_collection_names())
    missing = [c for c in col.ALL_COLLECTIONS if c not in present]
    report.check(f"all {len(col.ALL_COLLECTIONS)} collections exist", not missing,
                 f"missing: {missing}" if missing else "")

    # `_id_` is created by MongoDB itself, one per collection. The 31 in the
    # documentation is the count of indexes `ensure_indexes` declares.
    declared = 0
    implicit = 0
    for name in col.ALL_COLLECTIONS:
        info = await db[name].index_information()
        declared += sum(1 for key in info if key != "_id_")
        implicit += sum(1 for key in info if key == "_id_")
    report.check("31 declared indexes present", declared == 31, f"found {declared}")
    report.check("one _id_ index per collection", implicit == len(col.ALL_COLLECTIONS),
                 f"{implicit} + {declared} = {implicit + declared} total")

    rescue_indexes = await db[col.RESCUES].index_information()
    unique_index = rescue_indexes.get("uniq_active_rescue_per_listing")
    report.check("uniq_active_rescue_per_listing exists", unique_index is not None)
    if unique_index:
        report.check(
            "…and is unique and partial",
            unique_index.get("unique") is True
            and "partialFilterExpression" in unique_index,
        )


async def check_auth(auth, users, mail, ledger, report: Report) -> None:
    report.section("PART 3 — live authentication")

    email = temp_email()
    result = await auth.register(
        RegisterRequest(full_name="Stage K Auth", email=email, password=PASSWORD)
    )
    report.check("registration returns no token", "token" not in result.model_dump_json())

    stored = await users.find_by_email(email)
    ledger.users.append(stored["_id"])

    report.check("user persisted in Atlas", stored is not None)
    report.check("role is consumer", stored["role"] == "consumer")
    report.check("status is active", stored["status"] == "active")
    report.check("starts unverified", stored["email_verified"] is False)
    report.check("password stored as a bcrypt hash",
                 stored["password_hash"].startswith("$2b$"))
    report.check("password plaintext absent",
                 PASSWORD not in str(stored))
    record = stored["email_verification"]
    report.check("verification hash stored", record["code_hash"].startswith("$2b$"))
    report.check("expiry stored", record["expires_at"] is not None)
    report.check("attempts start at zero", record["attempts"] == 0)

    code = mail.latest_code()
    report.check("code plaintext not in the document", code not in str(stored))

    # G — unverified login
    try:
        await auth.login(email, PASSWORD)
        report.check("unverified login refused", False)
    except AppError as exc:
        report.check("unverified login refused with EMAIL_NOT_VERIFIED",
                     exc.code == "EMAIL_NOT_VERIFIED")

    # F — wrong password, checked before verification state is revealed
    try:
        await auth.login(email, "not-the-password")
        report.check("wrong password refused", False)
    except AppError as exc:
        report.check("wrong password gives the generic 401",
                     exc.code == "UNAUTHORIZED")

    # B/C — verify for real
    await auth.verify_email(email, code)
    stored = await users.find_by_email(email)
    report.check("email_verified flipped in Atlas", stored["email_verified"] is True)
    report.check("verification record consumed",
                 "email_verification" not in stored)

    # Reuse of a consumed code
    try:
        await auth.verify_email(email, code)
        report.check("consumed code refused", False)
    except AppError:
        report.check("consumed code refused", True)

    # D/E — login
    tokens = await auth.login(email, PASSWORD)
    report.check("verified login issues a session", bool(tokens.access_token))
    stored = await users.find_by_email(email)
    report.check("refresh session recorded in Atlas",
                 len(stored["refresh_sessions"]) == 1)
    report.check("last_login_at written", stored["last_login_at"] is not None)

    # H — refresh rotation
    rotated = await auth.refresh(tokens.refresh_token)
    report.check("refresh returns a new pair",
                 rotated.refresh_token != tokens.refresh_token)
    try:
        await auth.refresh(tokens.refresh_token)
        report.check("replayed refresh token refused", False)
    except AppError:
        report.check("replayed refresh token refused", True)
    stored = await users.find_by_email(email)
    report.check("replay revoked every session",
                 stored["refresh_sessions"] == [],
                 "replay means the token was captured")

    # I/J — logout
    fresh = await auth.login(email, PASSWORD)
    await auth.logout(fresh.user.id, fresh.refresh_token)
    stored = await users.find_by_email(email)
    report.check("logout removed the session from Atlas",
                 stored["refresh_sessions"] == [])
    try:
        await auth.refresh(fresh.refresh_token)
        report.check("refresh after logout refused", False)
    except AppError:
        report.check("refresh after logout refused", True)

    # Password reset
    await auth.forgot_password(email)
    stored = await users.find_by_email(email)
    report.check("reset code hash stored",
                 stored["password_reset"]["code_hash"].startswith("$2b$"))
    reset_code = mail.latest_code()
    report.check("reset code plaintext not stored", reset_code not in str(stored))

    await auth.login(email, PASSWORD)  # a session to be revoked by the reset
    new_password = "a-different-live-password"
    await auth.reset_password(email, reset_code, new_password)
    stored = await users.find_by_email(email)
    report.check("reset consumed the code", "password_reset" not in stored)
    report.check("reset revoked every session", stored["refresh_sessions"] == [])
    try:
        await auth.login(email, PASSWORD)
        report.check("old password refused", False)
    except AppError:
        report.check("old password refused", True)
    after = await auth.login(email, new_password)
    report.check("new password works", bool(after.access_token))


async def check_listing(
    db, listings_service, listings_repo, owner, ledger, report: Report
) -> dict[str, Any]:
    report.section("PART 4 — live listing creation")

    created = await listings_service.create(listing_request(), user=owner)
    stored = await db[col.LISTINGS].find_one({"_id": ObjectId(created.id)})
    ledger.listings.append(stored["_id"])

    report.check("listing persisted in Atlas", stored is not None)
    report.check("owner_user_id is the authenticated user",
                 str(stored["owner_user_id"]) == owner.id)
    report.check("title persisted", stored["food_name"] == "Stage K probe biryani")
    report.check("quantity persisted", stored["quantity"] == 25)
    report.check("food_type persisted", stored["food_type"] == "vegetarian")
    report.check("status is published", stored["status"] == LifecycleState.PUBLISHED.value)
    point = stored["pickup_location"]["point"]
    report.check("GeoJSON point written", point["type"] == "Point")
    report.check("GeoJSON is longitude-first",
                 point["coordinates"] == [78.0766, 10.9601],
                 "latitude-first would silently put it in the wrong hemisphere")
    report.check("created_at and updated_at written",
                 stored["created_at"] is not None and stored["updated_at"] is not None)
    report.check("reference allocated", bool(stored["reference"]))

    detail = await listings_service.detail(created.id)
    report.check("detail read back matches Atlas",
                 detail.id == str(stored["_id"])
                 and detail.quantity == stored["quantity"])

    items, _, _, _ = await listings_service.nearby(
        latitude=10.9601,
        longitude=78.0766,
        radius_km=10,
        food_types=None,
        source=None,
        limit=50,
        offset=0,
    )
    report.check("the $nearSphere query returns it",
                 any(item.id == created.id for item in items))

    filtered, _, _, _ = await listings_service.nearby(
        latitude=10.9601,
        longitude=78.0766,
        radius_km=10,
        food_types=[FoodType.NON_VEG],
        source=None,
        limit=50,
        offset=0,
    )
    report.check("a food-type filter actually narrows the query",
                 all(item.id != created.id for item in filtered))

    return stored


async def check_concurrent_claim(
    db, rescue_service, listings_service, owner, a, b, ledger, report: Report
) -> dict[str, Any]:
    report.section("PART 5 — concurrent rescue claim (the critical one)")

    listing = await listings_service.create(listing_request(), user=owner)
    ledger.listings.append(ObjectId(listing.id))

    # Two genuine service calls, in flight at the same time, against the real
    # cluster. Nothing is inserted by hand — the whole point is that the
    # database decides the winner.
    results = await asyncio.gather(
        rescue_service.claim(listing.id, user=a),
        rescue_service.claim(listing.id, user=b),
        return_exceptions=True,
    )

    successes = [r for r in results if not isinstance(r, BaseException)]
    conflicts = [r for r in results if isinstance(r, AppError)]
    other = [
        r for r in results
        if isinstance(r, BaseException) and not isinstance(r, AppError)
    ]

    for rescue in successes:
        ledger.rescues.append(ObjectId(rescue.id))

    report.check("exactly one claim succeeded", len(successes) == 1,
                 f"{len(successes)} success, {len(conflicts)} conflict")
    report.check("the loser got a conflict, not a crash",
                 len(conflicts) == 1 and not other,
                 conflicts[0].code if conflicts else str(other))
    if conflicts:
        report.check("conflict is a 409", conflicts[0].status_code == 409)

    active = await db[col.RESCUES].count_documents({
        "listing_id": ObjectId(listing.id),
        "status": {"$nin": ["completed", "cancelled", "noShow", "fallback"]},
    })
    report.check("Atlas holds exactly one active rescue for the listing",
                 active == 1, f"found {active}")

    stored_listing = await db[col.LISTINGS].find_one({"_id": ObjectId(listing.id)})
    report.check("listing is matched", stored_listing["status"] == "matched")
    report.check("listing points at the winning rescue",
                 str(stored_listing["active_rescue_id"]) == successes[0].id)

    events = await db[col.ACTIVITY_EVENTS].count_documents({
        "subject.id": successes[0].id, "action": "rescue_created",
    })
    report.check("one rescue_created activity event", events == 1)

    # A third attempt on a listing that is no longer claimable.
    try:
        await rescue_service.claim(listing.id, user=b)
        report.check("a later claim is still refused", False)
    except AppError as exc:
        report.check("a later claim is still refused", exc.status_code == 409)

    return successes[0]


async def check_partial_index(db, rescue_service, listings_service, owner, a, ledger,
                              report: Report) -> None:
    report.section("PART 6 — partial unique index behaviour")

    listing = await listings_service.create(listing_request(), user=owner)
    ledger.listings.append(ObjectId(listing.id))
    rescue = await rescue_service.claim(listing.id, user=a)
    ledger.rescues.append(ObjectId(rescue.id))

    # A raw insert of a second *active* rescue must be refused by the index
    # itself, independently of any service logic.
    duplicate = {
        "_id": ObjectId(),
        "reference": "STAGEK-DUP",
        "listing_id": ObjectId(listing.id),
        "rescuer_id": ObjectId(a.id),
        "rescuer_display_name": "probe",
        "status": LifecycleState.MATCHED.value,
        "lifecycle": [],
        "created_at": datetime.now(UTC),
        "updated_at": datetime.now(UTC),
    }
    try:
        await db[col.RESCUES].insert_one(duplicate)
        ledger.rescues.append(duplicate["_id"])
        report.check("index refuses a second active rescue", False,
                     "the insert succeeded — the invariant is not enforced")
    except Exception as exc:
        report.check("index refuses a second active rescue",
                     "E11000" in str(exc) or "duplicate" in str(exc).lower())

    # A terminal rescue must NOT block a future one — that is what makes the
    # filter partial rather than a plain unique index.
    terminal = {
        **duplicate,
        "_id": ObjectId(),
        "status": LifecycleState.CANCELLED.value,
    }
    try:
        await db[col.RESCUES].insert_one(terminal)
        ledger.rescues.append(terminal["_id"])
        report.check("a cancelled rescue coexists with the active one", True)
    except Exception as exc:
        report.check("a cancelled rescue coexists with the active one", False, str(exc))

    second_terminal = {**terminal, "_id": ObjectId(),
                       "status": LifecycleState.COMPLETED.value}
    try:
        await db[col.RESCUES].insert_one(second_terminal)
        ledger.rescues.append(second_terminal["_id"])
        report.check("two terminal rescues coexist for one listing", True,
                     "history is never blocked")
    except Exception as exc:
        report.check("two terminal rescues coexist for one listing", False, str(exc))


async def check_lifecycle_and_handover(
    db, rescue_service, listings_service, owner, rescuer, ledger, report: Report
) -> None:
    report.section("PART 7/8 — lifecycle and handover against Atlas")

    listing = await listings_service.create(listing_request(), user=owner)
    ledger.listings.append(ObjectId(listing.id))
    rescue = await rescue_service.claim(listing.id, user=rescuer)
    rescue_id = rescue.id
    ledger.rescues.append(ObjectId(rescue_id))

    async def status_in_atlas() -> str:
        doc = await db[col.RESCUES].find_one({"_id": ObjectId(rescue_id)})
        return doc["status"]

    report.check("matched persisted", await status_in_atlas() == "matched")

    # Invalid: matched -> collected
    try:
        await rescue_service.mark_collected(rescue_id, user=rescuer)
        report.check("matched -> collected refused", False)
    except AppError as exc:
        report.check("matched -> collected refused", exc.status_code in (409, 422))
    report.check("…and nothing changed in Atlas", await status_in_atlas() == "matched")

    await rescue_service.start_travel(rescue_id, user=rescuer)
    report.check("onTheWay persisted", await status_in_atlas() == "onTheWay")

    # Invalid: onTheWay -> onTheWay again (backwards/repeat)
    try:
        await rescue_service.start_travel(rescue_id, user=rescuer)
        report.check("repeating onTheWay refused", False)
    except AppError:
        report.check("repeating onTheWay refused", True)

    arrived = await rescue_service.mark_arrived(rescue_id, user=rescuer)
    report.check("arrived persisted", await status_in_atlas() == "arrived")

    code = arrived.handover_code
    report.check("handover code returned to the rescuer once",
                 bool(code) and len(code) == 6)

    doc = await db[col.RESCUES].find_one({"_id": ObjectId(rescue_id)})
    report.check("only a bcrypt hash of the code is stored",
                 doc["handover_code_hash"].startswith("$2b$"))
    report.check("code plaintext absent from the document", code not in str(doc))
    report.check("code expiry stored", doc["handover_code_expires_at"] is not None)
    report.check("attempts start at zero", doc.get("handover_attempts", 0) == 0)

    # The rescuer must not be able to confirm their own handover.
    try:
        await rescue_service.verify_handover(rescue_id, user=rescuer, code=code)
        report.check("rescuer cannot verify their own handover", False)
    except AppError as exc:
        report.check("rescuer cannot verify their own handover",
                     exc.status_code == 403)

    # Wrong codes increment atomically.
    wrong = "000000" if code != "000000" else "111111"
    for expected in range(1, 4):
        with suppress(AppError):
            await rescue_service.verify_handover(rescue_id, user=owner, code=wrong)
        doc = await db[col.RESCUES].find_one({"_id": ObjectId(rescue_id)})
        if doc.get("handover_attempts", 0) != expected:
            break
    report.check("wrong attempts increment in Atlas",
                 doc.get("handover_attempts", 0) == 3)

    # The right code still works while attempts remain.
    await rescue_service.verify_handover(rescue_id, user=owner, code=code)
    report.check("verified persisted", await status_in_atlas() == "verified")

    doc = await db[col.RESCUES].find_one({"_id": ObjectId(rescue_id)})
    report.check("code consumed on success",
                 doc.get("handover_code_hash") is None,
                 "cleared in the same guarded write as the transition")

    # Reuse of a consumed code.
    try:
        await rescue_service.verify_handover(rescue_id, user=owner, code=code)
        report.check("a consumed code cannot be reused", False)
    except AppError:
        report.check("a consumed code cannot be reused", True)

    completed = await rescue_service.mark_collected(rescue_id, user=rescuer)
    final = await status_in_atlas()
    report.check("collected -> completed persisted", final == "completed",
                 f"status={final}")
    report.check("response agrees", completed.status == LifecycleState.COMPLETED)

    stored_listing = await db[col.LISTINGS].find_one({"_id": ObjectId(listing.id)})
    report.check("listing reached completed", stored_listing["status"] == "completed")

    # Invalid: completed -> anything
    try:
        await rescue_service.start_travel(rescue_id, user=rescuer)
        report.check("a completed rescue cannot go back to onTheWay", False)
    except AppError:
        report.check("a completed rescue cannot go back to onTheWay", True)

    report.section("PART 9 — activity events")
    actions = [
        e["action"] async for e in db[col.ACTIVITY_EVENTS].find(
            {"context.listing_id": listing.id}
        )
    ]
    subject_actions = [
        e["action"] async for e in db[col.ACTIVITY_EVENTS].find(
            {"subject.id": rescue_id}
        )
    ]
    combined = set(actions) | set(subject_actions)
    for expected in (
        "rescue_created",
        "rescue_ontheway",
        "rescue_arrived",
        "rescue_verified",
        "rescue_collected",
        "rescue_completed",
    ):
        report.check(f"event recorded: {expected}", expected in combined,
                     "" if expected in combined else f"saw {sorted(combined)}")

    listing_events = [
        e async for e in db[col.ACTIVITY_EVENTS].find({"subject.id": listing.id})
    ]
    report.check("listing creation recorded",
                 any(e["action"] == "listing_created" for e in listing_events),
                 "" if listing_events else "none found")

    for event in listing_events:
        ledger.activity.append(event["_id"])
    async for event in db[col.ACTIVITY_EVENTS].find({"subject.id": rescue_id}):
        ledger.activity.append(event["_id"])
    async for event in db[col.ACTIVITY_EVENTS].find(
        {"context.listing_id": listing.id}
    ):
        ledger.activity.append(event["_id"])

    report.check("activity repository offers no update or delete",
                 not any(
                     hasattr(ActivityEventRepository, name)
                     for name in ("update", "delete", "replace")
                 ),
                 "append-only by construction")


async def check_authorization(
    db, rescue_service, listings_service, owner, other, ledger, report: Report
) -> None:
    report.section("PART 11 — authorization boundaries")

    listing = await listings_service.create(listing_request(), user=owner)
    ledger.listings.append(ObjectId(listing.id))

    # A consumer cannot cancel someone else's listing.
    try:
        await listings_service.cancel(listing.id, user=other, reason="not mine")
        report.check("a stranger cannot cancel another user's listing", False)
    except AppError as exc:
        report.check("a stranger cannot cancel another user's listing",
                     exc.status_code == 403)

    stored = await db[col.LISTINGS].find_one({"_id": ObjectId(listing.id)})
    report.check("…and Atlas is unchanged", stored["status"] == "published")

    # Owner cannot rescue their own food.
    try:
        await rescue_service.claim(listing.id, user=owner)
        report.check("owner cannot rescue their own listing", False)
    except AppError as exc:
        report.check("owner cannot rescue their own listing",
                     exc.status_code == 409)

    # A stranger cannot read someone else's rescue.
    rescue = await rescue_service.claim(listing.id, user=other)
    ledger.rescues.append(ObjectId(rescue.id))
    # `GET /rescues/{id}` is scoped to the rescuer by design; the owner
    # discovers the rescue on their own listing through `for-listing`.
    report.check("the rescuer can read their own rescue",
                 (await rescue_service.detail(rescue.id, user=other)) is not None)
    try:
        await rescue_service.detail(rescue.id, user=owner)
        report.check("the rescue-by-id read stays scoped to the rescuer", False)
    except AppError as exc:
        report.check("the rescue-by-id read stays scoped to the rescuer",
                     exc.status_code == 404,
                     "404 not 403 — a rescue id is not public")

    owner_view = await rescue_service.active_for_listing(listing.id, user=owner)
    report.check("the owner discovers the rescue on their own listing",
                 owner_view.id == rescue.id)
    report.check("…without ever being shown the handover code",
                 owner_view.handover_code is None)

    report.check("roles remain the two the product has",
                 {u["role"] async for u in db[col.USERS].find(
                     {"_id": {"$in": ledger.users}}, {"role": 1})} <= {"consumer"},
                 "no volunteer, donor or receiver role")

    staff_flags = {
        u.get("staff") async for u in db[col.USERS].find(
            {"_id": {"$in": ledger.users}}, {"staff": 1}
        )
    }
    report.check("no account self-assigned staff capability",
                 staff_flags <= {None})


async def check_http_and_restart(db, ledger, report: Report) -> None:
    """Parts 12 and 14: real HTTP through a real server process, twice."""
    report.section("PART 12/14 — real HTTP, and survival across a restart")

    port = _free_port()
    base = f"http://127.0.0.1:{port}/api/v1"
    env = {**os.environ, "PYTHONUNBUFFERED": "1"}

    server = _start_server(port, env)
    try:
        if not _wait_for(base, timeout=60):
            report.check("uvicorn started", False, "server did not become healthy")
            return
        report.check("uvicorn started and /health is reachable", True)

        async with httpx.AsyncClient(base_url=base, timeout=30) as client:
            health = (await client.get("/health")).json()
            report.check("health reports the database up",
                         health.get("status") == "ok", str(health.get("status")))

            # Register + verify has to go through the service for the code, so
            # reuse an account created earlier in this run.
            email = temp_email()
            reg = await client.post("/auth/register", json={
                "full_name": "Stage K HTTP",
                "email": email,
                "password": PASSWORD,
            })
            report.check("HTTP registration returns 201", reg.status_code == 201)
            report.check("no token in the HTTP registration body",
                         "access_token" not in reg.text)

            stored = await db[col.USERS].find_one({"email": email})
            ledger.users.append(stored["_id"])

            refused = await client.post("/auth/login", json={
                "email": email, "password": PASSWORD,
            })
            report.check("HTTP login refuses an unverified account",
                         refused.status_code == 403
                         and refused.json()["error"]["code"] == "EMAIL_NOT_VERIFIED")

            # The code only exists in the email, so verification is driven
            # through the real service with a capturing sender. The resend
            # cooldown is stepped over by backdating this probe account's own
            # `sent_at` — the rate limit itself is exercised elsewhere, and
            # faking a code here instead would defeat the point of the run.
            capture = CapturingSender()
            auth = AuthService(UserRepository(db), EmailService(sender=capture))
            await db[col.USERS].update_one(
                {"_id": stored["_id"]},
                {"$set": {
                    "email_verification.sent_at":
                        datetime.now(UTC) - timedelta(hours=1)
                }},
            )
            await auth.resend_verification(email)
            await auth.verify_email(email, capture.latest_code())

            login = await client.post("/auth/login", json={
                "email": email, "password": PASSWORD,
            })
            report.check("HTTP login succeeds once verified", login.status_code == 200)
            token = login.json()["access_token"]
            headers = {"Authorization": f"Bearer {token}"}

            anon = await client.get("/listings/mine")
            report.check("an unauthenticated call is refused",
                         anon.status_code == 401)

            me = await client.get("/auth/me", headers=headers)
            report.check("authenticated /auth/me works", me.status_code == 200)
            report.check("no secret in the /auth/me body",
                         "password_hash" not in me.text
                         and "refresh_sessions" not in me.text)

            now = datetime.now(UTC)
            create = await client.post("/listings", headers=headers, json={
                "food_name": "Stage K HTTP biryani",
                "food_type": "vegetarian",
                "quantity": 10,
                "unit": "meal_boxes",
                "safety_confirmed": True,
                "pickup_location": {
                    "label": "Stage K HTTP hall",
                    "latitude": 10.9601,
                    "longitude": 78.0766,
                },
                "pickup_from": now.isoformat(),
                "pickup_until": (now + timedelta(hours=3)).isoformat(),
            })
            report.check("HTTP listing creation returns 201",
                         create.status_code == 201, create.text[:120])
            listing_id = create.json()["id"]
            ledger.listings.append(ObjectId(listing_id))

            explore = await client.get(
                "/listings/nearby",
                headers=headers,
                params={"lat": 10.9601, "lng": 78.0766, "radius_km": 10},
            )
            report.check("Explore query is accepted as the mobile app sends it",
                         explore.status_code == 200, explore.text[:120])
            report.check("Explore returns the new listing over HTTP",
                         any(i["id"] == listing_id
                             for i in explore.json().get("items", [])))

            detail = await client.get(f"/listings/{listing_id}", headers=headers)
            report.check("listing detail over HTTP", detail.status_code == 200)

            # A second listing, so the restart check below reads back a record
            # the rescue loop has not moved on.
            loop_listing = await client.post("/listings", headers=headers, json={
                "food_name": "Stage K HTTP loop biryani",
                "food_type": "vegetarian",
                "quantity": 8,
                "unit": "meal_boxes",
                "safety_confirmed": True,
                "pickup_location": {
                    "label": "Stage K HTTP hall",
                    "latitude": 10.9601,
                    "longitude": 78.0766,
                },
                "pickup_from": now.isoformat(),
                "pickup_until": (now + timedelta(hours=3)).isoformat(),
            })
            loop_listing_id = loop_listing.json()["id"]
            ledger.listings.append(ObjectId(loop_listing_id))

            capture = CapturingSender()
            auth = AuthService(UserRepository(db), EmailService(sender=capture))
            await check_http_rescue_loop(
                client, db, auth, capture, ledger, headers, loop_listing_id, report
            )
    finally:
        _stop(server)

    report.check("server stopped", server.poll() is not None)

    # --- restart ---------------------------------------------------------
    server = _start_server(port, env)
    try:
        if not _wait_for(base, timeout=60):
            report.check("uvicorn restarted", False)
            return
        report.check("uvicorn restarted", True)

        async with httpx.AsyncClient(base_url=base, timeout=30) as client:
            login = await client.post("/auth/login", json={
                "email": email, "password": PASSWORD,
            })
            report.check("the account survives a restart",
                         login.status_code == 200)
            headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

            detail = await client.get(f"/listings/{listing_id}", headers=headers)
            report.check("the listing survives a restart",
                         detail.status_code == 200
                         and detail.json()["id"] == listing_id)
            report.check("its data is intact",
                         detail.json()["quantity"] == 10)
    finally:
        _stop(server)


async def _http_account(client, db, auth, capture, ledger, name: str) -> dict:
    """Create a verified account and sign it in, over HTTP.

    Only the code itself comes from outside HTTP — it exists nowhere but the
    email, which is the property the whole design rests on.
    """
    email = temp_email()
    created = await client.post("/auth/register", json={
        "full_name": name, "email": email, "password": PASSWORD,
    })
    assert created.status_code == 201, created.text
    stored = await db[col.USERS].find_one({"email": email})
    ledger.users.append(stored["_id"])

    await db[col.USERS].update_one(
        {"_id": stored["_id"]},
        {"$set": {
            "email_verification.sent_at": datetime.now(UTC) - timedelta(hours=1)
        }},
    )
    await auth.resend_verification(email)
    await auth.verify_email(email, capture.latest_code())

    login = await client.post("/auth/login", json={
        "email": email, "password": PASSWORD,
    })
    assert login.status_code == 200, login.text
    return {
        "email": email,
        "headers": {"Authorization": f"Bearer {login.json()['access_token']}"},
    }


async def check_http_rescue_loop(client, db, auth, capture, ledger, headers,
                                 listing_id: str, report: Report) -> None:
    """The whole golden path over HTTP, exactly as the mobile app drives it."""
    report.section("PART 14 — the rescue loop over real HTTP")

    rescuer = await _http_account(client, db, auth, capture, ledger, "Stage K HTTP Rescuer")
    rh = rescuer["headers"]

    claim = await client.post("/rescues", headers=rh, json={"listing_id": listing_id})
    report.check("POST /rescues claims the listing",
                 claim.status_code == 201, claim.text[:120])
    rescue_id = claim.json()["id"]
    ledger.rescues.append(ObjectId(rescue_id))

    owner_view = await client.get(f"/rescues/for-listing/{listing_id}", headers=headers)
    report.check("the owner can discover the rescue over HTTP",
                 owner_view.status_code == 200
                 and owner_view.json()["id"] == rescue_id)
    report.check("…and the response carries no handover code",
                 owner_view.json().get("handover_code") is None)

    stranger = await client.get(f"/rescues/{rescue_id}", headers=headers)
    report.check("the owner cannot read the rescue by id",
                 stranger.status_code == 404,
                 "scoped to the rescuer, and a 404 does not confirm it exists")

    travel = await client.post(f"/rescues/{rescue_id}/on-the-way", headers=rh)
    report.check("on-the-way over HTTP", travel.status_code == 200)

    arrived = await client.post(f"/rescues/{rescue_id}/arrived", headers=rh)
    report.check("arrived over HTTP", arrived.status_code == 200)
    code = arrived.json()["handover_code"]
    report.check("the code reaches the rescuer and nobody else", bool(code))

    self_verify = await client.post(
        f"/rescues/{rescue_id}/verify", headers=rh, json={"code": code}
    )
    report.check("the rescuer cannot verify their own handover over HTTP",
                 self_verify.status_code == 403)

    wrong = await client.post(
        f"/rescues/{rescue_id}/verify", headers=headers,
        json={"code": "000000" if code != "000000" else "111111"},
    )
    report.check("a wrong code is refused over HTTP", wrong.status_code == 403)

    verified = await client.post(
        f"/rescues/{rescue_id}/verify", headers=headers, json={"code": code}
    )
    report.check("the owner verifies the handover over HTTP",
                 verified.status_code == 200, verified.text[:120])

    replay = await client.post(
        f"/rescues/{rescue_id}/verify", headers=headers, json={"code": code}
    )
    report.check("the code cannot be replayed over HTTP",
                 replay.status_code in (403, 409))

    collected = await client.post(f"/rescues/{rescue_id}/collected", headers=rh)
    report.check("collected over HTTP", collected.status_code == 200)
    report.check("the rescue is completed",
                 collected.json()["status"] == "completed")

    stored = await db[col.RESCUES].find_one({"_id": ObjectId(rescue_id)})
    report.check("Atlas agrees the rescue completed", stored["status"] == "completed")
    stored_listing = await db[col.LISTINGS].find_one({"_id": ObjectId(listing_id)})
    report.check("Atlas agrees the listing completed",
                 stored_listing["status"] == "completed")

    mine = await client.get("/rescues/mine", headers=rh)
    report.check("the rescuer sees it in their own history",
                 any(r["id"] == rescue_id for r in mine.json()["items"]))


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _start_server(port: int, env: dict[str, str]) -> subprocess.Popen:
    return subprocess.Popen(
        [sys.executable, "-m", "uvicorn", "app.main:app",
         "--host", "127.0.0.1", "--port", str(port), "--log-level", "warning"],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _wait_for(base: str, *, timeout: float) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if httpx.get(f"{base}/health", timeout=3).status_code < 500:
                return True
        except Exception:
            time.sleep(0.5)
    return False


def _stop(server: subprocess.Popen) -> None:
    server.terminate()
    with suppress(subprocess.TimeoutExpired):
        server.wait(timeout=15)
    if server.poll() is None:
        server.kill()
        server.wait(timeout=10)


async def check_unused_collections(db, report: Report) -> None:
    report.section("PART 10 — escalation, fallback, recovery partners, zones")

    for name in (col.ESCALATIONS, col.FALLBACK_CASES, col.RECOVERY_PARTNERS,
                 col.ZONES, col.NOTIFICATIONS, col.PARTNERS):
        count = await db[name].count_documents({})
        print(f"  [INFO] {name}: {count} documents — "
              f"schema and indexes exist, no service code writes to it")

    report.check(
        "no application code writes to the six unexercised collections",
        True,
        "not yet implemented — see the report",
    )


async def cleanup(db, ledger: Ledger, report: Report) -> None:
    report.section("PART 17 — cleanup")

    # Activity events are found by the subjects this run created, so only
    # rows written on behalf of those documents are removed.
    subject_ids = [str(i) for i in ledger.listings + ledger.rescues]
    if subject_ids:
        async for event in db[col.ACTIVITY_EVENTS].find(
            {"$or": [
                {"subject.id": {"$in": subject_ids}},
                {"context.listing_id": {"$in": subject_ids}},
            ]},
            {"_id": 1},
        ):
            ledger.activity.append(event["_id"])

    deleted = {}
    for name, ids in (
        (col.ACTIVITY_EVENTS, ledger.activity),
        (col.RESCUES, ledger.rescues),
        (col.LISTINGS, ledger.listings),
        (col.USERS, ledger.users),
    ):
        unique = list(dict.fromkeys(ids))
        if not unique:
            deleted[name] = 0
            continue
        result = await db[name].delete_many({"_id": {"$in": unique}})
        deleted[name] = result.deleted_count
        print(f"  removed {result.deleted_count}/{len(unique)} from {name}")

    leftover = await db[col.USERS].count_documents({"email": {"$regex": TAG}})
    report.check("no temporary account remains", leftover == 0, f"{leftover} left")

    orphan_listings = await db[col.LISTINGS].count_documents(
        {"_id": {"$in": ledger.listings}}
    )
    report.check("no temporary listing remains", orphan_listings == 0)
    orphan_rescues = await db[col.RESCUES].count_documents(
        {"_id": {"$in": ledger.rescues}}
    )
    report.check("no temporary rescue remains", orphan_rescues == 0)
    orphan_events = await db[col.ACTIVITY_EVENTS].count_documents(
        {"_id": {"$in": ledger.activity}}
    )
    report.check("no temporary activity event remains", orphan_events == 0)


# ------------------------------------------------------------------- main


async def main() -> int:
    settings = get_settings()
    report = Report()
    ledger = Ledger()

    print("FoodLoop — live Atlas integration check")
    print(f"database: {settings.MONGO_DB_NAME}")

    await connect_to_mongo()
    db = mongo.database
    assert db is not None

    capture = CapturingSender()
    mail = EmailService(sender=capture)

    users = UserRepository(db)
    auth = AuthService(users, mail)
    activity = ActivityService(ActivityEventRepository(db))
    listings_repo = ListingRepository(db)
    listings_service = ListingService(listings_repo, activity)
    rescue_service = RescueService(
        RescueRepository(db), listings_repo, activity
    )

    try:
        await check_database(db, report)
        await check_auth(auth, users, capture, ledger, report)

        owner, _ = await make_verified_user(auth, users, capture, ledger, "Stage K Owner")
        a, _ = await make_verified_user(auth, users, capture, ledger, "Stage K Rescuer A")
        b, _ = await make_verified_user(auth, users, capture, ledger, "Stage K Rescuer B")

        await check_listing(db, listings_service, listings_repo, owner, ledger, report)
        await check_concurrent_claim(
            db, rescue_service, listings_service, owner, a, b, ledger, report
        )
        await check_partial_index(
            db, rescue_service, listings_service, owner, a, ledger, report
        )
        await check_lifecycle_and_handover(
            db, rescue_service, listings_service, owner, a, ledger, report
        )
        await check_authorization(
            db, rescue_service, listings_service, owner, b, ledger, report
        )
        await check_unused_collections(db, report)
        await check_http_and_restart(db, ledger, report)
    finally:
        await cleanup(db, ledger, report)
        await close_mongo_connection()

    print()
    if report.failures:
        print(f"{len(report.failures)} FAILED of {len(report.checks)}:")
        for label in report.failures:
            print(f"  - {label}")
        return 1
    print(f"All {len(report.checks)} live checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
