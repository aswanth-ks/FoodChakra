"""Handover verification and rescue completion.

Reuses the Stage E fakes. The handover code is generated and hashed by the real
`app.core.security` functions, so these tests exercise the actual crypto path
rather than a stub — the code a test submits is the one a rescuer would read
out.
"""

import asyncio
from datetime import UTC, datetime, timedelta

import pytest
from bson import ObjectId
from httpx import ASGITransport, AsyncClient

from app.core.exceptions import ConflictError, ForbiddenError
from app.db.mongo import get_db
from app.features.activity.service import ActivityService
from app.features.auth.dependencies import get_current_user
from app.features.auth.schemas import AccountRole
from app.features.rescues.router import get_rescue_service
from app.features.rescues.service import (
    MAX_HANDOVER_ATTEMPTS,
    RescueService,
)
from app.main import create_app
from app.shared.lifecycle import (
    RESCUE_TRANSITIONS,
    LifecycleState,
    can_transition,
)
from tests.test_activity import FakeActivityRepository
from tests.test_listings import CONSUMER_ID, OTHER_ID, PARTNER_ID, user
from tests.test_rescues import ClaimingListingRepository, FakeRescueRepository

#: The consumer who published the listing being rescued.
OWNER_ID = OTHER_ID
STRANGER_ID = ObjectId()
OTHER_PARTNER_ID = ObjectId()


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
def service(rescues, listings, events) -> RescueService:
    return RescueService(rescues, listings, ActivityService(events))


@pytest.fixture
def current_user():
    return {"user": user()}


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


async def arrive(service, listings, *, partner_listing: bool = False):
    """Drive a rescue to `arrived` and return (rescue_id, plaintext code)."""
    listing = listings.seed(owner_id=OWNER_ID)
    if partner_listing:
        listing["source_kind"] = "partner"
        listing["partner_id"] = PARTNER_ID

    rescue = await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))
    await service.start_travel(rescue.id, user=user(CONSUMER_ID))
    arrived = await service.mark_arrived(rescue.id, user=user(CONSUMER_ID))
    return rescue.id, arrived.handover_code, listing


def owner_user(user_id=OWNER_ID, **kwargs):
    return user(user_id, **kwargs)


# --------------------------------------------------------------- arrived


async def test_arriving_follows_the_canonical_transition(service, listings):
    rescue_id, code, _ = await arrive(service, listings)

    assert code is not None
    assert can_transition(
        LifecycleState.ON_THE_WAY,
        LifecycleState.ARRIVED,
        transitions=RESCUE_TRANSITIONS,
    )
    fetched = await service.detail(rescue_id, user=user(CONSUMER_ID))
    assert fetched.status is LifecycleState.ARRIVED


async def test_arriving_issues_a_six_digit_code_to_the_rescuer(service, listings):
    _, code, _ = await arrive(service, listings)

    assert len(code) == 6
    assert code.isdigit()


async def test_only_the_rescuer_can_mark_arrived(service, listings):
    listing = listings.seed(owner_id=OWNER_ID)
    rescue = await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))
    await service.start_travel(rescue.id, user=user(CONSUMER_ID))

    with pytest.raises(Exception) as caught:
        await service.mark_arrived(rescue.id, user=owner_user())

    # Another account's rescue is not visible at all.
    assert caught.value.status_code == 404


async def test_cannot_arrive_before_setting_off(service, listings):
    listing = listings.seed(owner_id=OWNER_ID)
    rescue = await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))

    with pytest.raises(ConflictError):
        await service.mark_arrived(rescue.id, user=user(CONSUMER_ID))


# ---------------------------------------------------------- verification


async def test_the_owner_can_verify_with_the_rescuers_code(service, listings):
    rescue_id, code, _ = await arrive(service, listings)

    verified = await service.verify_handover(
        rescue_id, user=owner_user(), code=code
    )

    assert verified.status is LifecycleState.VERIFIED
    assert can_transition(
        LifecycleState.ARRIVED,
        LifecycleState.VERIFIED,
        transitions=RESCUE_TRANSITIONS,
    )


async def test_a_rescuer_cannot_verify_their_own_handover(service, listings):
    """The entire reason the step exists."""
    rescue_id, code, _ = await arrive(service, listings)

    with pytest.raises(ForbiddenError) as caught:
        await service.verify_handover(rescue_id, user=user(CONSUMER_ID), code=code)

    assert "own handover" in str(caught.value)


