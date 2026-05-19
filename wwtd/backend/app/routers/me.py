from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, exists, select
from sqlalchemy.orm import Session

from app.auth import get_current_profile
from app.db import get_db
from app.models import Bet, Person, Profile, Question, Room, RoomMember
from app.question_betting import betting_open_for
from app.schemas import BetOut, ProfileOut, ProfileUpdate

router = APIRouter(prefix="/me", tags=["me"])


@router.get("", response_model=ProfileOut)
def read_me(profile: Annotated[Profile, Depends(get_current_profile)]) -> Profile:
    return profile


@router.patch("", response_model=ProfileOut)
def update_me(
    body: ProfileUpdate,
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[Session, Depends(get_db)],
) -> Profile:
    profile.display_name = body.display_name.strip()
    db.commit()
    db.refresh(profile)
    return profile


@router.get("/bets", response_model=list[BetOut])
def list_my_bets(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[Session, Depends(get_db)],
    room_id: str | None = None,
) -> list[BetOut]:
    if room_id is not None:
        is_member = db.scalar(
            select(
                exists().where(
                    and_(RoomMember.room_id == room_id, RoomMember.user_id == profile.id)
                )
            )
        )
        if not is_member:
            raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Not a member of this room")

    stmt = (
        select(Bet, Question, Room, Person)
        .join(Question, Bet.question_id == Question.id)
        .join(Room, Question.room_id == Room.id)
        .join(Person, Room.person_id == Person.id)
        .where(Bet.user_id == profile.id)
    )
    if room_id is not None:
        stmt = stmt.where(Room.id == room_id)
    rows = db.execute(stmt).all()

    def _bet_is_past(question: Question) -> bool:
        if question.status == "resolved":
            return True
        return not betting_open_for(status=question.status, created_at=question.created_at)

    rows = sorted(
        rows,
        key=lambda row: (1 if _bet_is_past(row[1]) else 0, -row[0].created_at.timestamp()),
    )
    return [
        BetOut(
            id=bet.id,
            room_id=room.id,
            market_id=question.id,
            market_question=question.question,
            person_name=person.name,
            side=bet.side,
            amount=float(bet.amount),
            payout_amount=float(bet.payout_amount) if bet.payout_amount is not None else None,
            market_status=question.status,
            winning_side=question.winning_side,
            market_betting_open=betting_open_for(
                status=question.status, created_at=question.created_at
            ),
            created_at=bet.created_at,
        )
        for bet, question, room, person in rows
    ]
