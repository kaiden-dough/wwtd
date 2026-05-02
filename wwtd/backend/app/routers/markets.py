from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, case, func, select
from sqlalchemy.orm import Session

from app.auth import get_current_profile, get_optional_profile
from app.db import get_db
from app.models import Bet, Market, Person, Profile
from app.schemas import BetCreate, MarketCreate, MarketOut

router = APIRouter(prefix="/markets", tags=["markets"])


def _get_or_create_person(db: Session, name: str) -> Person:
    normalized = name.strip()
    person = db.scalar(select(Person).where(Person.name == normalized))
    if person:
        return person
    person = Person(name=normalized)
    db.add(person)
    db.flush()
    return person


def _run_markets_query(
    db: Session,
    *,
    person_id: int | None,
    market_id: str | None,
    current: Profile | None,
) -> list[MarketOut]:
    yes_sum = func.coalesce(func.sum(case((Bet.side == "yes", Bet.amount), else_=0)), 0.0)
    no_sum = func.coalesce(func.sum(case((Bet.side == "no", Bet.amount), else_=0)), 0.0)

    columns: list = [
        Market.id,
        Market.person_id,
        Person.name.label("person_name"),
        Market.question,
        Market.date_label,
        Market.created_by,
        Market.status,
        Market.created_at,
        yes_sum.label("yes_total"),
        no_sum.label("no_total"),
    ]
    if current is not None:
        uid = current.id
        columns.append(
            func.coalesce(
                func.sum(case((and_(Bet.side == "yes", Bet.user_id == uid), Bet.amount), else_=0)),
                0.0,
            ).label("user_yes")
        )
        columns.append(
            func.coalesce(
                func.sum(case((and_(Bet.side == "no", Bet.user_id == uid), Bet.amount), else_=0)),
                0.0,
            ).label("user_no")
        )

    stmt = (
        select(*columns)
        .join(Person, Market.person_id == Person.id)
        .outerjoin(Bet, Bet.market_id == Market.id)
        .group_by(Market.id, Person.id, Person.name)
        .order_by(Market.created_at.desc())
    )
    if person_id is not None:
        stmt = stmt.where(Market.person_id == person_id)
    if market_id is not None:
        stmt = stmt.where(Market.id == market_id)

    rows = db.execute(stmt).all()
    out: list[MarketOut] = []
    for row in rows:
        mapping = row._mapping
        out.append(
            MarketOut(
                id=mapping["id"],
                person_id=mapping["person_id"],
                person_name=mapping["person_name"],
                question=mapping["question"],
                date_label=mapping["date_label"],
                created_by=mapping["created_by"],
                status=mapping["status"],
                created_at=mapping["created_at"],
                yes_wagered_points=float(mapping["yes_total"] or 0),
                no_wagered_points=float(mapping["no_total"] or 0),
                user_yes_bet=float(mapping.get("user_yes") or 0) if current is not None else 0.0,
                user_no_bet=float(mapping.get("user_no") or 0) if current is not None else 0.0,
            )
        )
    return out


@router.get("", response_model=list[MarketOut])
def list_markets(
    db: Annotated[Session, Depends(get_db)],
    current: Annotated[Profile | None, Depends(get_optional_profile)],
    person_id: int | None = None,
) -> list[MarketOut]:
    return _run_markets_query(db, person_id=person_id, market_id=None, current=current)


@router.get("/{market_id}", response_model=MarketOut)
def get_market(
    market_id: str,
    db: Annotated[Session, Depends(get_db)],
    current: Annotated[Profile | None, Depends(get_optional_profile)],
) -> MarketOut:
    rows = _run_markets_query(db, person_id=None, market_id=market_id, current=current)
    if not rows:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Market not found")
    return rows[0]


@router.post("", response_model=MarketOut, status_code=status.HTTP_201_CREATED)
def create_market(
    body: MarketCreate,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> MarketOut:
    person = _get_or_create_person(db, body.person_name)
    market = Market(
        person_id=person.id,
        question=body.question.strip(),
        date_label=body.date_label.strip(),
        created_by=profile.id,
        status="open",
    )
    db.add(market)
    db.flush()

    side = body.creator_side.lower()
    bet = Bet(market_id=market.id, user_id=profile.id, side=side, amount=float(body.creator_stake))
    db.add(bet)
    db.commit()

    rows = _run_markets_query(db, person_id=None, market_id=market.id, current=profile)
    if not rows:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Market creation failed")
    return rows[0]


@router.post("/{market_id}/bets", response_model=MarketOut)
def place_bet(
    market_id: str,
    body: BetCreate,
    db: Annotated[Session, Depends(get_db)],
    profile: Annotated[Profile, Depends(get_current_profile)],
) -> MarketOut:
    market = db.get(Market, market_id)
    if market is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Market not found")
    if market.status != "open":
        raise HTTPException(status.HTTP_400_BAD_REQUEST, detail="Market is not open for betting")

    bet = Bet(
        market_id=market.id,
        user_id=profile.id,
        side=body.side.lower(),
        amount=float(body.amount),
    )
    db.add(bet)
    db.commit()

    rows = _run_markets_query(db, person_id=None, market_id=market.id, current=profile)
    if not rows:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Bet failed")
    return rows[0]
