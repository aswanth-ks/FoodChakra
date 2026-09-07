"""FoodLoop API application factory."""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pymongo.errors import PyMongoError

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging
from app.db.indexes import ensure_indexes
from app.db.mongo import close_mongo_connection, connect_to_mongo, mongo

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging()
    await connect_to_mongo()
    try:
        if mongo.database is not None:
            await ensure_indexes(mongo.database)
    except PyMongoError as exc:
        # Startup must not hard-fail on an unreachable database: /health has to
        # stay reachable so the failure is observable rather than invisible.
        logger.error("Index bootstrap skipped — MongoDB unreachable: %s", exc)
    yield
    await close_mongo_connection()


def create_app() -> FastAPI:
    settings = get_settings()

    app = FastAPI(
        title=settings.APP_NAME,
        version="0.1.0",
        description="FoodLoop — food rescue and redistribution platform API.",
        docs_url="/docs",
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_exception_handlers(app)
    app.include_router(api_router, prefix=settings.API_V1_PREFIX)

    return app


app = create_app()
