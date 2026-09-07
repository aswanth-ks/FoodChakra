"""MongoDB connection lifecycle.

Exactly one Motor client exists per process. It is opened in the FastAPI
lifespan and closed on shutdown. Repositories receive a database handle through
the `get_db` dependency — they must never construct a client themselves.
"""

import logging

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class MongoConnection:
    """Holds the process-wide Motor client."""

    client: AsyncIOMotorClient | None = None
    database: AsyncIOMotorDatabase | None = None


mongo = MongoConnection()


async def connect_to_mongo() -> None:
    settings = get_settings()
    logger.info("Connecting to MongoDB database %r", settings.MONGO_DB_NAME)
    mongo.client = AsyncIOMotorClient(
        settings.MONGO_URI,
        serverSelectionTimeoutMS=5_000,
        uuidRepresentation="standard",
    )
    mongo.database = mongo.client[settings.MONGO_DB_NAME]


async def close_mongo_connection() -> None:
    if mongo.client is not None:
        logger.info("Closing MongoDB connection")
        mongo.client.close()
        mongo.client = None
        mongo.database = None


def get_db() -> AsyncIOMotorDatabase:
    """FastAPI dependency returning the shared database handle."""
    if mongo.database is None:
        raise RuntimeError(
            "MongoDB is not initialised. connect_to_mongo() must run in the app lifespan."
        )
    return mongo.database
