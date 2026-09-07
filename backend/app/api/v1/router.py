"""Aggregates every v1 feature router.

Each new feature adds exactly one `include_router` line here. This file is the
single source of truth for what the v1 API exposes.
"""

from fastapi import APIRouter

from app.features.health.router import router as health_router

api_router = APIRouter()
api_router.include_router(health_router)

# Phase 3+: auth, users
# Phase 5+: donations
# Phase 6+: requests
# Phase 7+: rescues
# Phase 8+: matches
# Phase 10+: fallback
# Phase 12+: notifications
