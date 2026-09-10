"""Rescue tests — tap-to-claim.

The fakes reproduce the two database guarantees the design leans on:

* `FakeListingRepository.claim` matches the claimable filter and flips the
  status **in one step**, exactly as `find_one_and_update` does. A test can
  therefore lose a claim the same way a real caller would.
* `FakeRescueRepository.create` enforces the
  `uniq_active_rescue_per_listing` partial index, raising `DuplicateKeyError`
  for a second active rescue on one listing.

Without both, a concurrency test would only prove the fake is permissive.
"""

import asyncio
from datetime import UTC, datetime
from typing import Any

import pytest
from bson import ObjectId
from httpx import ASGITransport, AsyncClient
from pymongo.errors import DuplicateKeyError

from app.core.exceptions import ConflictError
from app.db.mongo import get_db
from app.features.activity.service import ActivityService
from app.features.auth.dependencies import get_current_user
from app.features.auth.schemas import AccountRole
from app.features.listings.repository import claimable_filter
from app.features.rescues.repository import RescueRepository, active_rescue_filter
from app.features.rescues.router import get_rescue_service
from app.features.rescues.service import RescueService
from app.main import create_app
from app.shared.lifecycle import (
    RESCUE_ACTIVE_STATES,
    RESCUE_TRANSITIONS,
    LifecycleState,
    can_transition,
    to_rescue_stage,
)
from tests.test_activity import FakeActivityRepository
from tests.test_listings import (
    CONSUMER_ID,
    KARUR,
    OTHER_ID,
    PARTNER_ID,
    FakeListingRepository,
    user,
)

RIVAL_ID = ObjectId()


class ClaimingListingRepository(FakeListingRepository):
    """Adds the atomic claim/release pair to the Stage D fake."""

    async def claim(self, listing_id, *, rescue_id):
        stored = self.documents.get(listing_id)
        if stored is None:
            return None

        criteria = claimable_filter()
        allowed = set(criteria["status"]["$in"])
        # Both conditions are evaluated together with the write, mirroring
        # find_one_and_update. There is no window between them.
        if stored["status"] not in allowed:
            return None
        if _aware(stored["expires_at"]) <= criteria["expires_at"]["$gt"]:
            return None

        before = dict(stored)
        stored["status"] = LifecycleState.MATCHED.value
        stored["active_rescue_id"] = rescue_id
        stored["updated_at"] = datetime.now(UTC)
        return before

    async def release(self, listing_id, *, rescue_id, restore_to):
        stored = self.documents.get(listing_id)
        if (
            stored is None
            or stored.get("active_rescue_id") != rescue_id
            or stored["status"] != LifecycleState.MATCHED.value
        ):
            return False
        stored["status"] = restore_to.value
        stored["active_rescue_id"] = None
        return True


