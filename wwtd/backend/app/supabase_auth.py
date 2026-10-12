"""Verify Google sessions with the configured Supabase Auth server."""
import json
import uuid
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from app.config import settings
from app.models import Profile, GoogleIdentity


def verify_google_session(token):
    if not settings.supabase_url.startswith("https://") or not settings.supabase_publishable_key:
        raise HTTPException(503, "Google sign-in is not configured")
    request = Request(settings.supabase_url.rstrip("/") + "/auth/v1/user",
        headers={"apikey": settings.supabase_publishable_key, "Authorization": "Bearer " + token})
    try:
        with urlopen(request, timeout=10) as response:
            user = json.load(response)
    except HTTPError as exc:
        raise HTTPException(401 if exc.code in (401, 403) else 503, "Could not verify Google session") from exc
    except (URLError, TimeoutError, ValueError) as exc:
        raise HTTPException(503, "Google sign-in is temporarily unavailable") from exc
    if not isinstance(user, dict) or not user.get("email_confirmed_at") or not user.get("email"):
        raise HTTPException(401, "A verified email is required")
    if not any(i.get("provider") == "google" for i in (user.get("identities") or [])):
        raise HTTPException(403, "Please sign in with Google")
    try:
        subject = str(uuid.UUID(user["id"]))
    except (KeyError, ValueError, TypeError) as exc:
        raise HTTPException(401, "Invalid user identity") from exc
    user["id"] = subject
    return user


def google_profile(token, db):
    user = verify_google_session(token)
    subject = user["id"]
    identity = db.get(GoogleIdentity, subject)
    if identity is not None:
        return db.get(Profile, identity.profile_id)
    profile = db.get(Profile, subject)
    if profile is not None:
        return profile
    # Never silently attach a Google identity to an existing password account.
    if db.scalar(select(Profile).where(Profile.email == user["email"])) is not None:
        raise HTTPException(409, "This email belongs to an existing account; sign in with that account")
    metadata = user.get("user_metadata") or {}
    profile = Profile(id=subject, email=user["email"],
        display_name=str(metadata.get("full_name") or user["email"].split("@")[0])[:200],
        balance_points=0.0)
    db.add(profile)
    try:
        db.flush()
        db.add(GoogleIdentity(supabase_user_id=subject, profile_id=profile.id))
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        profile = db.get(Profile, subject)
        if profile is None:
            raise HTTPException(409, "Account already exists") from exc
    return profile


def link_google(token, profile, db):
    user = verify_google_session(token)
    identity = db.get(GoogleIdentity, user["id"])
    if identity is not None:
        if identity.profile_id != profile.id:
            raise HTTPException(409, "Google account already belongs to another player")
        return profile
    if db.scalar(select(GoogleIdentity).where(GoogleIdentity.profile_id == profile.id)):
        raise HTTPException(409, "Player already has a linked Google account")
    db.add(GoogleIdentity(supabase_user_id=user["id"], profile_id=profile.id))
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(409, "Google account is already linked") from exc
    return profile
