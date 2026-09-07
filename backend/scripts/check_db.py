"""MongoDB connectivity diagnostic.

Run this whenever the database is unreachable. It separates the three failure
modes that all surface as the same unhelpful driver error:

    1. Network    - outbound 27017 is blocked (fails at TCP connect)
    2. Allowlist  - your public IP is not in Atlas Network Access
    3. Credentials- wrong username or password (fails at auth, after TCP)

Usage:
    ./.venv/Scripts/python.exe scripts/check_db.py
"""

import asyncio
import socket
import sys
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from pymongo.errors import OperationFailure, PyMongoError  # noqa: E402

from app.core.config import get_settings  # noqa: E402

TICK, CROSS, WARN = "[ OK ]", "[FAIL]", "[WARN]"


def public_ip() -> str:
    try:
        return urllib.request.urlopen("https://api.ipify.org", timeout=8).read().decode()
    except Exception:
        return "unknown"


def resolve_hosts(uri: str) -> list[str]:
    """Resolve the SRV record to the underlying shard hostnames."""
    host = urlsplit(uri).hostname or ""
    if not uri.startswith("mongodb+srv://"):
        return [host]
    try:
        import dns.resolver

        answers = dns.resolver.resolve(f"_mongodb._tcp.{host}", "SRV")
        return [str(r.target).rstrip(".") for r in answers]
    except Exception as exc:
        print(f"  {CROSS} SRV lookup failed for {host}: {exc}")
        return []


def probe_tcp(host: str, port: int = 27017) -> bool:
    sock = socket.socket()
    sock.settimeout(8)
    try:
        sock.connect((host, port))
        print(f"  {TICK} {host}:{port} reachable")
        return True
    except Exception as exc:
        print(f"  {CROSS} {host}:{port} {type(exc).__name__}")
        return False
    finally:
        sock.close()


async def probe_auth(uri: str, db_name: str) -> bool:
    from motor.motor_asyncio import AsyncIOMotorClient

    client = AsyncIOMotorClient(uri, serverSelectionTimeoutMS=8000)
    try:
        info = await client.server_info()
        await client[db_name].command("ping")
        print(f"  {TICK} authenticated — MongoDB {info.get('version')}")
        return True
    except OperationFailure as exc:
        print(f"  {CROSS} authentication rejected: {exc.details.get('errmsg', exc)}")
        print("         -> the username or password is wrong")
        return False
    except PyMongoError as exc:
        print(f"  {CROSS} {type(exc).__name__}: {str(exc)[:160]}")
        return False
    finally:
        client.close()


async def main() -> int:
    settings = get_settings()
    uri = settings.MONGO_URI

    print("MongoDB connectivity check\n")
    print(f"  database : {settings.MONGO_DB_NAME}")
    print(f"  public IP: {public_ip()}   <- must be in Atlas Network Access\n")

    print("1. Resolving hosts")
    hosts = resolve_hosts(uri)
    for h in hosts:
        print(f"     {h}")
    if not hosts:
        return 1

    print("\n2. TCP reachability on 27017")
    reachable = any(probe_tcp(h) for h in hosts)
    if not reachable:
        print(
            f"\n  {WARN} No host accepted a TCP connection.\n"
            "        This happens BEFORE authentication, so the password is not at fault.\n"
            "        Most likely: outbound 27017 is blocked on this network, or your IP\n"
            "        is not on the Atlas allowlist. Try a mobile hotspot, or run MongoDB\n"
            "        locally with: docker run -d -p 27017:27017 mongo:8"
        )
        return 1

    print("\n3. Authentication")
    if not await probe_auth(uri, settings.MONGO_DB_NAME):
        return 1

    print("\nAll checks passed — the database is ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
