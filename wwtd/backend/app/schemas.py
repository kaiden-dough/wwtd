from datetime import datetime

from pydantic import BaseModel, Field


class ProfileOut(BaseModel):
    id: str
    email: str | None
    display_name: str | None
    avatar_url: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class AuthTokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    profile: ProfileOut


class SendCodeOut(BaseModel):
    message: str
    dev_code: str | None = None


class PersonCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)


class PersonOut(BaseModel):
    id: int
    name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class MarketCreate(BaseModel):
    person_name: str = Field(min_length=1, max_length=200)
    question: str = Field(min_length=1)
    date_label: str = Field(min_length=1, max_length=64)
    creator_side: str = Field(pattern="^(yes|no)$")
    creator_stake: float = Field(gt=0, le=1_000_000)


class MarketOut(BaseModel):
    id: str
    person_id: int
    person_name: str
    question: str
    date_label: str
    created_by: str
    status: str
    created_at: datetime
    yes_wagered_points: float
    no_wagered_points: float
    user_yes_bet: float = 0
    user_no_bet: float = 0


class BetCreate(BaseModel):
    side: str = Field(pattern="^(yes|no)$")
    amount: float = Field(gt=0, le=1_000_000)
