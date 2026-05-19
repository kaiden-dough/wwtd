from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, case, exists, func, select
from sqlalchemy.orm import Session

from app.auth import get_current_profile
from app.db import get_db
from app.market_codes import generate_join_code
from app.models import Bet, Person, Profile, Question, Room, RoomMember
from app.payouts import resolve_question
from app.question_betting import betting_open_for, is_betting_open
from app.refunds import refund_question_bets
from app.schemas import BetCreate, QuestionCreate, QuestionOut, QuestionResolve, RoomCreate, RoomJoin, RoomOut

router = APIRouter(tags=["rooms"])


def _deduct_balance(profile: Profile, amount: float) -> None:
    if profile.balance_points < amount:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient balance ({profile.balance_points:.0f} points available)",
        )
    profile.balance_points -= amount


def _get_or_create_person(db: Session, name: str) -> Person:
    normalized = name.strip()
    person = db.scalar(select(Person).where(Person.name == normalized))
    if person:
        return person
    person = Person(name=normalized)
    db.add(person)
    db.flush()
    return person


def _is_member(db: Session, room_id: str, user_id: str) -> bool:
    stmt = select(exists().where(and_(RoomMember.room_id == room_id, RoomMember.user_id == user_id)))
    return bool(db.scalar(stmt))


