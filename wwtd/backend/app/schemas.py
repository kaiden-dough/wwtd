from datetime import datetime

from pydantic import BaseModel, Field


class ProfileOut(BaseModel):
    id: str
    email: str | None
    display_name: str | None
    avatar_url: str | None
    balance_points: float
    created_at: datetime

    model_config = {"from_attributes": True}


class ProfileUpdate(BaseModel):
    display_name: str = Field(min_length=1, max_length=200)


class LeaderboardEntryOut(BaseModel):
    user_id: str
    display_name: str
    net_points: float
    win_rate: float = 0.0
    is_trending_up: bool = True


class RoomLeaderboardOut(BaseModel):
    room_id: str
    person_name: str
    entries: list[LeaderboardEntryOut]


class BetOut(BaseModel):
    id: int
    room_id: str
    market_id: str
    market_question: str
    person_name: str
    side: str
    amount: float
    payout_amount: float | None
    market_status: str
    winning_side: str | None
    created_at: datetime


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


class RoomCreate(BaseModel):
    person_name: str = Field(min_length=1, max_length=200)


class RoomJoin(BaseModel):
    join_code: str = Field(min_length=4, max_length=8)


class RoomOut(BaseModel):
    id: str
    join_code: str
    person_name: str
    is_moderator: bool = False
    created_at: datetime


class QuestionCreate(BaseModel):
    question: str = Field(min_length=1)


class QuestionOut(BaseModel):
    id: str
    room_id: str
    join_code: str
    person_id: int
    person_name: str
    question: str
    created_by: str
    is_moderator: bool = False
    status: str
    winning_side: str | None = None
    created_at: datetime
    yes_wagered_points: float
    no_wagered_points: float
    user_yes_bet: float = 0
    user_no_bet: float = 0


class QuestionResolve(BaseModel):
    winning_side: str = Field(pattern="^(yes|no)$")


class BetCreate(BaseModel):
    side: str = Field(pattern="^(yes|no)$")
    amount: float = Field(gt=0, le=1_000_000)
