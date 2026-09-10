"""Outbound email.

One module owns everything about sending mail, for the same reason
`security.py` owns everything about cryptography: "how does FoodLoop send an
email?" should be a question with a single place to look, and swapping SMTP for
a hosted API later should not touch a line of authentication code.

The seam is [EmailSender]. `AuthService` never sees it — it calls the three
named methods on [EmailService], which describe *what* is being sent rather
than how. Nothing here logs a code, a password, or an SMTP credential.
"""

from __future__ import annotations

import asyncio
import logging
import smtplib
from dataclasses import dataclass
from email.message import EmailMessage as MimeMessage
from email.utils import formataddr, formatdate, make_msgid
from typing import Protocol

from app.core.config import Settings, get_settings

logger = logging.getLogger(__name__)


class EmailError(Exception):
    """Base for every mail failure. Never surfaced verbatim to a client."""


class EmailNotConfiguredError(EmailError):
    """No SMTP host or sender address is set.

    Deliberately distinct from a delivery failure: one is an operator's
    misconfiguration and the other is a transient network problem, and the
    caller genuinely needs to tell them apart.
    """


class EmailDeliveryError(EmailError):
    """The message could not be handed to the SMTP server."""


@dataclass(frozen=True, slots=True)
class OutgoingEmail:
    """A message ready to send. Plain text only — no tracking, no remote images."""

    to: str
    subject: str
    body: str


class EmailSender(Protocol):
    """The provider seam.

    Implementations do exactly one thing: deliver a message, or raise. They
    know nothing about verification codes, accounts or authentication.
    """

    async def send(self, message: OutgoingEmail) -> None: ...


class SmtpEmailSender:
    """Delivers over SMTP with STARTTLS.

    `smtplib` is synchronous, so each send runs in a worker thread under a
    hard timeout. A mail server that stops responding must not be able to hold
    an API request open — the login notification in particular is attached to
    a request that has already succeeded.
    """

    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or get_settings()

    async def send(self, message: OutgoingEmail) -> None:
        settings = self._settings
        if not settings.email_configured:
            raise EmailNotConfiguredError(
                "SMTP is not configured on this server."
            )

        mime = self._build(message)
        try:
            await asyncio.wait_for(
                asyncio.to_thread(self._deliver, mime, message.to),
                timeout=settings.SMTP_TIMEOUT_SECONDS,
            )
        except TimeoutError as exc:
            raise EmailDeliveryError("The mail server did not respond.") from exc
        except (smtplib.SMTPException, OSError) as exc:
            # The exception text can name the server and the credentials it
            # rejected, so it is logged by *type* only and never returned.
            logger.warning(
                "SMTP delivery failed (%s)", type(exc).__name__
            )
            raise EmailDeliveryError("The email could not be sent.") from exc

    def _build(self, message: OutgoingEmail) -> MimeMessage:
        settings = self._settings
        mime = MimeMessage()
        mime["From"] = formataddr(
            (settings.SMTP_FROM_NAME, settings.SMTP_FROM_EMAIL)
        )
        mime["To"] = message.to
        mime["Subject"] = message.subject
        mime["Date"] = formatdate(localtime=True)
        # Without a Message-ID many providers score the mail as spam, and a
        # verification code in a spam folder is a broken sign-up.
        mime["Message-ID"] = make_msgid(domain=_domain_of(settings.SMTP_FROM_EMAIL))
        mime["Auto-Submitted"] = "auto-generated"
        mime.set_content(message.body)
        return mime

    def _deliver(self, mime: MimeMessage, recipient: str) -> None:
        """Runs on a worker thread. Blocking, by nature of `smtplib`."""
        settings = self._settings
        with smtplib.SMTP(
            settings.SMTP_HOST,
            settings.SMTP_PORT,
            timeout=settings.SMTP_TIMEOUT_SECONDS,
        ) as client:
            client.ehlo()
            if settings.SMTP_USE_TLS:
                client.starttls()
                client.ehlo()
            if settings.SMTP_USERNAME:
                client.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            client.send_message(mime, to_addrs=[recipient])


def _domain_of(address: str) -> str:
    _, _, domain = address.partition("@")
    return domain or "foodloop.local"


class EmailService:
    """What FoodLoop sends, expressed in the language of the product.

    Every method takes only what belongs in an email. A code is passed in and
    used once, in the body; it is never stored, never returned, and never
    logged — the log lines here record the *kind* of message and nothing else,
    because "verification code sent to a@b.com: 481920" in a log file is the
    same leak as storing it in plaintext.
    """

    def __init__(
        self,
        sender: EmailSender | None = None,
        settings: Settings | None = None,
    ) -> None:
        self._settings = settings or get_settings()
        self._sender = sender or SmtpEmailSender(self._settings)

    @property
    def configured(self) -> bool:
        return self._settings.email_configured

    async def send_verification_otp(
        self, *, to: str, full_name: str, code: str
    ) -> None:
        minutes = self._settings.OTP_EXPIRE_MINUTES
        await self._send(
            to,
            "Verify your FoodLoop email",
            f"""Hi {_first_name(full_name)},

Welcome to FoodLoop. Use this code to verify your email address:

    {code}

It expires in {minutes} minutes and can be used once.

If you did not create a FoodLoop account, you can ignore this email.

— The FoodLoop team
""",
            kind="verification",
        )

    async def send_password_reset_otp(
        self, *, to: str, full_name: str, code: str
    ) -> None:
        minutes = self._settings.OTP_EXPIRE_MINUTES
        await self._send(
            to,
            "Reset your FoodLoop password",
            f"""Hi {_first_name(full_name)},

Use this code to set a new FoodLoop password:

    {code}

It expires in {minutes} minutes and can be used once.

If you did not ask to reset your password, ignore this email — your password
has not changed, and nobody can change it without this code.

— The FoodLoop team
""",
            kind="password reset",
        )

    async def send_login_notification(self, *, to: str, full_name: str) -> None:
        """Confirms a successful sign-in.

        Deliberately claims nothing about device, location or IP address: the
        backend does not collect any of them, and inventing "signed in from
        Chennai" would be worse than saying nothing — it trains people to
        ignore the one signal that should alarm them.
        """
        await self._send(
            to,
            "You signed in to FoodLoop",
            f"""Hi {_first_name(full_name)},

Welcome back. You successfully signed in to your FoodLoop account.

If this was not you, change your password straight away using
"Forgot password" on the sign-in screen.

— The FoodLoop team
""",
            kind="login notification",
        )

    async def _send(self, to: str, subject: str, body: str, *, kind: str) -> None:
        await self._sender.send(OutgoingEmail(to=to, subject=subject, body=body))
        # Recipient and kind only. No code, ever.
        logger.info("Sent %s email to %s", kind, _redact(to))


def _first_name(full_name: str) -> str:
    first = full_name.strip().split(" ")[0] if full_name.strip() else ""
    return first or "there"


def _redact(address: str) -> str:
    """`asha@example.com` -> `a***@example.com`, for log lines."""
    local, _, domain = address.partition("@")
    if not domain:
        return "***"
    return f"{local[:1]}***@{domain}"


def get_email_service() -> EmailService:
    """FastAPI dependency. Tests override this with a recording double."""
    return EmailService()