def _require_member(db: Session, room: Room, profile: Profile) -> None:
    if not _is_member(db, room.id, profile.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Join this room with its code first")


def _add_member(db: Session, room_id: str, user_id: str) -> None:
    if _is_member(db, room_id, user_id):
        return
    db.add(RoomMember(room_id=room_id, user_id=user_id))


def _is_moderator(room: Room, profile: Profile) -> bool:
    return room.created_by == profile.id


def _run_questions_query(
    db: Session,
    *,
    room_id: str | None,
    question_id: str | None,
    current: Profile,
) -> list[QuestionOut]:
    yes_sum = func.coalesce(func.sum(case((Bet.side == "yes", Bet.amount), else_=0)), 0.0)
    no_sum = func.coalesce(func.sum(case((Bet.side == "no", Bet.amount), else_=0)), 0.0)
    uid = current.id

    stmt = (
        select(
            Question.id,
            Question.room_id,
            Room.join_code,
            Room.person_id,
            Person.name.label("person_name"),
            Question.question,
            Question.created_by,
            Question.status,
            Question.winning_side,
            Question.created_at,
            Room.created_by.label("moderator_id"),
            yes_sum.label("yes_total"),
            no_sum.label("no_total"),
            func.coalesce(
                func.sum(case((and_(Bet.side == "yes", Bet.user_id == uid), Bet.amount), else_=0)),
                0.0,
            ).label("user_yes"),
            func.coalesce(
                func.sum(case((and_(Bet.side == "no", Bet.user_id == uid), Bet.amount), else_=0)),
                0.0,
            ).label("user_no"),
        )
        .join(Room, Question.room_id == Room.id)
        .join(Person, Room.person_id == Person.id)
        .join(RoomMember, RoomMember.room_id == Room.id)
        .outerjoin(Bet, Bet.question_id == Question.id)
        .where(RoomMember.user_id == uid)
        .group_by(
            Question.id,
            Question.room_id,
            Room.join_code,
            Room.person_id,
            Person.name,
            Question.question,
            Question.created_by,
            Question.status,
            Question.winning_side,
            Question.created_at,
            Room.created_by,
        )
    )
    if room_id is not None:
        stmt = stmt.where(Question.room_id == room_id)
    if question_id is not None:
        stmt = stmt.where(Question.id == question_id)

    rows = db.execute(stmt).all()
    questions = [
        QuestionOut(
            id=m.id,
            room_id=m.room_id,
            join_code=m.join_code,
            person_id=m.person_id,
            person_name=m.person_name,
            question=m.question,
            created_by=m.created_by,
            is_moderator=m.moderator_id == current.id,
            status=m.status,
            winning_side=m.winning_side,
            created_at=m.created_at,
            betting_open=betting_open_for(status=m.status, created_at=m.created_at),
            yes_wagered_points=float(m.yes_total or 0),
            no_wagered_points=float(m.no_total or 0),
            user_yes_bet=float(m.user_yes or 0),
            user_no_bet=float(m.user_no or 0),
        )
        for m in rows
    ]
    questions.sort(
        key=lambda q: (
            1 if (q.status == "resolved" or not q.betting_open) else 0,
            -q.created_at.timestamp(),
        )
    )
    return questions


def _room_out(room: Room, person: Person, profile: Profile) -> RoomOut:
    return RoomOut(
        id=room.id,
        join_code=room.join_code,
        person_name=person.name,
        is_moderator=_is_moderator(room, profile),
        created_at=room.created_at,
    )


@router.get("/rooms", response_model=list[RoomOut])
def list_my_rooms(
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> list[RoomOut]:
    stmt = (
        select(Room, Person)
        .join(RoomMember, RoomMember.room_id == Room.id)
        .join(Person, Room.person_id == Person.id)
        .where(RoomMember.user_id == profile.id)
        .order_by(Room.created_at.desc())
    )
    rows = db.execute(stmt).all()
    return [_room_out(room, person, profile) for room, person in rows]


@router.post("/rooms", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
def create_room(
    body: RoomCreate,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> RoomOut:
    person = _get_or_create_person(db, body.person_name)
    room = Room(
        join_code=generate_join_code(db),
        person_id=person.id,
        created_by=profile.id,
    )
    db.add(room)
    db.flush()
    _add_member(db, room.id, profile.id)
    db.commit()
    db.refresh(room)
    return _room_out(room, person, profile)


@router.post("/rooms/join", response_model=RoomOut)
def join_room(
    body: RoomJoin,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> RoomOut:
    code = body.join_code.strip().upper()
    row = db.execute(
        select(Room, Person).join(Person, Room.person_id == Person.id).where(Room.join_code == code)
    ).first()
    if row is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Invalid join code")
    room, person = row
    _add_member(db, room.id, profile.id)
    db.commit()
    return _room_out(room, person, profile)


@router.get("/rooms/{room_id}/questions", response_model=list[QuestionOut])
def list_room_questions(
    room_id: str,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> list[QuestionOut]:
    if not _is_member(db, room_id, profile.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="You are not in this room")
    return _run_questions_query(db, room_id=room_id, question_id=None, current=profile)


@router.post("/rooms/{room_id}/questions", response_model=QuestionOut, status_code=status.HTTP_201_CREATED)
def add_question(
    room_id: str,
    body: QuestionCreate,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> QuestionOut:
    room = db.get(Room, room_id)
    if room is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Room not found")
    _require_member(db, room, profile)

    question = Question(
        room_id=room.id,
        question=body.question.strip(),
        created_by=profile.id,
        status="open",
    )
    db.add(question)
    db.commit()

    rows = _run_questions_query(db, room_id=room_id, question_id=question.id, current=profile)
    if not rows:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not create question")
    return rows[0]


@router.delete("/rooms/{room_id}/questions/{question_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_question(
    room_id: str,
    question_id: str,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> None:
    room = db.get(Room, room_id)
    if room is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Room not found")
    if not _is_moderator(room, profile):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Only the moderator can delete questions")

    question = db.get(Question, question_id)
    if question is None or question.room_id != room.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Question not found")

    refund_question_bets(db, question)
    db.delete(question)
    db.commit()


# Legacy /markets paths (question id = market id for clients)
markets_router = APIRouter(prefix="/markets", tags=["markets"])


@markets_router.get("", response_model=list[QuestionOut])
def list_all_questions(
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> list[QuestionOut]:
    return _run_questions_query(db, room_id=None, question_id=None, current=profile)


@markets_router.post("/join", response_model=RoomOut)
def join_room_via_markets(
    body: RoomJoin,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> RoomOut:
    return join_room(body, db, profile)


@markets_router.post("/{question_id}/bets", response_model=QuestionOut)
def place_bet(
    question_id: str,
    body: BetCreate,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> QuestionOut:
    question = db.get(Question, question_id)
    if question is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Question not found")
    room = db.get(Room, question.room_id)
    if room is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Room not found")
    _require_member(db, room, profile)
    if question.status != "open":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Question is not open for betting")
    if not is_betting_open(question):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Betting is closed (24 hours have passed or question was resolved)",
        )

    amount = float(body.amount)
    _deduct_balance(profile, amount)
    db.add(
        Bet(
            question_id=question.id,
            user_id=profile.id,
            side=body.side.lower(),
            amount=amount,
        )
    )
    db.commit()
    db.refresh(profile)

    rows = _run_questions_query(db, room_id=None, question_id=question.id, current=profile)
    if not rows:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Bet failed")
    return rows[0]


@markets_router.post("/{question_id}/resolve", response_model=QuestionOut)
def resolve_question_endpoint(
    question_id: str,
    body: QuestionResolve,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> QuestionOut:
    question = db.get(Question, question_id)
    if question is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Question not found")
    room = db.get(Room, question.room_id)
    if room is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Room not found")
    if not _is_moderator(room, profile):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Only the moderator can resolve questions")
    if question.status != "open":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Question is already resolved")

    resolve_question(db, question, body.winning_side.lower())
    db.commit()

    rows = _run_questions_query(db, room_id=None, question_id=question.id, current=profile)
    if not rows:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Resolve failed")
    return rows[0]
