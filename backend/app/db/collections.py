"""The ten FoodLoop collections, named once.

Repositories import these constants rather than writing `db.listings` with a
string literal, so a typo is an ImportError at startup instead of a silently
created empty collection at runtime — MongoDB will happily create
`db.listing` for you and return nothing forever.

The set is deliberately closed. `docs/BACKEND_CONTRACT.md` §0 and §3.9 record
which collections were considered and rejected (`food_requests`, `matches`,
`volunteers`, `organizations`, `waste_transfers`, `analytics_events`) and why.
Adding one here needs the same justification.
"""

from typing import Final

USERS: Final = "users"
PARTNERS: Final = "partners"
LISTINGS: Final = "listings"
RESCUES: Final = "rescues"
ESCALATIONS: Final = "escalations"
FALLBACK_CASES: Final = "fallback_cases"
RECOVERY_PARTNERS: Final = "recovery_partners"
ZONES: Final = "zones"
NOTIFICATIONS: Final = "notifications"
ACTIVITY_EVENTS: Final = "activity_events"

#: Every collection FoodLoop owns. Used by the index bootstrap and by
#: `scripts/check_db.py` to report on the database.
ALL_COLLECTIONS: Final[tuple[str, ...]] = (
    USERS,
    PARTNERS,
    LISTINGS,
    RESCUES,
    ESCALATIONS,
    FALLBACK_CASES,
    RECOVERY_PARTNERS,
    ZONES,
    NOTIFICATIONS,
    ACTIVITY_EVENTS,
)
