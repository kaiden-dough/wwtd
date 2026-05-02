from typing import Annotated

from fastapi import APIRouter, Depends

from app.auth import get_current_profile
from app.models import Profile
from app.schemas import ProfileOut

router = APIRouter(prefix="/me", tags=["me"])


@router.get("", response_model=ProfileOut)
def read_me(profile: Annotated[Profile, Depends(get_current_profile)]) -> Profile:
    return profile