class FakeRescueRepository(RescueRepository):
    """In-memory rescues, enforcing the partial unique index."""

    def __init__(self) -> None:
        self.documents: dict[ObjectId, dict[str, Any]] = {}
        self.fail_next_create = False

    async def create(self, document: dict[str, Any]) -> dict[str, Any]:
        if self.fail_next_create:
            self.fail_next_create = False
            raise DuplicateKeyError("E11000 uniq_active_rescue_per_listing")

        active = set(active_rescue_filter()["status"]["$in"])
        for existing in self.documents.values():
            if (
                existing["listing_id"] == document["listing_id"]
                and existing["status"] in active
            ):
                raise DuplicateKeyError("E11000 uniq_active_rescue_per_listing")

        self.documents[document["_id"]] = document
        return document

    async def delete(self, rescue_id: ObjectId) -> None:
        self.documents.pop(rescue_id, None)

    async def find_by_id(self, rescue_id: str) -> dict[str, Any] | None:
        try:
            return self.documents.get(ObjectId(rescue_id))
        except Exception:
            return None

    async def find_active_for_listing(self, listing_id):
        active = set(active_rescue_filter()["status"]["$in"])
        return next(
            (
                d
                for d in self.documents.values()
                if d["listing_id"] == listing_id and d["status"] in active
            ),
            None,
        )

    async def find_by_rescuer(self, *, rescuer_id, active_only, limit, offset):
        active = set(active_rescue_filter()["status"]["$in"])
        rows = [
            d
            for d in self.documents.values()
            if d["rescuer_id"] == rescuer_id
            and (not active_only or d["status"] in active)
        ]
        rows.sort(key=lambda d: d["created_at"], reverse=True)
        return rows[offset : offset + limit]

    async def set_handover_code(self, rescue_id, *, code_hash, expires_at):
        stored = self.documents[rescue_id]
        stored["handover_code_hash"] = code_hash
        stored["handover_code_expires_at"] = expires_at
        stored["handover_attempts"] = 0

    async def count_handover_attempt(self, rescue_id) -> int:
        stored = self.documents[rescue_id]
        stored["handover_attempts"] = int(stored.get("handover_attempts", 0)) + 1
        return stored["handover_attempts"]

    async def set_status(self, rescue_id, *, expected, status, extra=None):
        stored = self.documents.get(rescue_id)
        if stored is None or stored["status"] not in [s.value for s in expected]:
            return None
        stored.update(extra or {})
        stored["status"] = status.value
        stored["updated_at"] = datetime.now(UTC)
        stored.setdefault("lifecycle", []).append({"step": status.value})
        return stored

    # ----- helpers -----
    def active_for(self, listing_id: ObjectId) -> list[dict[str, Any]]:
        active = set(active_rescue_filter()["status"]["$in"])
        return [
            d
            for d in self.documents.values()
            if d["listing_id"] == listing_id and d["status"] in active
        ]


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


@pytest.fixture
def listings() -> ClaimingListingRepository:
    return ClaimingListingRepository()


@pytest.fixture
def rescues() -> FakeRescueRepository:
    return FakeRescueRepository()


@pytest.fixture
def events() -> FakeActivityRepository:
    return FakeActivityRepository()


@pytest.fixture
def current_user() -> dict[str, Any]:
    return {"user": user()}


@pytest.fixture
def service(rescues, listings, events) -> RescueService:
    return RescueService(rescues, listings, ActivityService(events))


@pytest.fixture
def app(service, current_user):
    application = create_app()
    application.dependency_overrides[get_db] = lambda: None
    application.dependency_overrides[get_rescue_service] = lambda: service
    application.dependency_overrides[get_current_user] = lambda: current_user["user"]
    return application


@pytest.fixture
async def api(app):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest.fixture
async def anon_api(service):
    application = create_app()
    application.dependency_overrides[get_db] = lambda: None
    application.dependency_overrides[get_rescue_service] = lambda: service
    transport = ASGITransport(app=application)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


# ---------------------------------------------------------------- basics


async def test_consumer_can_rescue_an_available_listing(api, listings, rescues):
    listing = listings.seed(owner_id=OTHER_ID)

    response = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == LifecycleState.MATCHED.value
    assert body["stage"] == "confirmed"
    assert body["is_active"] is True
    assert body["listing"]["title"] == "25 Meal Boxes"
    assert len(rescues.documents) == 1


async def test_claiming_marks_the_listing_matched_and_links_the_rescue(
    api, listings, rescues
):
    listing = listings.seed(owner_id=OTHER_ID)

    response = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    assert listing["status"] == LifecycleState.MATCHED.value
    assert str(listing["active_rescue_id"]) == response.json()["id"]


async def test_unauthenticated_claim_is_rejected(anon_api, listings, rescues):
    listing = listings.seed(owner_id=OTHER_ID)

    response = await anon_api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    assert response.status_code == 401
    assert rescues.documents == {}
    assert listing["status"] == LifecycleState.PUBLISHED.value


async def test_a_partner_cannot_rescue(api, listings, rescues, current_user):
    """A partner is a business publishing surplus, not collecting it."""
    current_user["user"] = user(
        PARTNER_ID, role=AccountRole.PARTNER, partner_id=str(PARTNER_ID)
    )
    listing = listings.seed(owner_id=OTHER_ID)

    response = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    assert response.status_code == 403
    assert rescues.documents == {}
    assert listing["status"] == LifecycleState.PUBLISHED.value


