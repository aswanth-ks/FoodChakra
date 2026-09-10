"""The canonical lifecycle is the one thing every later stage builds on.

These tests exist to make drift loud: if someone adds a state and forgets to
place it in the listing/rescue split, or projects it for one client but not the
other, a test fails rather than a screen silently rendering nothing.
"""

import pytest

from app.shared.lifecycle import (
    LIFECYCLE_ORDER,
    LISTING_CLAIMABLE_STATES,
    LISTING_STATES,
    LISTING_TRANSITIONS,
    RESCUE_ACTIVE_STATES,
    RESCUE_STATES,
    RESCUE_TRANSITIONS,
    TERMINAL_STATES,
    LifecycleState,
    PartnerSurplusStatus,
    RescueStage,
    can_transition,
    is_terminal,
    progress_index,
    to_partner_status,
    to_rescue_stage,
)


def test_forward_path_matches_the_consoles_nine_steps():
    # The console's LIFECYCLE_ORDER is the contract; these strings are what the
    # dashboard's TypeScript union expects to parse.
    assert [state.value for state in LIFECYCLE_ORDER] == [
        "draft",
        "published",
        "searching",
        "matched",
        "onTheWay",
        "arrived",
        "verified",
        "collected",
        "completed",
    ]


def test_every_state_belongs_to_a_document():
    """No state may be orphaned — each is held by a listing, a rescue, or both."""
    covered = LISTING_STATES | RESCUE_STATES
    assert covered == set(LifecycleState)


def test_ownership_changes_hands_at_matched():
    # Before `matched` the listing drives; after it, the rescue does.
    assert LifecycleState.SEARCHING in LISTING_STATES
    assert LifecycleState.SEARCHING not in RESCUE_STATES
    assert LifecycleState.ARRIVED in RESCUE_STATES
    assert LifecycleState.ARRIVED not in LISTING_STATES
    # `matched` is the handover point and belongs to both.
    assert LifecycleState.MATCHED in LISTING_STATES & RESCUE_STATES


def test_active_rescue_states_exclude_every_terminal_state():
    """This set is the partial index's filter — a mistake here re-opens the race."""
    assert {
        LifecycleState.MATCHED,
        LifecycleState.ON_THE_WAY,
        LifecycleState.ARRIVED,
        LifecycleState.VERIFIED,
        LifecycleState.COLLECTED,
    } == RESCUE_ACTIVE_STATES
    assert not RESCUE_ACTIVE_STATES & TERMINAL_STATES


def test_a_cancelled_rescue_frees_its_listing():
    # The whole reason the claim index is partial rather than plain-unique.
    assert LifecycleState.CANCELLED not in RESCUE_ACTIVE_STATES
    assert LifecycleState.NO_SHOW not in RESCUE_ACTIVE_STATES


def test_only_published_and_searching_listings_are_claimable():
    assert {
        LifecycleState.PUBLISHED,
        LifecycleState.SEARCHING,
    } == LISTING_CLAIMABLE_STATES
    assert LifecycleState.MATCHED not in LISTING_CLAIMABLE_STATES


@pytest.mark.parametrize(
    ("current", "target", "expected"),
    [
        (LifecycleState.DRAFT, LifecycleState.PUBLISHED, True),
        # Publishing must not skip straight to collected.
        (LifecycleState.DRAFT, LifecycleState.COLLECTED, False),
        (LifecycleState.SEARCHING, LifecycleState.MATCHED, True),
        (LifecycleState.SEARCHING, LifecycleState.FALLBACK, True),
        # A cancelled rescue returns the listing to the pool.
        (LifecycleState.MATCHED, LifecycleState.SEARCHING, True),
        (LifecycleState.COMPLETED, LifecycleState.SEARCHING, False),
    ],
)
def test_listing_transitions(current, target, expected):
    assert (
        can_transition(current, target, transitions=LISTING_TRANSITIONS) is expected
    )


@pytest.mark.parametrize(
    ("current", "target", "expected"),
    [
        (LifecycleState.MATCHED, LifecycleState.ON_THE_WAY, True),
        (LifecycleState.ON_THE_WAY, LifecycleState.ARRIVED, True),
        (LifecycleState.ARRIVED, LifecycleState.VERIFIED, True),
        (LifecycleState.VERIFIED, LifecycleState.COLLECTED, True),
        # Collection must not bypass handover verification.
        (LifecycleState.ARRIVED, LifecycleState.COLLECTED, False),
        # Terminal means terminal.
        (LifecycleState.CANCELLED, LifecycleState.MATCHED, False),
    ],
)
def test_rescue_transitions(current, target, expected):
    assert can_transition(current, target, transitions=RESCUE_TRANSITIONS) is expected


def test_transition_tables_only_reference_states_the_document_can_hold():
    for source, targets in LISTING_TRANSITIONS.items():
        assert source in LISTING_STATES
        assert targets <= LISTING_STATES
    for source, targets in RESCUE_TRANSITIONS.items():
        assert source in RESCUE_STATES
        assert targets <= RESCUE_STATES


def test_terminal_states_have_no_outgoing_transitions():
    for state in TERMINAL_STATES:
        assert state not in LISTING_TRANSITIONS
        assert state not in RESCUE_TRANSITIONS
        assert is_terminal(state)


def test_progress_index_tracks_the_forward_path():
    assert progress_index(LifecycleState.DRAFT) == 0
    assert progress_index(LifecycleState.COMPLETED) == 8
    # A failure state is off the path entirely rather than at position zero.
    assert progress_index(LifecycleState.CANCELLED) is None


@pytest.mark.parametrize(
    ("state", "expected"),
    [
        (LifecycleState.MATCHED, RescueStage.CONFIRMED),
        (LifecycleState.ON_THE_WAY, RescueStage.READY),
        (LifecycleState.ARRIVED, RescueStage.PICKUP),
        (LifecycleState.VERIFIED, RescueStage.PICKUP),
        (LifecycleState.COLLECTED, RescueStage.COLLECTED),
        (LifecycleState.COMPLETED, RescueStage.COLLECTED),
        # Not yet in flight — the stepper is not shown at all.
        (LifecycleState.SEARCHING, None),
    ],
)
def test_mobile_projection(state, expected):
    assert to_rescue_stage(state) is expected


@pytest.mark.parametrize(
    ("state", "expected"),
    [
        (LifecycleState.DRAFT, PartnerSurplusStatus.DRAFT),
        (LifecycleState.PUBLISHED, PartnerSurplusStatus.LOOKING_FOR_RESCUER),
        (LifecycleState.SEARCHING, PartnerSurplusStatus.LOOKING_FOR_RESCUER),
        (LifecycleState.MATCHED, PartnerSurplusStatus.RESCUER_MATCHED),
        (LifecycleState.ARRIVED, PartnerSurplusStatus.AWAITING_HANDOVER),
        (LifecycleState.COMPLETED, PartnerSurplusStatus.COLLECTED),
        (LifecycleState.EXPIRED, PartnerSurplusStatus.EXPIRED),
    ],
)
def test_partner_projection(state, expected):
    assert to_partner_status(state) is expected


def test_every_listing_state_a_partner_can_see_has_a_projection():
    """A partner must never be shown a blank status for their own surplus."""
    partner_visible = LISTING_STATES - {LifecycleState.CANCELLED, LifecycleState.FALLBACK}
    for state in partner_visible:
        assert to_partner_status(state) is not None, state
