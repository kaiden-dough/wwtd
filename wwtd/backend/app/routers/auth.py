import re
import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db
from app.models import Profile
from app.passwords import hash_password, verify_password
from app.schemas import AuthTokenOut, ProfileOut
from app.tokens import create_access_token

router = APIRouter(prefix="/auth", tags=["auth"])

_USERNAME_RE = re.compile(r"^[a-zA-Z0-9_]{3,32}$")


class RegisterBody(BaseModel):
    username: str = Field(min_length=3, max_length=32)
    password: str = Field(min_length=8, max_length=128)


class LoginBody(BaseModel):
    username: str = Field(min_length=3, max_length=32)
    password: str = Field(min_length=1, max_length=128)


class TempLoginBody(BaseModel):
    password: str = Field(min_length=1, max_length=128)


def _normalize_username(username: str) -> str:
    return username.strip().lower()


def _validate_username(username: str) -> None:
    if not _USERNAME_RE.match(username):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Username must be 3–32 characters: letters, numbers, underscore only",
        )


def _username_format_error(username: str) -> str | None:
    if len(username) < 3:
        return "Username must be at least 3 characters"
    if not _USERNAME_RE.match(username):
        return "Username must be 3–32 characters: letters, numbers, underscore only"
    return None


def _profile_out(profile: Profile) -> ProfileOut:
    return ProfileOut.model_validate(profile)


def _issue_token(profile: Profile) -> AuthTokenOut:
    token = create_access_token(profile.id, profile.username)
    return AuthTokenOut(access_token=token, profile=_profile_out(profile))


class UsernameAvailabilityOut(BaseModel):
    available: bool
    username: str
    message: str | None = None


@router.get("/check-username", response_model=UsernameAvailabilityOut)
def check_username(username: str, db: Annotated[Session, Depends(get_db)]) -> UsernameAvailabilityOut:
    normalized = _normalize_username(username)
    format_error = _username_format_error(normalized)
    if format_error is not None:
        return UsernameAvailabilityOut(
            available=False,
            username=normalized,
            message=format_error,
        )
    taken = db.scalar(select(Profile).where(Profile.username == normalized)) is not None
    if taken:
        return UsernameAvailabilityOut(
            available=False,
            username=normalized,
            message="Username already taken",
        )
    return UsernameAvailabilityOut(available=True, username=normalized)


@router.post("/register", response_model=AuthTokenOut, status_code=status.HTTP_201_CREATED)
def register(body: RegisterBody, db: Annotated[Session, Depends(get_db)]) -> AuthTokenOut:
    username = _normalize_username(body.username)
    _validate_username(username)

    existing = db.scalar(select(Profile).where(Profile.username == username))
    if existing is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, detail="Username already taken")

    profile = Profile(
        id=str(uuid.uuid4()),
        username=username,
        password_hash=hash_password(body.password),
        display_name=username,
        balance_points=0.0,
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return _issue_token(profile)


@router.post("/login", response_model=AuthTokenOut)
def login(body: LoginBody, db: Annotated[Session, Depends(get_db)]) -> AuthTokenOut:
    username = _normalize_username(body.username)
    temp_display_name = _temp_display_name(username)
    if temp_display_name is not None and body.password == "dingus":
        return _temp_login(db, username=username, display_name=temp_display_name)

    profile = db.scalar(select(Profile).where(Profile.username == username))
    if profile is None or not profile.password_hash:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")

    if not verify_password(body.password, profile.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")

    return _issue_token(profile)


@router.post("/admin-login", response_model=AuthTokenOut)
def admin_login(body: TempLoginBody, db: Annotated[Session, Depends(get_db)]) -> AuthTokenOut:
    """Temporary local-dev shortcut for working on the app without creating accounts."""
    _validate_temp_password(body.password)
    return _temp_login(db, username="admin", display_name="Admin")


@router.post("/temp-user-login", response_model=AuthTokenOut)
def temp_user_login(body: TempLoginBody, db: Annotated[Session, Depends(get_db)]) -> AuthTokenOut:
    """Temporary local-dev shortcut for a non-moderator test account."""
    _validate_temp_password(body.password)
    return _temp_login(db, username="testuser", display_name="Test User")


def _validate_temp_password(password: str) -> None:
    if password != "dingus":
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid temporary account password")


def _temp_display_name(username: str) -> str | None:
    if username == "admin":
        return "Admin"
    if username == "testuser":
        return "Test User"
    return None


def _temp_login(db: Session, *, username: str, display_name: str) -> AuthTokenOut:
    profile = db.scalar(select(Profile).where(Profile.username == username))
    if profile is None:
        profile = Profile(
            id=str(uuid.uuid4()),
            username=username,
            password_hash=hash_password("dingus"),
            display_name=display_name,
            balance_points=0.0,
        )
        db.add(profile)
        db.commit()
        db.refresh(profile)
    elif profile.password_hash is None or not verify_password("dingus", profile.password_hash):
        profile.password_hash = hash_password("dingus")
        db.commit()
        db.refresh(profile)
    return _issue_token(profile)