async def test_missing_listing_is_not_found(api, rescues):
    response = await api.post(
        "/api/v1/rescues", json={"listing_id": str(ObjectId())}
    )

    assert response.status_code == 404
    assert rescues.documents == {}


async def test_malformed_listing_id_is_rejected(api, rescues):
    response = await api.post("/api/v1/rescues", json={"listing_id": "not-an-id"})

    assert response.status_code == 422
    assert rescues.documents == {}


async def test_you_cannot_rescue_your_own_listing(api, listings, rescues):
    listing = listings.seed(owner_id=CONSUMER_ID)

    response = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    assert response.status_code == 409
    assert rescues.documents == {}


@pytest.mark.parametrize(
    "status",
    [
        LifecycleState.DRAFT,
        LifecycleState.MATCHED,
        LifecycleState.COLLECTED,
        LifecycleState.COMPLETED,
        LifecycleState.CANCELLED,
        LifecycleState.EXPIRED,
        LifecycleState.FALLBACK,
    ],
)
async def test_unavailable_listings_cannot_be_claimed(api, listings, rescues, status):
    listing = listings.seed(owner_id=OTHER_ID, status=status)

    response = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    assert response.status_code == 409
    assert rescues.documents == {}


async def test_an_expired_window_cannot_be_claimed(api, listings, rescues):
    listing = listings.seed(owner_id=OTHER_ID, minutes_until_close=-5)

    response = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    assert response.status_code == 409
    assert rescues.documents == {}


async def test_a_withdrawn_listing_says_so(api, listings):
    listing = listings.seed(owner_id=OTHER_ID, status=LifecycleState.CANCELLED)

    response = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    assert response.status_code == 409
    assert "withdrawn" in response.json()["error"]["message"].lower()


# --------------------------------------------------------------- security


@pytest.mark.parametrize(
    "field", ["rescuer_id", "status", "created_at", "reference", "is_active"]
)
async def test_privileged_fields_cannot_be_supplied(api, listings, rescues, field):
    listing = listings.seed(owner_id=OTHER_ID)

    response = await api.post(
        "/api/v1/rescues",
        json={"listing_id": str(listing["_id"]), field: "forged"},
    )

    assert response.status_code == 422
    assert rescues.documents == {}
    assert listing["status"] == LifecycleState.PUBLISHED.value


async def test_identity_comes_from_the_session(api, listings, rescues):
    listing = listings.seed(owner_id=OTHER_ID)

    await api.post("/api/v1/rescues", json={"listing_id": str(listing["_id"])})

    [stored] = rescues.documents.values()
    assert stored["rescuer_id"] == CONSUMER_ID


async def test_timestamps_are_server_generated(api, listings, rescues):
    before = datetime.now(UTC)
    listing = listings.seed(owner_id=OTHER_ID)

    await api.post("/api/v1/rescues", json={"listing_id": str(listing["_id"])})

    [stored] = rescues.documents.values()
    assert _aware(stored["created_at"]) >= before


async def test_another_users_rescue_is_not_readable(
    api, listings, rescues, current_user
):
    listing = listings.seed(owner_id=OTHER_ID)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )
    rescue_id = created.json()["id"]

    current_user["user"] = user(RIVAL_ID)
    response = await api.get(f"/api/v1/rescues/{rescue_id}")

    # 404 rather than 403: a rescue id is not public, so confirming it exists
    # would leak something the caller had no way to know.
    assert response.status_code == 404


async def test_another_users_rescue_cannot_be_cancelled(
    api, listings, rescues, current_user
):
    listing = listings.seed(owner_id=OTHER_ID)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )
    rescue_id = created.json()["id"]

    current_user["user"] = user(RIVAL_ID)
    response = await api.post(f"/api/v1/rescues/{rescue_id}/cancel", json={})

    assert response.status_code == 404
    assert rescues.documents[ObjectId(rescue_id)]["status"] == (
        LifecycleState.MATCHED.value
    )


