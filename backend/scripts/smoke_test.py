import asyncio
import sys
import uuid
from datetime import UTC, datetime, timedelta
from pathlib import Path

import httpx
from motor.motor_asyncio import AsyncIOMotorClient

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import get_settings


async def main():
    settings = get_settings()
    client = AsyncIOMotorClient(settings.MONGO_URI, serverSelectionTimeoutMS=5000)
    db = client[settings.MONGO_DB_NAME]
    
    base_url = "http://127.0.0.1:8000/api/v1"
    
    unique_id = uuid.uuid4().hex[:8]
    email = f"test_{unique_id}@example.com"
    password = "SecurePassword123!"
    
    print(f"1. Registering consumer: {email}")
    async with httpx.AsyncClient(base_url=base_url) as http:
        resp = await http.post("/auth/register", json={
            "full_name": "Test User",
            "email": email,
            "password": password
        })
        if resp.status_code != 201:
            print(f"Failed to register: {resp.status_code} {resp.text}")
            return
            
        print("2. Confirming user in foodchakra.users")
        user = await db.users.find_one({"email": email})
        if not user:
            print("User not found in database!")
            return
        print("   User confirmed in database.")
        
        print("3. Bypassing email verification (since we cannot receive the email code)")
        await db.users.update_one(
            {"_id": user["_id"]},
            {"$set": {"email_verified": True}, "$unset": {"email_verification": ""}}
        )
        
        print("4. Logging in through the real login endpoint")
        resp = await http.post("/auth/login", json={
            "email": email,
            "password": password
        })
        if resp.status_code != 200:
            print(f"Failed to login: {resp.status_code} {resp.text}")
            return
        
        token = resp.json()["access_token"]
        
        print("5. Creating a real test listing through the API")
        now = datetime.now(UTC)
        pickup_from = now + timedelta(hours=1)
        pickup_until = now + timedelta(hours=4)
        
        resp = await http.post("/listings", headers={"Authorization": f"Bearer {token}"}, json={
            "food_name": "Test Surplus Food",
            "food_type": "vegetarian",
            "quantity": 10,
            "unit": "meal_boxes",
            "source": "home",
            "prepared_when": "earlier_today",
            "safety_confirmed": True,
            "pickup_location": {
                "label": "Home",
                "latitude": 13.0827,
                "longitude": 80.2707
            },
            "pickup_from": pickup_from.isoformat(),
            "pickup_until": pickup_until.isoformat()
        })
        
        if resp.status_code != 201:
            print(f"Failed to create listing: {resp.status_code} {resp.text}")
            return
            
        listing_id = resp.json()["id"]
        print(f"   Listing created: {listing_id}")
        
        print("6. Confirming the listing appears in foodchakra.listings")
        from bson import ObjectId
        listing = await db.listings.find_one({"_id": ObjectId(listing_id)})
        if not listing:
            print("Listing not found in database!")
            return
        print("   Listing confirmed in database.")
        
        print("\nCleaning up test records...")
        await db.listings.delete_one({"_id": ObjectId(listing_id)})
        await db.users.delete_one({"_id": user["_id"]})
        print("Cleanup complete.")
        
        print("\nSmoke test passed.")

if __name__ == "__main__":
    asyncio.run(main())
