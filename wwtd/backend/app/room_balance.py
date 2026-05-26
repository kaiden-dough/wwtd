from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.models import RoomMember


def get_room_member(db: Session, room_id: str, user_id: str) -> RoomMember:
    member = db.scalar(
        select(RoomMember).where(RoomMember.room_id == room_id, RoomMember.user_id == user_id)
    )
    if member is None:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Join this room with its code first")
    return member


def deduct_room_balance(member: RoomMember, amount: float) -> None:
    if member.balance_points < amount:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            detail=f"Insufficient balance ({member.balance_points:.0f} points available in this room)",
        )
    member.balance_points -= amount


def credit_room_balance(db: Session, room_id: str, user_id: str, amount: float) -> None:
    member = get_room_member(db, room_id, user_id)
    member.balance_points += amount


def starting_balance() -> float:
    return float(settings.starting_balance_points)
