import logging
import smtplib
from email.message import EmailMessage

from app.config import settings

logger = logging.getLogger(__name__)


def _smtp_configured() -> bool:
    return bool(settings.smtp_host.strip() and settings.smtp_from.strip())


def send_login_code(email: str, code: str) -> bool:
    """Send code by email. Returns True if sent via SMTP, False if dev/log-only."""
    if not _smtp_configured():
        logger.warning("SMTP not configured — login code for %s: %s", email, code)
        print(f"[wwtd] Login code for {email}: {code}", flush=True)
        return False

    message = EmailMessage()
    message["Subject"] = "Your wwtd login code"
    message["From"] = settings.smtp_from.strip()
    message["To"] = email
    message.set_content(
        f"Your login code is: {code}\n\n"
        f"It expires in {settings.otp_expire_minutes} minutes.\n\n"
        "If you didn't request this, you can ignore this email."
    )

    with smtplib.SMTP(settings.smtp_host.strip(), settings.smtp_port, timeout=30) as smtp:
        if settings.smtp_use_tls:
            smtp.starttls()
        user = settings.smtp_user.strip()
        password = settings.smtp_password
        if user:
            smtp.login(user, password)
        smtp.send_message(message)

    logger.info("Login code emailed to %s", email)
    return True