async def test_an_unrelated_consumer_cannot_verify(service, listings):
    rescue_id, code, _ = await arrive(service, listings)

    with pytest.raises(ForbiddenError):
        await service.verify_handover(
            rescue_id, user=user(STRANGER_ID), code=code
        )


async def test_an_unrelated_partner_cannot_verify(service, listings):
    rescue_id, code, _ = await arrive(service, listings, partner_listing=True)

    with pytest.raises(ForbiddenError):
        await service.verify_handover(
            rescue_id,
            user=user(
                STRANGER_ID,
                role=AccountRole.PARTNER,
                partner_id=str(OTHER_PARTNER_ID),
            ),
            code=code,
        )


async def test_a_colleague_at_the_owning_business_can_verify(service, listings):
    """A restaurant's surplus is rarely handed over by whoever posted it."""
    rescue_id, code, _ = await arrive(service, listings, partner_listing=True)

    verified = await service.verify_handover(
        rescue_id,
        user=user(
            STRANGER_ID, role=AccountRole.PARTNER, partner_id=str(PARTNER_ID)
        ),
        code=code,
    )

    assert verified.status is LifecycleState.VERIFIED


async def test_partner_id_comes_from_the_user_record_not_the_request(api, service, listings):
    """A forged partner_id in the body cannot buy verification authority."""
    rescue_id, code, _ = await arrive(service, listings, partner_listing=True)

    response = await api.post(
        f"/api/v1/rescues/{rescue_id}/verify",
        json={"code": code, "partner_id": str(PARTNER_ID)},
    )

    assert response.status_code == 422


async def test_an_incorrect_code_is_refused(service, listings):
    rescue_id, code, _ = await arrive(service, listings)
    wrong = "000000" if code != "000000" else "111111"

    with pytest.raises(ForbiddenError):
        await service.verify_handover(rescue_id, user=owner_user(), code=wrong)

    fetched = await service.detail(rescue_id, user=user(CONSUMER_ID))
    assert fetched.status is LifecycleState.ARRIVED


async def test_an_expired_code_is_refused(service, listings, rescues):
    rescue_id, code, _ = await arrive(service, listings)
    stored = rescues.documents[ObjectId(rescue_id)]
    stored["handover_code_expires_at"] = datetime.now(UTC) - timedelta(minutes=1)

    with pytest.raises(ConflictError) as caught:
        await service.verify_handover(rescue_id, user=owner_user(), code=code)

    assert "expired" in str(caught.value).lower()


async def test_a_code_cannot_be_used_twice(service, listings):
    rescue_id, code, _ = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)

    with pytest.raises(ConflictError):
        await service.verify_handover(rescue_id, user=owner_user(), code=code)


async def test_the_stored_hash_is_cleared_on_success(service, listings, rescues):
    rescue_id, code, _ = await arrive(service, listings)

    await service.verify_handover(rescue_id, user=owner_user(), code=code)

    stored = rescues.documents[ObjectId(rescue_id)]
    assert stored["handover_code_hash"] is None
    assert stored["handover_code_expires_at"] is None


async def test_repeated_wrong_guesses_lock_the_code(service, listings):
    rescue_id, code, _ = await arrive(service, listings)
    wrong = "000000" if code != "000000" else "111111"

    for _ in range(MAX_HANDOVER_ATTEMPTS):
        with pytest.raises(ForbiddenError):
            await service.verify_handover(rescue_id, user=owner_user(), code=wrong)

    # Even the correct code is now refused — six digits is guessable without
    # a cap.
    with pytest.raises(ConflictError) as caught:
        await service.verify_handover(rescue_id, user=owner_user(), code=code)
    assert "too many" in str(caught.value).lower()


async def test_two_simultaneous_verifications_yield_one_success(
    service, listings, events
):
    """Replay protection under concurrency, not just in sequence."""
    rescue_id, code, _ = await arrive(service, listings)

    results = await asyncio.gather(
        service.verify_handover(rescue_id, user=owner_user(), code=code),
        service.verify_handover(rescue_id, user=owner_user(), code=code),
        return_exceptions=True,
    )

    succeeded = [r for r in results if not isinstance(r, Exception)]
    failed = [r for r in results if isinstance(r, Exception)]

    assert len(succeeded) == 1
    assert len(failed) == 1
    assert failed[0].status_code == 409
    # And exactly one audit entry, not two.
    assert [e.action for e in events.events].count("rescue_verified") == 1


