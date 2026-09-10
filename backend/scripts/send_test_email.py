"""Send one real email, to prove the SMTP configuration works.

    python -m scripts.send_test_email [recipient]

Reads `backend/.env` through the normal settings path. Prints the host, the
port and the sender — never the password. Exits non-zero on failure so the
result cannot be mistaken for success.
"""

import asyncio
import sys

from app.core.config import get_settings
from app.core.email import EmailError, EmailService


async def main() -> int:
    settings = get_settings()
    if not settings.email_configured:
        print("SMTP is not configured. Set SMTP_HOST and SMTP_FROM_EMAIL.")
        return 2

    recipient = sys.argv[1] if len(sys.argv) > 1 else settings.SMTP_FROM_EMAIL
    print(f"host={settings.SMTP_HOST}:{settings.SMTP_PORT} tls={settings.SMTP_USE_TLS}")
    print(f"from={settings.SMTP_FROM_EMAIL} to={recipient}")

    try:
        # The real login notification, not a special test-only message, so a
        # pass here means the production path works.
        await EmailService().send_login_notification(to=recipient, full_name="Test")
    except EmailError as exc:
        print(f"FAILED: {type(exc).__name__}: {exc}")
        return 1

    print("SENT — check the inbox.")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
