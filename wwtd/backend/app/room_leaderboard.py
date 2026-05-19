from sqlalchemy import select
from sqlalchemy.orm import Session, joinedload

from app.models import Bet, Profile, Question, Room, RoomMember
from app.schemas import LeaderboardEntryOut


def entries_for_room(db: Session, room_id: str) -> list[LeaderboardEntryOut]:
    """Rank room members by net profit from resolved bets in this room."""
    members = list(
        db.scalars(
            select(Profile)
            .join(RoomMember, RoomMember.user_id == Profile.id)
            .where(RoomMember.room_id == room_id)
        )
    )
    stats: dict[str, dict[str, float | int]] = {
        member.id: {"net": 0.0, "wins": 0, "resolved": 0} for member in members
    }

    bets = list(
        db.scalars(
            select(Bet)
            .join(Question, Bet.question_id == Question.id)
            .where(Question.room_id == room_id)
            .options(joinedload(Bet.question))
        )
    )
    for bet in bets:
        if bet.user_id not in stats:
            continue
        question = bet.question
        if question.status != "resolved" or bet.payout_amount is None:
            continue
        row = stats[bet.user_id]
        row["net"] = float(row["net"]) + (bet.payout_amount - bet.amount)
        row["resolved"] = int(row["resolved"]) + 1
        if bet.payout_amount > bet.amount:
            row["wins"] = int(row["wins"]) + 1

    entries: list[LeaderboardEntryOut] = []
    for member in members:
        row = stats[member.id]
        resolved = int(row["resolved"])
        wins = int(row["wins"])
        net = float(row["net"])
        win_rate = (wins / resolved * 100.0) if resolved else 0.0
        label = member.username or member.display_name or member.email or member.id
        entries.append(
            LeaderboardEntryOut(
                user_id=member.id,
                display_name=label,
                net_points=net,
                win_rate=win_rate,
                is_trending_up=net >= 0,
            )
        )

    entries.sort(key=lambda e: (-e.net_points, -e.win_rate, e.display_name.lower()))
    return entries


def leaderboards_for_user(db: Session, user_id: str) -> list[tuple[Room, list[LeaderboardEntryOut]]]:
    rooms = list(
        db.scalars(
            select(Room)
            .join(RoomMember, RoomMember.room_id == Room.id)
            .where(RoomMember.user_id == user_id)
            .options(joinedload(Room.person))
            .order_by(Room.created_at.desc())
        )
    )
    return [(room, entries_for_room(db, room.id)) for room in rooms]