async def test_the_code_is_never_returned_to_the_verifier(api, service, listings):
    rescue_id, code, _ = await arrive(service, listings)

    verified = await service.verify_handover(
        rescue_id, user=owner_user(), code=code
    )

    assert verified.handover_code is None


async def test_the_code_is_not_returned_on_subsequent_reads(service, listings):
    """It is shown once, in the `arrived` response, and never again."""
    rescue_id, code, _ = await arrive(service, listings)

    fetched = await service.detail(rescue_id, user=user(CONSUMER_ID))

    assert fetched.handover_code is None


async def test_the_stored_hash_never_reaches_a_response(api, service, listings):
    rescue_id, code, _ = await arrive(service, listings)

    response = await api.get(f"/api/v1/rescues/{rescue_id}")

    assert response.status_code == 200
    assert "handover_code_hash" not in response.text
    assert "password" not in response.text
    assert "refresh_sessions" not in response.text


async def test_verification_requires_authentication(anon_api, service, listings):
    rescue_id, code, _ = await arrive(service, listings)

    response = await anon_api.post(
        f"/api/v1/rescues/{rescue_id}/verify", json={"code": code}
    )

    assert response.status_code == 401


@pytest.mark.parametrize("code", ["12345", "1234567", "abcdef", "", "12 456"])
async def test_malformed_codes_are_rejected(api, service, listings, code):
    rescue_id, _, _ = await arrive(service, listings)

    response = await api.post(
        f"/api/v1/rescues/{rescue_id}/verify", json={"code": code}
    )

    assert response.status_code == 422


async def test_cannot_verify_a_rescue_that_has_not_arrived(service, listings):
    listing = listings.seed(owner_id=OWNER_ID)
    rescue = await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))

    with pytest.raises(ConflictError):
        await service.verify_handover(
            rescue.id, user=owner_user(), code="123456"
        )


# ------------------------------------------------------ collected/completed


async def test_collection_completes_the_rescue_and_the_listing(
    service, listings, rescues
):
    rescue_id, code, listing = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)

    completed = await service.mark_collected(rescue_id, user=user(CONSUMER_ID))

    assert completed.status is LifecycleState.COMPLETED
    assert completed.is_active is False
    assert listing["status"] == LifecycleState.COMPLETED.value


async def test_collection_cannot_bypass_verification(service, listings):
    """The guard this whole stage exists to preserve."""
    rescue_id, _, _ = await arrive(service, listings)

    with pytest.raises(ConflictError):
        await service.mark_collected(rescue_id, user=user(CONSUMER_ID))

    assert not can_transition(
        LifecycleState.ARRIVED,
        LifecycleState.COLLECTED,
        transitions=RESCUE_TRANSITIONS,
    )


async def test_only_the_rescuer_can_confirm_collection(service, listings):
    rescue_id, code, _ = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)

    with pytest.raises(Exception) as caught:
        await service.mark_collected(rescue_id, user=owner_user())

    assert caught.value.status_code == 404


async def test_a_completed_rescue_cannot_be_collected_again(service, listings):
    rescue_id, code, _ = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)
    await service.mark_collected(rescue_id, user=user(CONSUMER_ID))

    with pytest.raises(ConflictError):
        await service.mark_collected(rescue_id, user=user(CONSUMER_ID))


async def test_a_completed_rescue_cannot_be_cancelled(service, listings):
    rescue_id, code, _ = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)
    await service.mark_collected(rescue_id, user=user(CONSUMER_ID))

    with pytest.raises(ConflictError):
        await service.cancel(rescue_id, user=user(CONSUMER_ID), reason=None)


async def test_a_cancelled_rescue_cannot_progress(service, listings):
    listing = listings.seed(owner_id=OWNER_ID)
    rescue = await service.claim(str(listing["_id"]), user=user(CONSUMER_ID))
    await service.cancel(rescue.id, user=user(CONSUMER_ID), reason=None)

    with pytest.raises(ConflictError):
        await service.start_travel(rescue.id, user=user(CONSUMER_ID))


async def test_two_simultaneous_collections_yield_one_completion(
    service, listings, events
):
    rescue_id, code, _ = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)

    results = await asyncio.gather(
        service.mark_collected(rescue_id, user=user(CONSUMER_ID)),
        service.mark_collected(rescue_id, user=user(CONSUMER_ID)),
        return_exceptions=True,
    )

    assert len([r for r in results if not isinstance(r, Exception)]) == 1
    assert [e.action for e in events.events].count("rescue_completed") == 1


# ------------------------------------------------------------ activity


