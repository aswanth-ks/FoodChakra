"""Index bootstrap tests.

These run without MongoDB: `ensure_indexes` is exercised against a fake
database that records what it was asked to create. That is enough to catch the
failures that actually happen — a collection with no indexes declared, a
duplicate index name, or the claim index losing its partial filter.
"""

import pytest
from pymongo import IndexModel

from app.db import collections as col
from app.db.indexes import INDEX_SPECS, ensure_indexes
from app.shared.lifecycle import RESCUE_ACTIVE_STATES


class FakeCollection:
    def __init__(self, name: str, recorder: dict[str, list[IndexModel]]) -> None:
        self._name = name
        self._recorder = recorder

    async def create_indexes(self, models: list[IndexModel]) -> list[str]:
        self._recorder[self._name] = models
        return [model.document["name"] for model in models]


class FakeDatabase:
    def __init__(self) -> None:
        self.created: dict[str, list[IndexModel]] = {}
        self.pinged = False

    async def command(self, name: str) -> dict[str, int]:
        assert name == "ping"
        self.pinged = True
        return {"ok": 1}

    def __getitem__(self, name: str) -> FakeCollection:
        return FakeCollection(name, self.created)


@pytest.fixture
def fake_db():
    return FakeDatabase()


async def test_ensure_indexes_covers_every_collection(fake_db):
    await ensure_indexes(fake_db)

    assert set(fake_db.created) == set(col.ALL_COLLECTIONS)


async def test_bootstrap_probes_connectivity_before_creating_indexes(fake_db):
    """One failed probe beats ten server-selection timeouts stalling startup."""
    await ensure_indexes(fake_db)

    assert fake_db.pinged is True


def test_the_collection_set_is_exactly_ten():
    """The audit closed this set. Growing it needs a documented reason."""
    assert len(col.ALL_COLLECTIONS) == 10
    assert set(INDEX_SPECS) == set(col.ALL_COLLECTIONS)


def test_no_collection_was_left_without_indexes():
    for name, models in INDEX_SPECS.items():
        assert models, f"{name} declares no indexes"


def test_index_names_are_explicit_and_unique_within_a_collection():
    # An unnamed index gets an auto-generated name that changes when its keys
    # change, silently leaving the old index behind on redeploy.
    for name, models in INDEX_SPECS.items():
        index_names = [model.document["name"] for model in models]
        assert all(index_names), f"{name} has an unnamed index"
        assert len(index_names) == len(set(index_names)), f"{name} has duplicate names"


def _index(collection: str, index_name: str) -> dict:
    for model in INDEX_SPECS[collection]:
        if model.document["name"] == index_name:
            return model.document
    raise AssertionError(f"{collection} has no index named {index_name}")


def test_rescue_claim_index_is_unique_and_partial():
    """The one index the correctness of the whole product rests on."""
    document = _index(col.RESCUES, "uniq_active_rescue_per_listing")

    assert document["unique"] is True
    assert document["key"] == {"listing_id": 1}

    # Partial, not plain-unique: a plain unique index would forbid re-claiming
    # a listing after a cancelled rescue, permanently burning the surplus.
    states = set(document["partialFilterExpression"]["status"]["$in"])
    assert states == {state.value for state in RESCUE_ACTIVE_STATES}


def test_expiry_sweep_index_exists():
    """Without this the escalation sweep is a full scan on every tick."""
    document = _index(col.LISTINGS, "by_status_expires_at")
    assert document["key"] == {"status": 1, "expires_at": 1}


@pytest.mark.parametrize(
    ("collection", "index_name", "field"),
    [
        (col.LISTINGS, "geo_pickup_location", "pickup_location.point"),
        (col.PARTNERS, "geo_location", "location"),
        (col.USERS, "geo_rescuer_location", "rescuer.last_location"),
        (col.RESCUES, "geo_rescuer_location", "rescuer_location"),
        (col.RECOVERY_PARTNERS, "geo_location", "location"),
        (col.ZONES, "geo_boundary", "boundary"),
    ],
)
def test_geospatial_indexes(collection, index_name, field):
    """Without 2dsphere, Explore and the dynamic radius cannot be written at all."""
    document = _index(collection, index_name)
    assert document["key"] == {field: "2dsphere"}


@pytest.mark.parametrize(
    ("collection", "index_name"),
    [(col.USERS, "uniq_email"), (col.LISTINGS, "uniq_reference")],
)
def test_uniqueness_guarantees(collection, index_name):
    assert _index(collection, index_name)["unique"] is True


def test_rejected_collections_are_not_reintroduced():
    """The audit ruled these out; see docs/BACKEND_CONTRACT.md §0 and §3.9."""
    rejected = {
        "food_requests",
        "matches",
        "volunteers",
        "organizations",
        "waste_transfers",
        "analytics_events",
        "donations",
    }
    assert not rejected & set(col.ALL_COLLECTIONS)
