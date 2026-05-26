from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, case, exists, func, or_, select
from sqlalchemy.orm import Session

from app.auth import get_current_profile
from app.db import get_db
from app.market_codes import generate_join_code
from app.models import Bet, Person, Profile, Question, Room, RoomMember
from app.payouts import resolve_question
from app.question_betting import betting_open_for, is_betting_open
from app.refunds import refund_question_bets
from app.room_balance import deduct_room_balance, get_room_member, starting_balance
from app.schemas import (
    BetCreate,
    QuestionCreate,
    QuestionOut,
    QuestionResolve,
    RoomCreate,
    RoomDiscoverOut,
    RoomJoin,
    RoomOut,
)

router = APIRouter(tags=["rooms"])


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


def _add_member(db: Session, room_id: str, user_id: str) -> RoomMember:
    member = db.scalar(
        select(RoomMember).where(RoomMember.room_id == room_id, RoomMember.user_id == user_id)
    )
    if member is not None:
        return member
    member = RoomMember(
        room_id=room_id,
        user_id=user_id,
        balance_points=starting_balance(),
    )
    db.add(member)
    db.flush()
    return member


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


def _room_out(
    room: Room,
    person: Person,
    profile: Profile,
    member: RoomMember,
    moderator: Profile,
) -> RoomOut:
    is_mod = _is_moderator(room, profile)
    mod_label = "You" if is_mod else _moderator_label(moderator)
    return RoomOut(
        id=room.id,
        join_code=room.join_code,
        person_name=person.name,
        moderator_name=mod_label,
        is_moderator=is_mod,
        balance_points=float(member.balance_points),
        created_at=room.created_at,
    )


def _moderator_label(profile: Profile) -> str:
    return profile.username or profile.display_name or profile.email or "Unknown"


@router.get("/rooms/discover", response_model=list[RoomDiscoverOut])
def discover_rooms(
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
    q: str = "",
) -> list[RoomDiscoverOut]:
    """Search rooms by subject name or moderator. Join code is never returned."""
    term = q.strip()
    if len(term) < 1:
        return []

    pattern = f"%{term}%"
    stmt = (
        select(Room, Person, Profile)
        .join(Person, Room.person_id == Person.id)
        .join(Profile, Room.created_by == Profile.id)
        .where(
            or_(
                Person.name.ilike(pattern),
                Profile.username.ilike(pattern),
                Profile.display_name.ilike(pattern),
            )
        )
        .order_by(Room.created_at.desc())
        .limit(25)
    )
    rows = db.execute(stmt).all()
    results: list[RoomDiscoverOut] = []
    for room, person, moderator in rows:
        results.append(
            RoomDiscoverOut(
                id=room.id,
                person_name=person.name,
                moderator_name=_moderator_label(moderator),
                is_member=_is_member(db, room.id, profile.id),
            )
        )
    return results


@router.get("/rooms", response_model=list[RoomOut])
def list_my_rooms(
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> list[RoomOut]:
    stmt = (
        select(Room, Person, RoomMember, Profile)
        .join(RoomMember, RoomMember.room_id == Room.id)
        .join(Person, Room.person_id == Person.id)
        .join(Profile, Room.created_by == Profile.id)
        .where(RoomMember.user_id == profile.id)
    )
    rows = list(db.execute(stmt).all())
    rows.sort(
        key=lambda row: (
            0 if row[0].created_by == profile.id else 1,
            -row[0].created_at.timestamp(),
        )
    )
    return [_room_out(room, person, profile, member, moderator) for room, person, member, moderator in rows]


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
    member = _add_member(db, room.id, profile.id)
    db.commit()
    db.refresh(room)
    return _room_out(room, person, profile, member, profile)


@router.post("/rooms/join", response_model=RoomOut)
def join_room(
    body: RoomJoin,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> RoomOut:
    code = body.join_code.strip().upper()
    if body.room_id is not None:
        row = db.execute(
            select(Room, Person, Profile)
            .join(Person, Room.person_id == Person.id)
            .join(Profile, Room.created_by == Profile.id)
            .where(Room.id == body.room_id)
        ).first()
        if row is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Room not found")
        room, person, moderator = row
        if room.join_code.upper() != code:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                detail="Join code does not match the selected room",
            )
    else:
        row = db.execute(
            select(Room, Person, Profile)
            .join(Person, Room.person_id == Person.id)
            .join(Profile, Room.created_by == Profile.id)
            .where(Room.join_code == code)
        ).first()
        if row is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Invalid join code")
        room, person, moderator = row
    member = _add_member(db, room.id, profile.id)
    db.commit()
    db.refresh(member)
    return _room_out(room, person, profile, member, moderator)


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
    member = get_room_member(db, question.room_id, profile.id)
    deduct_room_balance(member, amount)
    db.add(
        Bet(
            question_id=question.id,
            user_id=profile.id,
            side=body.side.lower(),
            amount=amount,
        )
    )
    db.commit()

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
