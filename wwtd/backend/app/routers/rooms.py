from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, case, exists, func, or_, select
from sqlalchemy.orm import Session, aliased

from app.auth import get_current_profile
from app.db import get_db
from app.market_codes import generate_join_code
from app.models import Bet, Person, Profile, Question, QuestionTarget, Room, RoomMember, RoomPerson
from app.payouts import resolve_question, unresolve_question
from app.question_betting import (
    betting_closes_at_for,
    betting_open_for,
    default_expiry_date,
    eastern_eod_for,
    is_betting_open,
)
from app.refunds import refund_question_bets
from app.room_balance import credit_room_balance, deduct_room_balance, get_room_member, starting_balance
from app.schemas import (
    BetCreate,
    PickHistoryOut,
    QuestionCreate,
    QuestionExpiryUpdate,
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


def _normalize_names(names: list[str]) -> list[str]:
    normalized: list[str] = []
    seen: set[str] = set()
    for name in names:
        value = name.strip()
        key = value.lower()
        if not value or key in seen:
            continue
        normalized.append(value)
        seen.add(key)
    return normalized


def _room_person_names(db: Session, room: Room, fallback: Person | None = None) -> list[str]:
    rows = db.execute(
        select(Person.name)
        .join(RoomPerson, RoomPerson.person_id == Person.id)
        .where(RoomPerson.room_id == room.id)
        .order_by(RoomPerson.sort_order.asc(), Person.name.asc())
    ).scalars().all()
    if rows:
        return list(rows)
    if fallback is not None:
        return [fallback.name]
    if room.person is not None:
        return [room.person.name]
    return []


def _room_label(names: list[str]) -> str:
    if not names:
        return "Unknown"
    if len(names) == 1:
        return names[0]
    return ", ".join(names)


def _question_target_names(db: Session, question_id: str, fallback_name: str) -> list[str]:
    rows = db.execute(
        select(Person.name)
        .join(QuestionTarget, QuestionTarget.person_id == Person.id)
        .where(QuestionTarget.question_id == question_id)
        .order_by(QuestionTarget.sort_order.asc(), Person.name.asc())
    ).scalars().all()
    return list(rows) if rows else [fallback_name]


def _pick_history(db: Session, question_id: str) -> list[PickHistoryOut]:
    rows = db.execute(
        select(Bet.side, Bet.amount, Bet.created_at)
        .where(Bet.question_id == question_id)
        .order_by(Bet.created_at.asc(), Bet.id.asc())
    ).all()
    return [
        PickHistoryOut(
            side=row.side,
            amount=float(row.amount),
            created_at=row.created_at,
        )
        for row in rows
    ]


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


def _add_room_people(db: Session, room: Room, people: list[Person]) -> None:
    for index, person in enumerate(people):
        db.add(
            RoomPerson(
                room_id=room.id,
                person_id=person.id,
                sort_order=index,
                is_primary=index == 0,
            )
        )
    db.flush()


def _room_people(db: Session, room: Room) -> list[Person]:
    rows = db.execute(
        select(Person)
        .join(RoomPerson, RoomPerson.person_id == Person.id)
        .where(RoomPerson.room_id == room.id)
        .order_by(RoomPerson.sort_order.asc(), Person.name.asc())
    ).scalars().all()
    if rows:
        return list(rows)
    if room.person is not None:
        return [room.person]
    person = db.get(Person, room.person_id)
    return [person] if person is not None else []


def _target_people_for_question(db: Session, room: Room, target_names: list[str]) -> list[Person]:
    available = _room_people(db, room)
    if not available:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Room has no people")

    requested = _normalize_names(target_names)
    if not requested:
        return available

    by_name = {person.name.lower(): person for person in available}
    missing = [name for name in requested if name.lower() not in by_name]
    if missing:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail=f"Question targets must be people in this room: {', '.join(missing)}",
        )
    return [by_name[name.lower()] for name in requested]


def _is_moderator(room: Room, profile: Profile) -> bool:
    return room.created_by == profile.id


def _is_hidden_admin(profile: Profile) -> bool:
    return (profile.username or "").lower() == "admin"


