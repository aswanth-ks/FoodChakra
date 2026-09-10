"""Listings tests.

The repository is faked in memory — including `$nearSphere`'s radius filter and
nearest-first ordering — so the suite is deterministic and needs no Atlas
connection. Everything above the driver is the real implementation: schema
validation, ownership, lifecycle legality, projections and activity events.
"""

import math
from datetime import UTC, datetime, timedelta
from typing import Any

import pytest
from bson import ObjectId
from httpx import ASGITransport, AsyncClient

from app.db.mongo import get_db
from app.features.activity.service import ActivityService
from app.features.auth.dependencies import get_current_user
from app.features.auth.schemas import AccountRole, AccountStatus, UserResponse
from app.features.listings.repository import ListingRepository, claimable_filter
from app.features.listings.router import get_listing_service
from app.features.listings.service import ListingService
from app.main import create_app
from app.shared.lifecycle import LISTING_CLAIMABLE_STATES, LifecycleState
from tests.test_activity import FakeActivityRepository

KARUR = (10.9577, 78.0809)


class FakeListingRepository(ListingRepository):
    """In-memory listings, reproducing the queries the real one issues."""

    def __init__(self) -> None:
        self.documents: dict[ObjectId, dict[str, Any]] = {}

    async def create(self, document: dict[str, Any]) -> dict[str, Any]:
        object_id = ObjectId()
        stored = {**document, "_id": object_id}
        self.documents[object_id] = stored
        return stored

    async def find_by_id(self, listing_id: str) -> dict[str, Any] | None:
        try:
            return self.documents.get(ObjectId(listing_id))
        except Exception:
            return None

    async def set_status(
        self, listing_id, *, expected, status, extra=None
    ) -> dict[str, Any] | None:
        stored = self.documents.get(listing_id)
        if stored is None or stored["status"] not in [s.value for s in expected]:
            return None
        stored.update(extra or {})
        stored["status"] = status.value
        stored["updated_at"] = datetime.now(UTC)
        return stored

    async def reference_exists(self, reference: str) -> bool:
        return any(d["reference"] == reference for d in self.documents.values())

    async def find_nearby(
        self,
        *,
        longitude,
        latitude,
        radius_km,
        limit,
        offset,
        food_types=None,
        source=None,
    ) -> list[dict[str, Any]]:
        criteria = claimable_filter()
        allowed = set(criteria["status"]["$in"])
        now = criteria["expires_at"]["$gt"]

        def distance(doc: dict[str, Any]) -> float:
            lng, lat = doc["pickup_location"]["point"]["coordinates"]
            return _haversine_km((latitude, longitude), (lat, lng))

        matches = [
            d
            for d in self.documents.values()
            if d["status"] in allowed
            and _aware(d["expires_at"]) > now
            and distance(d) <= radius_km
            and (not food_types or d["food_type"] in food_types)
            and (source is None or d.get("source") == source)
        ]
        matches.sort(key=distance)
        return matches[offset : offset + limit]

    async def find_by_owner(
        self, *, owner_id, statuses, limit, offset
    ) -> list[dict[str, Any]]:
        matches = [
            d
            for d in self.documents.values()
            if d["owner_user_id"] == owner_id
            and (not statuses or d["status"] in statuses)
        ]
        matches.sort(key=lambda d: d["created_at"], reverse=True)
        return matches[offset : offset + limit]

    # ----- test helper -----
    def seed(
        self,
        *,
        owner_id: ObjectId,
        status: LifecycleState = LifecycleState.PUBLISHED,
        coordinates: tuple[float, float] = KARUR,
        food_type: str = "vegetarian",
        minutes_until_close: int = 240,
        created_at: datetime | None = None,
        source: str | None = None,
    ) -> dict[str, Any]:
        now = datetime.now(UTC)
        until = now + timedelta(minutes=minutes_until_close)
        object_id = ObjectId()
        stored = {
            "_id": object_id,
            "reference": f"FL-{10000 + len(self.documents)}",
            "source_kind": "consumer",
            "owner_user_id": owner_id,
            "owner_display_name": "Asha Rao",
            "partner_id": None,
            "source": source,
            "title": "25 Meal Boxes",
            "food_name": "Vegetable biryani",
            "food_type": food_type,
            "quantity": 25,
            "unit": "meal_boxes",
            "servings_estimate": 25,
            "weight_kg": None,
            "prepared_when": "earlier_today",
            "description": "Freshly prepared.",
            "tags": ["Plant-Based"],
            "photo_url": None,
            "safety_confirmed": True,
            "pickup_location": {
                "label": "Community Hall",
                "locality": "Karur, Tamil Nadu",
                "pickup_point": None,
                "point": {
                    "type": "Point",
                    "coordinates": [coordinates[1], coordinates[0]],
                },
            },
            "pickup_from": now - timedelta(minutes=10),
            "pickup_until": until,
            "expires_at": until,
            "status": status.value,
            "active_rescue_id": None,
            "search_radius_km": 5.0,
            "escalation_id": None,
            "is_live": False,
            "published_at": now,
            "created_at": created_at or now,
            "updated_at": now,
        }
        self.documents[object_id] = stored
        return stored


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=UTC)


