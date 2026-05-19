import json
import logging
import re
import smtplib
import urllib.error
import urllib.request
from email.message import EmailMessage

from app.config import settings

logger = logging.getLogger(__name__)

_SENDER_RE = re.compile(r"^(.*?)\s*<([^>]+)>$")


def _login_email_body(code: str) -> str:
    return (
        f"Your login code is: {code}\n\n"
        f"It expires in {settings.otp_expire_minutes} minutes.\n\n"
        "If you didn't request this, you can ignore this email."
    )


def _sender_name_and_email() -> tuple[str, str]:
    raw = (
        settings.email_from.strip()
        or settings.smtp_from.strip()
        or settings.brevo_sender_email.strip()
    )
    if not raw:
        raise ValueError("Set EMAIL_FROM to a verified Brevo sender, e.g. you@gmail.com")

    match = _SENDER_RE.match(raw)
    if match:
        name = match.group(1).strip() or settings.brevo_sender_name
        return name, match.group(2).strip()

    if "@" in raw:
        return settings.brevo_sender_name, raw

    raise ValueError(f"Invalid EMAIL_FROM format: {raw!r}")


def _brevo_configured() -> bool:
    return bool(settings.brevo_api_key.strip())


def _resend_configured() -> bool:
    return bool(settings.resend_api_key.strip())


def _smtp_configured() -> bool:
    return bool(settings.smtp_host.strip() and settings.smtp_from.strip())


def _send_via_brevo(email: str, code: str) -> bool:
    name, sender_email = _sender_name_and_email()
    payload = {
        "sender": {"name": name, "email": sender_email},
        "to": [{"email": email}],
        "subject": "Your wwtd login code",
        "textContent": _login_email_body(code),
    }
    request = urllib.request.Request(
        "https://api.brevo.com/v3/smtp/email",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "api-key": settings.brevo_api_key.strip(),
            "Content-Type": "application/json",
            "accept": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            if 200 <= response.status < 300:
                logger.info("Login code sent via Brevo to %s", email)
                return True
            body = response.read().decode(errors="replace")
            raise RuntimeError(f"Brevo unexpected status {response.status}: {body}")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise RuntimeError(f"Brevo failed ({exc.code}): {body}") from exc


def _send_via_resend(email: str, code: str) -> bool:
    from_addr = settings.email_from.strip() or settings.smtp_from.strip() or "onboarding@resend.dev"
    payload = {
        "from": from_addr,
        "to": [email],
        "subject": "Your wwtd login code",
        "text": _login_email_body(code),
    }
    request = urllib.request.Request(
        "https://api.resend.com/emails",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {settings.resend_api_key.strip()}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            if 200 <= response.status < 300:
                logger.info("Login code sent via Resend to %s", email)
                return True
            body = response.read().decode(errors="replace")
            raise RuntimeError(f"Resend unexpected status {response.status}: {body}")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        raise RuntimeError(f"Resend failed ({exc.code}): {body}") from exc


def _send_via_smtp(email: str, code: str) -> bool:
    message = EmailMessage()
    message["Subject"] = "Your wwtd login code"
    message["From"] = settings.smtp_from.strip()
    message["To"] = email
    message.set_content(_login_email_body(code))

    with smtplib.SMTP(settings.smtp_host.strip(), settings.smtp_port, timeout=30) as smtp:
        if settings.smtp_use_tls:
            smtp.starttls()
        user = settings.smtp_user.strip()
        password = settings.smtp_password
        if user:
            smtp.login(user, password)
        smtp.send_message(message)

    logger.info("Login code emailed via SMTP to %s", email)
    return True


def send_login_code(email: str, code: str) -> bool:
    """Send login code. Prefer Brevo/Resend HTTPS on Render (SMTP port 587 is blocked there)."""
    if _brevo_configured():
        _send_via_brevo(email, code)
        return True

    if _resend_configured():
        _send_via_resend(email, code)
        return True

    if _smtp_configured():
        _send_via_smtp(email, code)
        return True

    logger.warning("Email not configured — login code for %s: %s", email, code)
    print(f"[wwtd] Login code for {email}: {code}", flush=True)
    return False
