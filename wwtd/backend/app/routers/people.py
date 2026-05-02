from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.auth import get_current_profile
from app.db import get_db
from app.models import Person, Profile
from app.schemas import PersonCreate, PersonOut

router = APIRouter(prefix="/people", tags=["people"])


@router.get("", response_model=list[PersonOut])
def list_people(db: Annotated[Session, Depends(get_db)]) -> list[Person]:
    return list(db.scalars(select(Person).order_by(Person.name)).all())


@router.post("", response_model=PersonOut, status_code=status.HTTP_201_CREATED)
def create_person(
    body: PersonCreate,
    db: Annotated[Session, Depends(get_db)],
    _: Annotated[Profile, Depends(get_current_profile)],
) -> Person:
    name = body.name.strip()
    existing = db.scalar(select(Person).where(Person.name == name))
    if existing:
        raise HTTPException(status.HTTP_409_CONFLICT, detail="Person with this name already exists")
    person = Person(name=name)
    db.add(person)
    db.commit()
    db.refresh(person)
    return person
