from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jwt.exceptions import PyJWTError
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db
from app.models import Profile

security = HTTPBearer(auto_error=False)


def decode_supabase_jwt(token: str) -> dict:
    if not settings.supabase_jwt_secret:
        raise HTTPException(
            status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Server is not configured with SUPABASE_JWT_SECRET",
        )
    options: dict = {}
    kwargs: dict = {"algorithms": ["HS256"]}
    aud = settings.supabase_jwt_audience.strip()
    if aud:
        kwargs["audience"] = aud
    else:
        options["verify_aud"] = False
    try:
        return jwt.decode(token, settings.supabase_jwt_secret, options=options, **kwargs)
    except PyJWTError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token") from exc


def _upsert_profile_from_payload(payload: dict, db: Session) -> Profile:
    sub = payload.get("sub")
    if not sub or not isinstance(sub, str):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid token subject")

    email = payload.get("email")
    if not isinstance(email, str):
        email = None

    meta = payload.get("user_metadata") or {}
    if not isinstance(meta, dict):
        meta = {}
    display = meta.get("full_name") or meta.get("name")
    if not isinstance(display, str):
        display = email
    avatar = meta.get("avatar_url")
    if not isinstance(avatar, str):
        avatar = None

    profile = db.get(Profile, sub)
    if profile is None:
        profile = Profile(id=sub, email=email, display_name=display, avatar_url=avatar)
        db.add(profile)
        db.commit()
        db.refresh(profile)
        return profile

    changed = False
    if email and profile.email != email:
        profile.email = email
        changed = True
    if display and profile.display_name != display:
        profile.display_name = display
        changed = True
    if avatar and profile.avatar_url != avatar:
        profile.avatar_url = avatar
        changed = True
    if changed:
        db.commit()
        db.refresh(profile)
    return profile


def get_current_profile(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
    db: Annotated[Session, Depends(get_db)],
) -> Profile:
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Bearer token required")
    payload = decode_supabase_jwt(creds.credentials)
    return _upsert_profile_from_payload(payload, db)


def get_optional_profile(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
    db: Annotated[Session, Depends(get_db)],
) -> Profile | None:
    if creds is None or creds.scheme.lower() != "bearer":
        return None
    payload = decode_supabase_jwt(creds.credentials)
    return _upsert_profile_from_payload(payload, db)
