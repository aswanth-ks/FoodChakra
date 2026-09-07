"""Index bootstrap.

Every index FoodLoop relies on is declared here and created idempotently at
startup, so a fresh environment is never silently missing one. Geospatial
(`2dsphere`) indexes are what make the dynamic rescue radius possible.

Collections are added in Phase 2 once `docs/DATABASE.md` is agreed.
"""

import logging

from motor.motor_asyncio import AsyncIOMotorDatabase

logger = logging.getLogger(__name__)


async def ensure_indexes(db: AsyncIOMotorDatabase) -> None:
    """Create all required indexes. Safe to run on every startup."""
    # Phase 2 will populate this, e.g.:
    #   await db.users.create_index("email", unique=True)
    #   await db.donations.create_index([("pickup_location", "2dsphere")])
    #   await db.donations.create_index([("status", 1), ("expires_at", 1)])
    logger.info("Index bootstrap complete (no collections defined yet — Phase 2)")