async def test_the_response_exposes_no_account_fields(api, listings):
    listing = listings.seed(owner_id=OTHER_ID)

    response = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    for leak in ("rescuer_id", "owner_user_id", "password", "refresh_sessions"):
        assert leak not in response.text
    assert str(OTHER_ID) not in response.text
    assert response.json()["listing"]["shared_by"] == "Asha Rao"


async def test_mine_returns_only_the_callers_rescues(
    api, listings, rescues, current_user
):
    first = listings.seed(owner_id=OTHER_ID)
    await api.post("/api/v1/rescues", json={"listing_id": str(first["_id"])})

    current_user["user"] = user(RIVAL_ID)
    second = listings.seed(owner_id=OTHER_ID)
    await api.post("/api/v1/rescues", json={"listing_id": str(second["_id"])})

    response = await api.get("/api/v1/rescues/mine")

    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["listing"]["id"] == str(second["_id"])


# ------------------------------------------------------------ concurrency


async def test_two_consumers_racing_produce_exactly_one_rescue(
    service, listings, rescues, events
):
    """The mandatory race. Both callers claim the same listing at once."""
    listing = listings.seed(owner_id=OTHER_ID)

    results = await asyncio.gather(
        service.claim(str(listing["_id"]), user=user(CONSUMER_ID)),
        service.claim(str(listing["_id"]), user=user(RIVAL_ID)),
        return_exceptions=True,
    )

    succeeded = [r for r in results if not isinstance(r, Exception)]
    failed = [r for r in results if isinstance(r, Exception)]

    assert len(succeeded) == 1, "exactly one claim must win"
    assert len(failed) == 1, "the loser must be refused"
    assert isinstance(failed[0], Exception)
    assert failed[0].status_code == 409

    # Exactly one rescue exists, and it holds the listing.
    assert len(rescues.documents) == 1
    assert len(rescues.active_for(listing["_id"])) == 1
    assert listing["status"] == LifecycleState.MATCHED.value
    assert str(listing["active_rescue_id"]) == succeeded[0].id

    # And the audit trail records one success, not two.
    assert [e.action for e in events.events] == ["rescue_created"]


async def test_a_claimed_listing_is_no_longer_claimable(
    service, listings, rescues
):
    listing = listings.seed(owner_id=OTHER_ID)
    await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))

    with pytest.raises(Exception) as caught:
        await service.claim(str(listing["_id"]), user=user(RIVAL_ID))

    assert caught.value.status_code == 409
    assert len(rescues.documents) == 1


async def test_many_concurrent_claims_still_yield_one_winner(
    service, listings, rescues
):
    listing = listings.seed(owner_id=OTHER_ID)
    rivals = [user(ObjectId()) for _ in range(10)]

    results = await asyncio.gather(
        *(service.claim(str(listing["_id"]), user=u) for u in rivals),
        return_exceptions=True,
    )

    succeeded = [r for r in results if not isinstance(r, Exception)]
    assert len(succeeded) == 1
    assert len(rescues.active_for(listing["_id"])) == 1


async def test_the_repository_claim_is_the_single_point_of_exclusion(listings):
    """The claim itself, without the service around it."""
    listing = listings.seed(owner_id=OTHER_ID)
    first_id, second_id = ObjectId(), ObjectId()

    first = await listings.claim(listing["_id"], rescue_id=first_id)
    second = await listings.claim(listing["_id"], rescue_id=second_id)

    assert first is not None, "the first claim wins"
    assert second is None, "the second matches nothing"
    # The returned document is the pre-claim one, which is what makes the
    # compensating release possible.
    assert first["status"] == LifecycleState.PUBLISHED.value
    assert listing["active_rescue_id"] == first_id


# ------------------------------------------------------------- consistency


async def test_a_failed_rescue_insert_releases_the_listing(
    service, listings, rescues, events
):
    """No rescue, and the listing must not be left stuck as `matched`."""
    listing = listings.seed(owner_id=OTHER_ID)
    rescues.fail_next_create = True

    with pytest.raises(Exception) as caught:
        await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))

    assert caught.value.status_code == 409
    assert rescues.documents == {}
    # Compensated back to exactly the status it held.
    assert listing["status"] == LifecycleState.PUBLISHED.value
    assert listing["active_rescue_id"] is None
    assert events.events == []


