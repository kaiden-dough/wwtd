from datetime import datetime

from pydantic import BaseModel, Field


class ProfileOut(BaseModel):
    id: str
    username: str | None
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
    wins: int = 0
    resolved_bets: int = 0
    win_rate: float = 0.0
    net_points: float = 0.0
    is_trending_up: bool = False


class RoomLeaderboardOut(BaseModel):
    room_id: str
    person_name: str
    person_names: list[str] = Field(default_factory=list)
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
    market_betting_open: bool = True
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
    person_name: str | None = Field(default=None, min_length=1, max_length=200)
    person_names: list[str] = Field(default_factory=list)
    room_type: str = Field(default="individual", pattern="^(individual|group)$")


class RoomJoin(BaseModel):
    join_code: str = Field(min_length=4, max_length=8)
    room_id: str | None = None


class RoomDiscoverOut(BaseModel):
    id: str
    person_name: str
    person_names: list[str] = Field(default_factory=list)
    room_type: str = "individual"
    moderator_name: str
    is_member: bool = False


class RoomOut(BaseModel):
    id: str
    join_code: str
    person_name: str
    person_names: list[str] = Field(default_factory=list)
    room_type: str = "individual"
    moderator_name: str
    is_moderator: bool = False
    balance_points: float
    created_at: datetime


class QuestionCreate(BaseModel):
    question: str = Field(min_length=1)
    target_names: list[str] = Field(default_factory=list)


class QuestionOut(BaseModel):
    id: str
    room_id: str
    join_code: str
    person_id: int
    person_name: str
    target_names: list[str] = Field(default_factory=list)
    question: str
    created_by: str
    is_moderator: bool = False
    status: str
    winning_side: str | None = None
    created_at: datetime
    betting_open: bool = True
    yes_wagered_points: float
    no_wagered_points: float
    user_yes_bet: float = 0
    user_no_bet: float = 0


class QuestionResolve(BaseModel):
    winning_side: str = Field(pattern="^(yes|no)$")


class BetCreate(BaseModel):
    side: str = Field(pattern="^(yes|no)$")
    amount: float = Field(gt=0, le=1_000_000)
