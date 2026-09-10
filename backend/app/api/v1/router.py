"""Aggregates every v1 feature router.

Each new feature adds exactly one `include_router` line here. This file is the
single source of truth for what the v1 API exposes.
"""

from fastapi import APIRouter

from app.features.auth.router import router as auth_router
from app.features.health.router import router as health_router
from app.features.listings.router import router as listings_router
from app.features.rescues.router import router as rescues_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(auth_router)
api_router.include_router(listings_router)
api_router.include_router(rescues_router)

# Phase 10+: fallback
# Phase 12+: notifications