async def test_each_successful_transition_emits_exactly_one_event(
    service, listings, events
):
    rescue_id, code, _ = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)
    await service.mark_collected(rescue_id, user=user(CONSUMER_ID))

    assert [e.action for e in events.events] == [
        "rescue_created",
        "rescue_ontheway",
        "rescue_arrived",
        "rescue_verified",
        "rescue_collected",
        "rescue_completed",
    ]


async def test_a_failed_verification_emits_no_lifecycle_event(
    service, listings, events
):
    rescue_id, code, _ = await arrive(service, listings)
    events.events.clear()
    wrong = "000000" if code != "000000" else "111111"

    with pytest.raises(ForbiddenError):
        await service.verify_handover(rescue_id, user=owner_user(), code=wrong)

    assert events.events == []


async def test_the_verification_event_records_the_owner_not_the_rescuer(
    service, listings, events
):
    """Accountability: the audit must say who confirmed the handover."""
    rescue_id, code, _ = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)

    verified = next(e for e in events.events if e.action == "rescue_verified")
    assert verified.actor.id == str(OWNER_ID)


# --------------------------------------------------------------- security


@pytest.mark.parametrize("field", ["status", "verified_by", "verified_at", "code_hash"])
async def test_privileged_fields_are_rejected_on_verify(
    api, service, listings, field
):
    rescue_id, code, _ = await arrive(service, listings)

    response = await api.post(
        f"/api/v1/rescues/{rescue_id}/verify",
        json={"code": code, field: "forged"},
    )

    assert response.status_code == 422


async def test_timestamps_are_server_generated(service, listings, rescues):
    before = datetime.now(UTC)
    rescue_id, code, _ = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)

    stored = rescues.documents[ObjectId(rescue_id)]
    recorded = stored["verified_at"]
    assert (recorded if recorded.tzinfo else recorded.replace(tzinfo=UTC)) >= before


async def test_the_verifier_is_recorded_from_the_session(
    service, listings, rescues
):
    rescue_id, code, _ = await arrive(service, listings)
    await service.verify_handover(rescue_id, user=owner_user(), code=code)

    assert rescues.documents[ObjectId(rescue_id)]["verified_by"] == OWNER_ID


async def test_every_implemented_transition_is_canonical():
    """The endpoints may only make moves `lifecycle.py` already permits."""
    for source, target in [
        (LifecycleState.ON_THE_WAY, LifecycleState.ARRIVED),
        (LifecycleState.ARRIVED, LifecycleState.VERIFIED),
        (LifecycleState.VERIFIED, LifecycleState.COLLECTED),
        (LifecycleState.COLLECTED, LifecycleState.COMPLETED),
    ]:
        assert can_transition(source, target, transitions=RESCUE_TRANSITIONS), (
            f"{source} -> {target}"
        )


# ------------------------------------------------- owner discovery (Stage G)


async def test_the_owner_can_find_the_rescue_on_their_listing(service, listings):
    """Without this the owner cannot reach the handover at all."""
    rescue_id, _, listing = await arrive(service, listings)

    found = await service.active_for_listing(
        str(listing["_id"]), user=owner_user()
    )

    assert found.id == rescue_id
    assert found.status is LifecycleState.ARRIVED


async def test_that_lookup_never_leaks_the_handover_code(service, listings):
    """An owner who could read the code would make the step meaningless."""
    _, _, listing = await arrive(service, listings)

    found = await service.active_for_listing(
        str(listing["_id"]), user=owner_user()
    )

    assert found.handover_code is None


async def test_a_partner_colleague_can_find_the_rescue(service, listings):
    _, _, listing = await arrive(service, listings, partner_listing=True)

    found = await service.active_for_listing(
        str(listing["_id"]),
        user=user(
            STRANGER_ID, role=AccountRole.PARTNER, partner_id=str(PARTNER_ID)
        ),
    )

    assert found.status is LifecycleState.ARRIVED


async def test_a_stranger_cannot_find_the_rescue_on_someone_elses_listing(
    service, listings
):
    _, _, listing = await arrive(service, listings)

    with pytest.raises(ForbiddenError):
        await service.active_for_listing(
            str(listing["_id"]), user=user(STRANGER_ID)
        )


async def test_a_listing_with_no_active_rescue_is_not_found(service, listings):
    listing = listings.seed(owner_id=OWNER_ID)

    with pytest.raises(Exception) as caught:
        await service.active_for_listing(str(listing["_id"]), user=owner_user())

    assert caught.value.status_code == 404
