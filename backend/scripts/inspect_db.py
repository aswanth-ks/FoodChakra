import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from motor.motor_asyncio import AsyncIOMotorClient

from app.core.config import get_settings


async def main():
    settings = get_settings()
    uri = settings.MONGO_URI
    db_name = settings.MONGO_DB_NAME

    print(f"Connecting to {db_name}...")
    client = AsyncIOMotorClient(uri, serverSelectionTimeoutMS=5000)
    db = client[db_name]

    try:
        await db.command("ping")
        print("MongoDB reachable.")
        
        collections = await db.list_collection_names()
        print(f"\nCollections in {db_name} ({len(collections)}):")
        for coll in collections:
            count = await db[coll].count_documents({})
            print(f"  - {coll} ({count} documents)")
            
            indexes = await db[coll].index_information()
            for name, _info in indexes.items():
                print(f"    * index: {name}")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        client.close()

if __name__ == "__main__":
    asyncio.run(main())
