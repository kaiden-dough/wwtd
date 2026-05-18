from datetime import UTC, datetime, timedelta

import jwt
from jwt.exceptions import PyJWTError

from app.config import settings


def create_access_token(user_id: str, email: str | None) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": user_id,
        "email": email,
        "iat": now,
        "exp": now + timedelta(days=settings.jwt_expire_days),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_access_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except PyJWTError as exc:
        raise ValueError("Invalid or expired token") from exc