def _can_moderate(room: Room, profile: Profile) -> bool:
    return _is_moderator(room, profile) or _is_hidden_admin(profile)


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
    is_hidden_admin = _is_hidden_admin(current)
    membership_exists = exists().where(and_(RoomMember.room_id == Room.id, RoomMember.user_id == uid))

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
            Question.betting_closes_at,
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
        .outerjoin(Bet, Bet.question_id == Question.id)
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
            Question.betting_closes_at,
            Room.created_by,
        )
    )
    if not is_hidden_admin:
        stmt = stmt.where(membership_exists)
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
            target_names=_question_target_names(db, m.id, m.person_name),
            question=m.question,
            created_by=m.created_by,
            is_moderator=m.moderator_id == current.id,
            status=m.status,
            winning_side=m.winning_side,
            created_at=m.created_at,
            betting_closes_at=betting_closes_at_for(
                created_at=m.created_at,
                betting_closes_at=m.betting_closes_at,
            ),
            betting_open=betting_open_for(
                status=m.status,
                created_at=m.created_at,
                betting_closes_at=m.betting_closes_at,
            ),
            yes_wagered_points=float(m.yes_total or 0),
            no_wagered_points=float(m.no_total or 0),
            user_yes_bet=float(m.user_yes or 0),
            user_no_bet=float(m.user_no or 0),
            pick_history=_pick_history(db, m.id),
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
    db: Session,
    room: Room,
    person: Person,
    profile: Profile,
    member: RoomMember | None,
    moderator: Profile,
) -> RoomOut:
    is_mod = _is_moderator(room, profile)
    can_moderate = _can_moderate(room, profile)
    mod_label = "You" if is_mod else _moderator_label(moderator)
    person_names = _room_person_names(db, room, person)
    return RoomOut(
        id=room.id,
        join_code=room.join_code,
        person_name=_room_label(person_names),
        person_names=person_names,
        room_type=room.room_type,
        moderator_name=mod_label,
        is_moderator=is_mod,
        can_moderate=can_moderate,
        balance_points=float(member.balance_points if member is not None else starting_balance()),
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
    SearchPerson = aliased(Person)
    member_count = func.count(RoomMember.id)
    stmt = (
        select(Room, Person, Profile, member_count.label("member_count"))
        .join(Person, Room.person_id == Person.id)
        .join(Profile, Room.created_by == Profile.id)
        .outerjoin(RoomMember, RoomMember.room_id == Room.id)
        .group_by(
            Room.id,
            Room.join_code,
            Room.person_id,
            Room.room_type,
            Room.created_by,
            Room.created_at,
            Person.id,
            Person.name,
            Profile.id,
            Profile.username,
            Profile.display_name,
            Profile.email,
        )
        .order_by(member_count.desc(), Room.created_at.desc())
        .limit(5)
    )
    if term:
        pattern = f"%{term}%"
        person_match = exists().where(
            and_(
                RoomPerson.room_id == Room.id,
                RoomPerson.person_id == SearchPerson.id,
                SearchPerson.name.ilike(pattern),
            )
        )
        stmt = stmt.where(
            or_(
                Person.name.ilike(pattern),
                person_match,
                Profile.username.ilike(pattern),
                Profile.display_name.ilike(pattern),
            )
        )
    rows = db.execute(stmt).all()
    results: list[RoomDiscoverOut] = []
    for room, person, moderator, members in rows:
        person_names = _room_person_names(db, room, person)
        results.append(
            RoomDiscoverOut(
                id=room.id,
                person_name=_room_label(person_names),
                person_names=person_names,
                room_type=room.room_type,
                moderator_name=_moderator_label(moderator),
                member_count=int(members or 0),
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
        .join(Person, Room.person_id == Person.id)
        .join(Profile, Room.created_by == Profile.id)
        .outerjoin(
            RoomMember,
            and_(RoomMember.room_id == Room.id, RoomMember.user_id == profile.id),
        )
    )
    if not _is_hidden_admin(profile):
        stmt = stmt.where(RoomMember.user_id == profile.id)
    rows = list(db.execute(stmt).all())
    rows.sort(
        key=lambda row: (
            0 if row[0].created_by == profile.id else 1,
            -row[0].created_at.timestamp(),
        )
    )
    return [_room_out(db, room, person, profile, member, moderator) for room, person, member, moderator in rows]


@router.post("/rooms", response_model=RoomOut, status_code=status.HTTP_201_CREATED)
def create_room(
    body: RoomCreate,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> RoomOut:
    requested_names = _normalize_names([
        *body.person_names,
        *([body.person_name] if body.person_name else []),
    ])
    if not requested_names:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Add at least one person")
    people = [_get_or_create_person(db, name) for name in requested_names]
    person = people[0]
    room = Room(
        join_code=generate_join_code(db),
        person_id=person.id,
        room_type="group" if len(people) > 1 or body.room_type == "group" else "individual",
        created_by=profile.id,
    )
    db.add(room)
    db.flush()
    _add_room_people(db, room, people)
    member = _add_member(db, room.id, profile.id)
    db.commit()
    db.refresh(room)
    return _room_out(db, room, person, profile, member, profile)


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
    return _room_out(db, room, person, profile, member, moderator)


@router.get("/rooms/{room_id}/questions", response_model=list[QuestionOut])
def list_room_questions(
    room_id: str,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> list[QuestionOut]:
    if not _is_hidden_admin(profile) and not _is_member(db, room_id, profile.id):
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
    if not _is_hidden_admin(profile):
        _require_member(db, room, profile)

    targets = _target_people_for_question(db, room, body.target_names)
    question = Question(
        room_id=room.id,
        question=body.question.strip(),
        created_by=profile.id,
        status="open",
        betting_closes_at=eastern_eod_for(body.expires_on or default_expiry_date()),
    )
    db.add(question)
    db.flush()
    for index, person in enumerate(targets):
        db.add(
            QuestionTarget(
                question_id=question.id,
                person_id=person.id,
                sort_order=index,
            )
        )
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
    if not _can_moderate(room, profile):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Only the moderator can delete questions")

    question = db.get(Question, question_id)
    if question is None or question.room_id != room.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Question not found")

    refund_question_bets(db, question)
    db.delete(question)
    db.commit()


@router.delete("/rooms/{room_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_room(
    room_id: str,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> None:
    room = db.get(Room, room_id)
    if room is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Room not found")
    if not _can_moderate(room, profile):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Only the moderator can delete rooms")

    db.delete(room)
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
    if _is_hidden_admin(profile) and not _is_member(db, room.id, profile.id):
        member = _add_member(db, room.id, profile.id)
    else:
        _require_member(db, room, profile)
        member = get_room_member(db, question.room_id, profile.id)
    if question.status != "open":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Question is not open for picking")
    if not is_betting_open(question):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail="Picking is closed (expiry reached or question was resolved)",
        )

    amount = float(body.amount)
    side = body.side.lower()
    existing_bet = db.scalar(
        select(Bet).where(Bet.question_id == question.id, Bet.user_id == profile.id)
    )
    if existing_bet is not None:
        credit_room_balance(db, question.room_id, profile.id, existing_bet.amount)

    deduct_room_balance(member, amount)
    if existing_bet is None:
        db.add(
            Bet(
                question_id=question.id,
                user_id=profile.id,
                side=side,
                amount=amount,
            )
        )
    else:
        existing_bet.side = side
        existing_bet.amount = amount
        existing_bet.payout_amount = None
        existing_bet.created_at = datetime.now(UTC)
    db.commit()

    rows = _run_questions_query(db, room_id=None, question_id=question.id, current=profile)
    if not rows:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Pick failed")
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
    if not _can_moderate(room, profile):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Only the moderator can resolve questions")
    if question.status not in ("open", "resolved"):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Question cannot be resolved")

    resolve_question(db, question, body.winning_side.lower())
    db.commit()

    rows = _run_questions_query(db, room_id=None, question_id=question.id, current=profile)
    if not rows:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Resolve failed")
    return rows[0]


@markets_router.patch("/{question_id}/expiry", response_model=QuestionOut)
def update_question_expiry_endpoint(
    question_id: str,
    body: QuestionExpiryUpdate,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> QuestionOut:
    question = db.get(Question, question_id)
    if question is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Question not found")
    room = db.get(Room, question.room_id)
    if room is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Room not found")
    if not _can_moderate(room, profile):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Only the moderator can change expiry")

    question.betting_closes_at = eastern_eod_for(body.expires_on)
    db.commit()

    rows = _run_questions_query(db, room_id=None, question_id=question.id, current=profile)
    if not rows:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Expiry update failed")
    return rows[0]


@markets_router.post("/{question_id}/unresolve", response_model=QuestionOut)
def unresolve_question_endpoint(
    question_id: str,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> QuestionOut:
    question = db.get(Question, question_id)
    if question is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Question not found")
    room = db.get(Room, question.room_id)
    if room is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Room not found")
    if not _can_moderate(room, profile):
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Only the moderator can undo resolves")
    if question.status != "resolved":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Question is not resolved")

    unresolve_question(db, question)
    db.commit()

    rows = _run_questions_query(db, room_id=None, question_id=question.id, current=profile)
    if not rows:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Undo resolve failed")
    return rows[0]