async def test_no_activity_event_is_written_for_a_failed_claim(
    service, listings, events
):
    listing = listings.seed(owner_id=OTHER_ID, status=LifecycleState.MATCHED)

    with pytest.raises(ConflictError):
        await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))

    assert events.events == []


async def test_a_successful_claim_writes_exactly_one_event(
    service, listings, events
):
    listing = listings.seed(owner_id=OTHER_ID)

    rescue = await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))

    [event] = events.events
    assert event.action == "rescue_created"
    assert event.subject.type == "rescue"
    assert event.subject.id == rescue.id
    assert event.context["listing_id"] == str(listing["_id"])


async def test_release_cannot_clobber_a_later_claim(listings):
    """The guard on `active_rescue_id` is what makes compensation safe."""
    listing = listings.seed(owner_id=OTHER_ID)
    stale_id = ObjectId()

    winner_id = ObjectId()
    await listings.claim(listing["_id"], rescue_id=winner_id)

    released = await listings.release(
        listing["_id"], rescue_id=stale_id, restore_to=LifecycleState.PUBLISHED
    )

    assert released is False
    assert listing["status"] == LifecycleState.MATCHED.value
    assert listing["active_rescue_id"] == winner_id


# --------------------------------------------------------------- lifecycle


async def test_starting_travel_follows_the_canonical_transition(api, listings):
    listing = listings.seed(owner_id=OTHER_ID)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )
    rescue_id = created.json()["id"]

    response = await api.post(f"/api/v1/rescues/{rescue_id}/on-the-way")

    assert response.status_code == 200
    assert response.json()["status"] == LifecycleState.ON_THE_WAY.value
    assert response.json()["stage"] == "ready"
    # The move this endpoint makes is legal in the canonical table.
    assert can_transition(
        LifecycleState.MATCHED,
        LifecycleState.ON_THE_WAY,
        transitions=RESCUE_TRANSITIONS,
    )


async def test_travel_cannot_start_twice(api, listings):
    listing = listings.seed(owner_id=OTHER_ID)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )
    rescue_id = created.json()["id"]
    await api.post(f"/api/v1/rescues/{rescue_id}/on-the-way")

    response = await api.post(f"/api/v1/rescues/{rescue_id}/on-the-way")

    assert response.status_code == 409
    assert not can_transition(
        LifecycleState.ON_THE_WAY,
        LifecycleState.ON_THE_WAY,
        transitions=RESCUE_TRANSITIONS,
    )


@pytest.mark.parametrize(
    "from_state", [LifecycleState.MATCHED, LifecycleState.ON_THE_WAY]
)
async def test_cancelling_returns_the_listing_to_the_pool(
    api, listings, rescues, from_state
):
    listing = listings.seed(owner_id=OTHER_ID)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )
    rescue_id = created.json()["id"]
    if from_state is LifecycleState.ON_THE_WAY:
        await api.post(f"/api/v1/rescues/{rescue_id}/on-the-way")

    response = await api.post(
        f"/api/v1/rescues/{rescue_id}/cancel", json={"reason": "Cannot make it."}
    )

    assert response.status_code == 200
    assert response.json()["status"] == LifecycleState.CANCELLED.value
    assert response.json()["is_active"] is False
    # Back in the pool, actively looking.
    assert listing["status"] == LifecycleState.SEARCHING.value
    assert listing["active_rescue_id"] is None


async def test_a_cancelled_rescue_frees_the_listing_for_someone_else(
    service, listings, rescues
):
    """Why the unique index is partial rather than plain."""
    listing = listings.seed(owner_id=OTHER_ID)
    first = await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))
    await service.cancel(first.id, user=user(CONSUMER_ID), reason=None)

    second = await service.claim(str(listing["_id"]), user=user(RIVAL_ID))

    assert second.status is LifecycleState.MATCHED
    assert len(rescues.documents) == 2
    assert len(rescues.active_for(listing["_id"])) == 1