def _haversine_km(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat1, lon1 = math.radians(a[0]), math.radians(a[1])
    lat2, lon2 = math.radians(b[0]), math.radians(b[1])
    h = (
        math.sin((lat2 - lat1) / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2
    )
    return 2 * 6371.0 * math.asin(math.sqrt(h))


CONSUMER_ID = ObjectId()
OTHER_ID = ObjectId()
PARTNER_ID = ObjectId()


def user(
    user_id: ObjectId = CONSUMER_ID,
    role: AccountRole = AccountRole.CONSUMER,
    partner_id: str | None = None,
) -> UserResponse:
    return UserResponse(
        id=str(user_id),
        email="asha@example.com",
        full_name="Asha Rao",
        role=role,
        status=AccountStatus.ACTIVE,
        email_verified=True,
        is_staff=False,
        partner_id=partner_id,
        created_at=datetime.now(UTC),
    )


@pytest.fixture
def listings() -> FakeListingRepository:
    return FakeListingRepository()


@pytest.fixture
def events() -> FakeActivityRepository:
    return FakeActivityRepository()


@pytest.fixture
def current_user() -> dict[str, UserResponse]:
    """Mutable holder so a test can switch who is signed in."""
    return {"user": user()}


@pytest.fixture
def app(listings, events, current_user):
    application = create_app()
    application.dependency_overrides[get_listing_service] = lambda: ListingService(
        listings, ActivityService(events)
    )
    application.dependency_overrides[get_current_user] = lambda: current_user["user"]
    return application


@pytest.fixture
async def api(app):
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


@pytest.fixture
async def anon_api(listings, events):
    """No auth override — exercises the real `get_current_user` dependency.

    `get_db` is stubbed only because FastAPI builds a route's whole dependency
    tree before any of it runs, so the service (and its database handle) is
    constructed even on a request that is about to be rejected as anonymous.
    """
    application = create_app()
    application.dependency_overrides[get_db] = lambda: None
    application.dependency_overrides[get_listing_service] = lambda: ListingService(
        listings, ActivityService(events)
    )
    transport = ASGITransport(app=application)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        yield client


def payload(**overrides: Any) -> dict[str, Any]:
    now = datetime.now(UTC)
    body = {
        "food_name": "Vegetable biryani",
        "food_type": "vegetarian",
        "quantity": 25,
        "unit": "meal_boxes",
        "source": "event",
        "prepared_when": "earlier_today",
        "safety_confirmed": True,
        "description": "Freshly prepared vegetarian meals.",
        "tags": ["Plant-Based"],
        "pickup_location": {
            "label": "Community Hall",
            "locality": "Karur, Tamil Nadu",
            "latitude": KARUR[0],
            "longitude": KARUR[1],
        },
        "pickup_from": (now - timedelta(minutes=5)).isoformat(),
        "pickup_until": (now + timedelta(hours=3)).isoformat(),
    }
    body.update(overrides)
    return body


# -------------------------------------------------------------- create


async def test_authenticated_creation_publishes_a_listing(api, listings):
    response = await api.post("/api/v1/listings", json=payload())

    assert response.status_code == 201
    body = response.json()
    assert body["status"] == LifecycleState.PUBLISHED.value
    assert body["title"] == "25 Meal Boxes"
    assert body["category"] == "Vegetarian"
    assert body["is_available"] is True
    assert body["reference"].startswith("FL-")
    assert len(listings.documents) == 1


async def test_unauthenticated_creation_is_rejected(anon_api, listings):
    response = await anon_api.post("/api/v1/listings", json=payload())

    assert response.status_code == 401
    assert listings.documents == {}


async def test_owner_is_taken_from_the_token_not_the_body(api, listings):
    """A forged owner is refused outright rather than quietly overridden."""
    response = await api.post(
        "/api/v1/listings", json=payload(owner_user_id=str(OTHER_ID))
    )

    assert response.status_code == 422
    assert listings.documents == {}


@pytest.mark.parametrize(
    "field",
    ["status", "reference", "created_at", "published_at", "source_kind", "partner_id"],
)
async def test_server_owned_fields_cannot_be_supplied(api, listings, field):
    response = await api.post("/api/v1/listings", json=payload(**{field: "x"}))

    assert response.status_code == 422
    assert listings.documents == {}


async def test_creation_assigns_ownership_and_timestamps_server_side(api, listings):
    before = datetime.now(UTC)

    await api.post("/api/v1/listings", json=payload())

    [stored] = listings.documents.values()
    assert stored["owner_user_id"] == CONSUMER_ID
    assert _aware(stored["created_at"]) >= before
    assert stored["status"] == LifecycleState.PUBLISHED.value


async def test_coordinates_are_stored_longitude_first(api, listings):
    # GeoJSON is [lng, lat]. Reversed, every query still "works" and every
    # result is in the wrong hemisphere.
    await api.post("/api/v1/listings", json=payload())

    [stored] = listings.documents.values()
    assert stored["pickup_location"]["point"]["coordinates"] == [KARUR[1], KARUR[0]]


async def test_a_partner_listing_is_marked_as_such(api, listings, current_user):
    current_user["user"] = user(
        PARTNER_ID, role=AccountRole.PARTNER, partner_id=str(PARTNER_ID)
    )

    response = await api.post("/api/v1/listings", json=payload())

    assert response.json()["source_kind"] == "partner"
    assert response.json()["shared_by_verified"] is True


async def test_safety_confirmation_is_required(api, listings):
    response = await api.post("/api/v1/listings", json=payload(safety_confirmed=False))

    assert response.status_code == 409
    assert listings.documents == {}


async def test_a_closed_pickup_window_is_rejected(api):
    now = datetime.now(UTC)
    response = await api.post(
        "/api/v1/listings",
        json=payload(
            pickup_from=(now - timedelta(hours=3)).isoformat(),
            pickup_until=(now - timedelta(hours=1)).isoformat(),
        ),
    )

    assert response.status_code == 409


async def test_pickup_window_must_run_forwards(api):
    now = datetime.now(UTC)
    response = await api.post(
        "/api/v1/listings",
        json=payload(
            pickup_from=(now + timedelta(hours=3)).isoformat(),
            pickup_until=(now + timedelta(hours=1)).isoformat(),
        ),
    )

    assert response.status_code == 422


@pytest.mark.parametrize(
    "overrides",
    [
        {"quantity": 0},
        {"quantity": -5},
        {"food_type": "meat-ish"},
        {"unit": "buckets"},
        {"food_name": ""},
        {"weight_kg": -1},
    ],
)
async def test_invalid_input_is_rejected(api, listings, overrides):
    response = await api.post("/api/v1/listings", json=payload(**overrides))

    assert response.status_code == 422
    assert listings.documents == {}


@pytest.mark.parametrize(
    "location",
    [
        {"label": "X", "latitude": 91, "longitude": 0},
        {"label": "X", "latitude": 0, "longitude": 181},
        {"label": "X", "latitude": 10.0},
        {"label": "X"},
    ],
)
async def test_pickup_coordinates_are_validated(api, location):
    response = await api.post("/api/v1/listings", json=payload(pickup_location=location))
    assert response.status_code == 422


async def test_weight_is_optional_and_preserved(api, listings):
    """The Give UI does not ask for a weight; fallback routing will need one."""
    without = await api.post("/api/v1/listings", json=payload())
    assert without.status_code == 201
    assert without.json()["weight_kg"] is None

    with_weight = await api.post("/api/v1/listings", json=payload(weight_kg=12.5))
    assert with_weight.json()["weight_kg"] == 12.5


async def test_kilogram_listings_estimate_servings(api):
    response = await api.post(
        "/api/v1/listings", json=payload(unit="kilograms", quantity=10)
    )

    assert response.json()["title"] == "10 kg"
    assert response.json()["servings"] == 25


async def test_creation_writes_an_activity_event(api, events):
    response = await api.post("/api/v1/listings", json=payload())

    [event] = events.events
    assert event.action == "listing_created"
    assert event.subject.type == "listing"
    assert event.subject.id == response.json()["id"]
    assert event.subject.reference == response.json()["reference"]
    assert event.context["food_type"] == "vegetarian"


# -------------------------------------------------------------- nearby


async def test_nearby_returns_claimable_listings(api, listings):
    listings.seed(owner_id=OTHER_ID)

    response = await api.get(
        "/api/v1/listings/nearby", params={"lat": KARUR[0], "lng": KARUR[1]}
    )

    assert response.status_code == 200
    assert len(response.json()["items"]) == 1
    assert response.json()["items"][0]["is_available"] is True


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
async def test_unavailable_listings_are_excluded(api, listings, status):
    listings.seed(owner_id=OTHER_ID, status=status)

    response = await api.get(
        "/api/v1/listings/nearby", params={"lat": KARUR[0], "lng": KARUR[1]}
    )

    assert response.json()["items"] == []


async def test_the_excluded_statuses_are_exactly_the_non_claimable_ones(listings):
    """Guards against the filter and the lifecycle drifting apart."""
    allowed = set(claimable_filter()["status"]["$in"])
    assert allowed == {s.value for s in LISTING_CLAIMABLE_STATES}


async def test_expired_window_is_excluded_even_when_still_published(api, listings):
    listings.seed(owner_id=OTHER_ID, minutes_until_close=-30)

    response = await api.get(
        "/api/v1/listings/nearby", params={"lat": KARUR[0], "lng": KARUR[1]}
    )

    assert response.json()["items"] == []


async def test_listings_outside_the_radius_are_excluded(api, listings):
    listings.seed(owner_id=OTHER_ID, coordinates=KARUR)
    # ~110 km north.
    listings.seed(owner_id=OTHER_ID, coordinates=(KARUR[0] + 1.0, KARUR[1]))

    response = await api.get(
        "/api/v1/listings/nearby",
        params={"lat": KARUR[0], "lng": KARUR[1], "radius_km": 5},
    )

    assert len(response.json()["items"]) == 1


async def test_results_are_nearest_first_with_a_distance_label(api, listings):
    listings.seed(owner_id=OTHER_ID, coordinates=(KARUR[0] + 0.03, KARUR[1]))
    listings.seed(owner_id=OTHER_ID, coordinates=KARUR)

    response = await api.get(
        "/api/v1/listings/nearby",
        params={"lat": KARUR[0], "lng": KARUR[1], "radius_km": 20},
    )

    distances = [item["distance_km"] for item in response.json()["items"]]
    assert distances == sorted(distances)
    assert distances[0] == 0.0


async def test_nearby_filters_by_food_type(api, listings):
    listings.seed(owner_id=OTHER_ID, food_type="vegetarian")
    listings.seed(owner_id=OTHER_ID, food_type="non_veg")

    response = await api.get(
        "/api/v1/listings/nearby",
        params={"lat": KARUR[0], "lng": KARUR[1], "food_type": "vegetarian"},
    )

    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["food_type"] == "vegetarian"


async def test_nearby_pagination(api, listings):
    for index in range(5):
        listings.seed(
            owner_id=OTHER_ID, coordinates=(KARUR[0] + index * 0.001, KARUR[1])
        )

    first = await api.get(
        "/api/v1/listings/nearby",
        params={"lat": KARUR[0], "lng": KARUR[1], "limit": 2, "offset": 0},
    )
    second = await api.get(
        "/api/v1/listings/nearby",
        params={"lat": KARUR[0], "lng": KARUR[1], "limit": 2, "offset": 4},
    )

    assert len(first.json()["items"]) == 2
    assert first.json()["has_more"] is True
    assert len(second.json()["items"]) == 1
    assert second.json()["has_more"] is False


async def test_nearby_requires_authentication(anon_api):
    response = await anon_api.get(
        "/api/v1/listings/nearby", params={"lat": KARUR[0], "lng": KARUR[1]}
    )
    assert response.status_code == 401


async def test_nearby_requires_coordinates(api):
    assert (await api.get("/api/v1/listings/nearby")).status_code == 422


async def test_urgency_is_derived_from_the_window_not_stored(api, listings):
    listings.seed(owner_id=OTHER_ID, minutes_until_close=10)
    listings.seed(owner_id=OTHER_ID, minutes_until_close=45)
    listings.seed(owner_id=OTHER_ID, minutes_until_close=600)

    response = await api.get(
        "/api/v1/listings/nearby", params={"lat": KARUR[0], "lng": KARUR[1]}
    )

    urgencies = {item["urgency"] for item in response.json()["items"]}
    assert urgencies == {"critical", "expiring", "available"}
    # Nothing about urgency reaches storage.
    for stored in listings.documents.values():
        assert "urgency" not in stored


# -------------------------------------------------------------- detail


async def test_listing_detail(api, listings):
    stored = listings.seed(owner_id=OTHER_ID)

    response = await api.get(f"/api/v1/listings/{stored['_id']}")

    assert response.status_code == 200
    body = response.json()
    assert body["description"] == "Freshly prepared."
    assert body["tags"] == ["Plant-Based"]
    assert body["prepared_note"] == "Prepared earlier today"
    assert body["is_available"] is True


async def test_detail_never_exposes_internal_identifiers(api, listings):
    stored = listings.seed(owner_id=OTHER_ID)

    response = await api.get(f"/api/v1/listings/{stored['_id']}")

    assert "owner_user_id" not in response.text
    assert str(OTHER_ID) not in response.text
    assert "password" not in response.text
    assert "refresh_sessions" not in response.text
    # The publisher is a display name only.
    assert response.json()["shared_by"] == "Asha Rao"


async def test_detail_reports_an_unavailable_listing_as_such(api, listings):
    stored = listings.seed(owner_id=OTHER_ID, status=LifecycleState.MATCHED)

    response = await api.get(f"/api/v1/listings/{stored['_id']}")

    assert response.status_code == 200
    assert response.json()["is_available"] is False


@pytest.mark.parametrize("listing_id", ["nonsense", str(ObjectId())])
async def test_unknown_listing_is_not_found(api, listing_id):
    response = await api.get(f"/api/v1/listings/{listing_id}")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "NOT_FOUND"


async def test_detail_requires_authentication(anon_api):
    response = await anon_api.get(f"/api/v1/listings/{ObjectId()}")
    assert response.status_code == 401


# ---------------------------------------------------------------- mine


async def test_mine_returns_only_the_callers_listings(api, listings):
    listings.seed(owner_id=CONSUMER_ID)
    listings.seed(owner_id=OTHER_ID)

    response = await api.get("/api/v1/listings/mine")

    assert len(response.json()["items"]) == 1


async def test_mine_includes_listings_that_are_no_longer_claimable(api, listings):
    """The Activity History tab exists precisely to show these."""
    listings.seed(owner_id=CONSUMER_ID, status=LifecycleState.COMPLETED)

    response = await api.get("/api/v1/listings/mine")

    assert len(response.json()["items"]) == 1
    assert response.json()["items"][0]["is_available"] is False


async def test_mine_filters_by_status(api, listings):
    listings.seed(owner_id=CONSUMER_ID, status=LifecycleState.PUBLISHED)
    listings.seed(owner_id=CONSUMER_ID, status=LifecycleState.COMPLETED)

    response = await api.get("/api/v1/listings/mine", params={"status": "completed"})

    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["status"] == "completed"


async def test_mine_is_newest_first(api, listings):
    now = datetime.now(UTC)
    listings.seed(owner_id=CONSUMER_ID, created_at=now - timedelta(days=2))
    newest = listings.seed(owner_id=CONSUMER_ID, created_at=now)

    response = await api.get("/api/v1/listings/mine")

    assert response.json()["items"][0]["id"] == str(newest["_id"])


# -------------------------------------------------------------- cancel


async def test_owner_can_withdraw_a_published_listing(api, listings, events):
    stored = listings.seed(owner_id=CONSUMER_ID)

    response = await api.post(
        f"/api/v1/listings/{stored['_id']}/cancel",
        json={"reason": "Collected in person."},
    )

    assert response.status_code == 200
    assert response.json()["status"] == LifecycleState.CANCELLED.value
    assert response.json()["is_available"] is False
    assert stored["cancel_reason"] == "Collected in person."


async def test_cancellation_writes_an_activity_event(api, listings, events):
    stored = listings.seed(owner_id=CONSUMER_ID)

    await api.post(f"/api/v1/listings/{stored['_id']}/cancel", json={})

    [event] = events.events
    assert event.action == "listing_cancelled"
    assert event.subject.id == str(stored["_id"])
    assert event.context["previous_status"] == LifecycleState.PUBLISHED.value


async def test_a_non_owner_cannot_withdraw_a_listing(api, listings, events):
    stored = listings.seed(owner_id=OTHER_ID)

    response = await api.post(f"/api/v1/listings/{stored['_id']}/cancel", json={})

    assert response.status_code == 403
    assert stored["status"] == LifecycleState.PUBLISHED.value
    assert events.events == []


async def test_cancellation_requires_authentication(anon_api):
    response = await anon_api.post(f"/api/v1/listings/{ObjectId()}/cancel", json={})
    assert response.status_code == 401


@pytest.mark.parametrize(
    "status",
    [
        LifecycleState.MATCHED,
        LifecycleState.COLLECTED,
        LifecycleState.COMPLETED,
        LifecycleState.CANCELLED,
    ],
)
async def test_illegal_cancellations_are_refused_by_the_lifecycle(
    api, listings, status
):
    """A claimed listing has a rescuer en route; withdrawal is not the owner's."""
    stored = listings.seed(owner_id=CONSUMER_ID, status=status)

    response = await api.post(f"/api/v1/listings/{stored['_id']}/cancel", json={})

    assert response.status_code == 409
    assert stored["status"] == status.value


async def test_a_searching_listing_can_still_be_withdrawn(api, listings):
    stored = listings.seed(owner_id=CONSUMER_ID, status=LifecycleState.SEARCHING)

    response = await api.post(f"/api/v1/listings/{stored['_id']}/cancel", json={})

    assert response.status_code == 200


async def test_cancelling_an_unknown_listing_is_not_found(api):
    response = await api.post(f"/api/v1/listings/{ObjectId()}/cancel", json={})
    assert response.status_code == 404


# ------------------------------------------------- stage E readiness


async def test_claimable_filter_is_ready_for_the_atomic_claim():
    """Stage E's `find_one_and_update` filter, shared with `/nearby`."""
    criteria = claimable_filter()

    assert set(criteria) == {"status", "expires_at"}
    assert set(criteria["status"]["$in"]) == {s.value for s in LISTING_CLAIMABLE_STATES}
    assert "$gt" in criteria["expires_at"]


async def test_set_status_guards_on_the_expected_state(listings):
    """The guard is in the query, so two concurrent writers cannot both win."""
    stored = listings.seed(owner_id=CONSUMER_ID, status=LifecycleState.PUBLISHED)

    first = await listings.set_status(
        stored["_id"],
        expected=[LifecycleState.PUBLISHED],
        status=LifecycleState.CANCELLED,
    )
    second = await listings.set_status(
        stored["_id"],
        expected=[LifecycleState.PUBLISHED],
        status=LifecycleState.CANCELLED,
    )

    assert first is not None
    assert second is None
