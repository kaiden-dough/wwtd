import hashlib
import logging
import secrets
import uuid
from datetime import UTC, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import select
from sqlalchemy.orm import Session
from typing import Annotated

from app.config import settings
from app.db import get_db
from app.email_service import send_login_code
from app.models import LoginCode, Profile
from app.schemas import AuthTokenOut, ProfileOut, SendCodeOut
from app.tokens import create_access_token

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["auth"])


class SendCodeBody(BaseModel):
    email: EmailStr


class VerifyCodeBody(BaseModel):
    email: EmailStr
    code: str = Field(min_length=6, max_length=6, pattern=r"^\d{6}$")


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


def _generate_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _utc_now() -> datetime:
    return datetime.now(UTC)


def _as_utc_aware(value: datetime) -> datetime:
    """SQLite often returns naive datetimes; treat them as UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)


@router.post("/send-code", response_model=SendCodeOut)
def send_code(body: SendCodeBody, db: Annotated[Session, Depends(get_db)]) -> SendCodeOut:
    email = _normalize_email(str(body.email))
    code = _generate_code()
    expires_at = _utc_now() + timedelta(minutes=settings.otp_expire_minutes)

    row = db.get(LoginCode, email)
    if row is None:
        row = LoginCode(email=email, code_hash=_hash_code(code), expires_at=expires_at, attempts=0)
        db.add(row)
    else:
        row.code_hash = _hash_code(code)
        row.expires_at = expires_at
        row.attempts = 0

    db.commit()

    emailed = False
    smtp_error: str | None = None
    try:
        emailed = send_login_code(email, code)
    except Exception as exc:
        logger.exception("Failed to send login email to %s", email)
        smtp_error = str(exc)
        print(f"[wwtd] SMTP failed for {email}; dev code: {code}", flush=True)

    dev_code = None
    if not emailed and settings.expose_dev_otp:
        dev_code = code

    if emailed:
        message = "Check your email for the 6-digit code."
    elif smtp_error:
        message = "Email failed — use the dev code below. Fix SMTP in backend .env (Gmail: App Password)."
    else:
        message = "Email is not configured — use the dev code below."

    return SendCodeOut(message=message, dev_code=dev_code)


@router.post("/verify-code", response_model=AuthTokenOut)
def verify_code(body: VerifyCodeBody, db: Annotated[Session, Depends(get_db)]) -> AuthTokenOut:
    email = _normalize_email(str(body.email))
    row = db.get(LoginCode, email)
    if row is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="No code sent for this email")

    if _as_utc_aware(row.expires_at) < _utc_now():
        db.delete(row)
        db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Code expired — request a new one")

    if row.attempts >= settings.otp_max_attempts:
        db.delete(row)
        db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Too many attempts — request a new code")

    if row.code_hash != _hash_code(body.code):
        row.attempts += 1
        db.commit()
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Invalid code")

    db.delete(row)

    profile = db.scalar(select(Profile).where(Profile.email == email))
    if profile is None:
        local_part = email.split("@", 1)[0]
        profile = Profile(
            id=str(uuid.uuid4()),
            email=email,
            display_name=local_part,
        )
        db.add(profile)
    db.commit()
    db.refresh(profile)

    token = create_access_token(profile.id, email)
    return AuthTokenOut(
        access_token=token,
        profile=ProfileOut.model_validate(profile),
    )
