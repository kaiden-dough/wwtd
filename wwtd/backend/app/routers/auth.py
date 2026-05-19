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


def _normalize_username(username: str) -> str:
    return username.strip().lower()


def _validate_username(username: str) -> None:
    if not _USERNAME_RE.match(username):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Username must be 3–32 characters: letters, numbers, underscore only",
        )


def _profile_out(profile: Profile) -> ProfileOut:
    return ProfileOut.model_validate(profile)


def _issue_token(profile: Profile) -> AuthTokenOut:
    token = create_access_token(profile.id, profile.username)
    return AuthTokenOut(access_token=token, profile=_profile_out(profile))


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
        balance_points=float(settings.starting_balance_points),
    )
    db.add(profile)
    db.commit()
    db.refresh(profile)
    return _issue_token(profile)


@router.post("/login", response_model=AuthTokenOut)
def login(body: LoginBody, db: Annotated[Session, Depends(get_db)]) -> AuthTokenOut:
    username = _normalize_username(body.username)
    profile = db.scalar(select(Profile).where(Profile.username == username))
    if profile is None or not profile.password_hash:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")

    if not verify_password(body.password, profile.password_hash):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid username or password")

    return _issue_token(profile)
