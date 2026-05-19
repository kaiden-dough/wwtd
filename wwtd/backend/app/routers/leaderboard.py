from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import and_, exists, select
from sqlalchemy.orm import Session, joinedload

from app.auth import get_current_profile
from app.db import get_db
from app.models import Profile, Room, RoomMember
from app.room_leaderboard import entries_for_room, leaderboards_for_user
from app.schemas import RoomLeaderboardOut

router = APIRouter(prefix="/leaderboard", tags=["leaderboard"])


@router.get("", response_model=list[RoomLeaderboardOut])
def list_leaderboard(
    profile: Annotated[Profile, Depends(get_current_profile)],
    db: Annotated[Session, Depends(get_db)],
    room_id: str | None = None,
) -> list[RoomLeaderboardOut]:
    if room_id is not None:
        room = db.scalar(
            select(Room).where(Room.id == room_id).options(joinedload(Room.person))
        )
        if room is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, detail="Room not found")
        is_member = db.scalar(
            select(
                exists().where(
                    and_(RoomMember.room_id == room_id, RoomMember.user_id == profile.id)
                )
            )
        )
        if not is_member:
            raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Not a member of this room")
        person_name = room.person.name if room.person else "Unknown"
        return [
            RoomLeaderboardOut(
                room_id=room.id,
                person_name=person_name,
                entries=entries_for_room(db, room.id),
            )
        ]

    boards = leaderboards_for_user(db, profile.id)
    out: list[RoomLeaderboardOut] = []
    for room, entries in boards:
        person_name = room.person.name if room.person else "Unknown"
        out.append(
            RoomLeaderboardOut(
                room_id=room.id,
                person_name=person_name,
                entries=entries,
            )
        )
    return out
