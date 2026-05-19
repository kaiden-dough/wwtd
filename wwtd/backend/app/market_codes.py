import secrets
import string

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Room

_CODE_ALPHABET = string.ascii_uppercase + string.digits
_CODE_LENGTH = 6


def generate_join_code(db: Session) -> str:
    for _ in range(32):
        code = "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LENGTH))
        exists = db.scalar(select(Room.id).where(Room.join_code == code))
        if not exists:
            return code
    raise RuntimeError("Could not allocate unique join code")
