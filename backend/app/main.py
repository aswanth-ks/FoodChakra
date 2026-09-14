"""FoodLoop API application factory."""

import logging
import time
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.logging import configure_logging
from app.core.startup_timing import startup_timing
from app.db.indexes import ensure_indexes
from app.db.mongo import close_mongo_connection, connect_to_mongo, mongo

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    configure_logging()

    # Timed so a slow first request can be attributed rather than guessed at.
    # The numbers are surfaced on `/health`; see `startup_timing`.
    began = time.monotonic()
    await connect_to_mongo()
    startup_timing.connect_ms = int((time.monotonic() - began) * 1000)

    if mongo.database is not None:
        logger.info("MongoDB connected to database: %s", mongo.database.name)
        indexes_began = time.monotonic()
        await ensure_indexes(mongo.database)
        startup_timing.indexes_ms = int((time.monotonic() - indexes_began) * 1000)
        logger.info("MongoDB indexes initialized")

    startup_timing.total_ms = int((time.monotonic() - began) * 1000)
    logger.info(
        "Application ready — connect %sms, indexes %sms, total %sms",
        startup_timing.connect_ms,
        startup_timing.indexes_ms,
        startup_timing.total_ms,
    )
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