async def test_a_cancelled_rescue_cannot_be_cancelled_again(api, listings):
    listing = listings.seed(owner_id=OTHER_ID)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )
    rescue_id = created.json()["id"]
    await api.post(f"/api/v1/rescues/{rescue_id}/cancel", json={})

    response = await api.post(f"/api/v1/rescues/{rescue_id}/cancel", json={})

    assert response.status_code == 409


async def test_every_implemented_transition_is_canonical():
    """The endpoints may only make moves `lifecycle.py` already permits."""
    implemented = [
        (LifecycleState.MATCHED, LifecycleState.ON_THE_WAY),
        (LifecycleState.MATCHED, LifecycleState.CANCELLED),
        (LifecycleState.ON_THE_WAY, LifecycleState.CANCELLED),
    ]
    for source, target in implemented:
        assert can_transition(source, target, transitions=RESCUE_TRANSITIONS), (
            f"{source} -> {target}"
        )


async def test_stage_is_a_projection_of_the_canonical_status():
    for state in (LifecycleState.MATCHED, LifecycleState.ON_THE_WAY):
        assert to_rescue_stage(state) is not None
    # Terminal states leave the stepper entirely.
    assert to_rescue_stage(LifecycleState.CANCELLED) is None


async def test_active_rescue_states_match_the_partial_index_filter():
    assert set(active_rescue_filter()["status"]["$in"]) == {
        s.value for s in RESCUE_ACTIVE_STATES
    }


# ------------------------------------------------------------------ reads


async def test_rescue_detail(api, listings):
    listing = listings.seed(owner_id=OTHER_ID, coordinates=KARUR)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )

    response = await api.get(f"/api/v1/rescues/{created.json()['id']}")

    assert response.status_code == 200
    body = response.json()
    assert body["listing"]["pickup_location"]["label"] == "Community Hall"
    assert body["listing"]["pickup_location"]["latitude"] == KARUR[0]
    assert body["listing"]["tags"] == ["Plant-Based"]


@pytest.mark.parametrize("rescue_id", ["nonsense", str(ObjectId())])
async def test_unknown_rescue_is_not_found(api, rescue_id):
    assert (await api.get(f"/api/v1/rescues/{rescue_id}")).status_code == 404


async def test_mine_can_filter_to_active_rescues(api, listings):
    first = listings.seed(owner_id=OTHER_ID)
    second = listings.seed(owner_id=OTHER_ID)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(first["_id"])}
    )
    await api.post("/api/v1/rescues", json={"listing_id": str(second["_id"])})
    await api.post(f"/api/v1/rescues/{created.json()['id']}/cancel", json={})

    everything = await api.get("/api/v1/rescues/mine")
    active = await api.get("/api/v1/rescues/mine", params={"active": True})

    assert len(everything.json()["items"]) == 2
    assert len(active.json()["items"]) == 1


async def test_mine_requires_authentication(anon_api):
    assert (await anon_api.get("/api/v1/rescues/mine")).status_code == 401


async def test_only_the_rescuer_can_start_travelling(api, listings, current_user):
    """Someone else's rescue is not theirs to advance."""
    listing = listings.seed(owner_id=OTHER_ID)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )
    rescue_id = created.json()["id"]

    current_user["user"] = user(RIVAL_ID)
    response = await api.post(f"/api/v1/rescues/{rescue_id}/on-the-way")

    assert response.status_code == 404


async def test_starting_travel_requires_authentication(anon_api, listings):
    response = await anon_api.post(f"/api/v1/rescues/{ObjectId()}/on-the-way")
    assert response.status_code == 401


async def test_starting_travel_emits_one_activity_event(api, listings, events):
    listing = listings.seed(owner_id=OTHER_ID)
    created = await api.post(
        "/api/v1/rescues", json={"listing_id": str(listing["_id"])}
    )
    events.events.clear()

    await api.post(f"/api/v1/rescues/{created.json()['id']}/on-the-way")

    assert [e.action for e in events.events] == ["rescue_ontheway"]
