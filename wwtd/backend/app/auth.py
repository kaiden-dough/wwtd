from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import Profile
from app.tokens import decode_access_token

security = HTTPBearer(auto_error=False)


def _profile_from_token_payload(payload: dict, db: Session) -> Profile:
    sub = payload.get("sub")
    if not sub or not isinstance(sub, str):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid token subject")

    profile = db.get(Profile, sub)
    if profile is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return profile


def get_current_profile(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
    db: Annotated[Session, Depends(get_db)],
) -> Profile:
    if creds is None or creds.scheme.lower() != "bearer":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Bearer token required")
    try:
        payload = decode_access_token(creds.credentials)
    except ValueError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token") from exc
    return _profile_from_token_payload(payload, db)


def get_optional_profile(
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(security)],
    db: Annotated[Session, Depends(get_db)],
) -> Profile | None:
    if creds is None or creds.scheme.lower() != "bearer":
        return None
    try:
        payload = decode_access_token(creds.credentials)
    except ValueError:
        return None
    return _profile_from_token_payload(payload, db)
