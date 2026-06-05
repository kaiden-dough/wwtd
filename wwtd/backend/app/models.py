import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class LoginCode(Base):
    __tablename__ = "login_codes"

    email: Mapped[str] = mapped_column(String(320), primary_key=True)
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Profile(Base):
    __tablename__ = "profiles"
    __table_args__ = (UniqueConstraint("email", name="uq_profiles_email"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    username: Mapped[str | None] = mapped_column(String(32), nullable=True, unique=True)
    password_hash: Mapped[str | None] = mapped_column(String(128), nullable=True)
    email: Mapped[str | None] = mapped_column(String(320), nullable=True, unique=True)
    display_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(Text, nullable=True)
    balance_points: Mapped[float] = mapped_column(Float, nullable=False, default=500.0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    rooms_created: Mapped[list["Room"]] = relationship(back_populates="moderator")
    bets: Mapped[list["Bet"]] = relationship(back_populates="user")


class Person(Base):
    __tablename__ = "people"
    __table_args__ = (UniqueConstraint("name", name="uq_people_name"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    rooms: Mapped[list["Room"]] = relationship(back_populates="person")
    room_links: Mapped[list["RoomPerson"]] = relationship(back_populates="person")
    question_links: Mapped[list["QuestionTarget"]] = relationship(back_populates="person")


class Room(Base):
    __tablename__ = "rooms"
    __table_args__ = (UniqueConstraint("join_code", name="uq_rooms_join_code"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    join_code: Mapped[str] = mapped_column(String(8), nullable=False, unique=True)
    person_id: Mapped[int] = mapped_column(ForeignKey("people.id", ondelete="RESTRICT"), nullable=False)
    room_type: Mapped[str] = mapped_column(String(16), nullable=False, default="individual")
    created_by: Mapped[str] = mapped_column(ForeignKey("profiles.id", ondelete="RESTRICT"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    person: Mapped[Person] = relationship(back_populates="rooms")
    people: Mapped[list["RoomPerson"]] = relationship(back_populates="room", cascade="all, delete-orphan")
    moderator: Mapped[Profile] = relationship(back_populates="rooms_created")
    members: Mapped[list["RoomMember"]] = relationship(back_populates="room", cascade="all, delete-orphan")
    questions: Mapped[list["Question"]] = relationship(back_populates="room", cascade="all, delete-orphan")


class RoomPerson(Base):
    __tablename__ = "room_people"
    __table_args__ = (UniqueConstraint("room_id", "person_id", name="uq_room_person"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    room_id: Mapped[str] = mapped_column(ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False)
    person_id: Mapped[int] = mapped_column(ForeignKey("people.id", ondelete="RESTRICT"), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    is_primary: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    room: Mapped[Room] = relationship(back_populates="people")
    person: Mapped[Person] = relationship(back_populates="room_links")


class RoomMember(Base):
    __tablename__ = "room_members"
    __table_args__ = (UniqueConstraint("room_id", "user_id", name="uq_room_member"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    room_id: Mapped[str] = mapped_column(ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False)
    balance_points: Mapped[float] = mapped_column(Float, nullable=False, default=500.0)
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    room: Mapped[Room] = relationship(back_populates="members")
    user: Mapped[Profile] = relationship()


class Question(Base):
    __tablename__ = "questions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id: Mapped[str] = mapped_column(ForeignKey("rooms.id", ondelete="CASCADE"), nullable=False)
    question: Mapped[str] = mapped_column(Text, nullable=False)
    created_by: Mapped[str] = mapped_column(ForeignKey("profiles.id", ondelete="RESTRICT"), nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="open")
    winning_side: Mapped[str | None] = mapped_column(String(8), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    betting_closes_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    room: Mapped[Room] = relationship(back_populates="questions")
    author: Mapped[Profile] = relationship(foreign_keys=[created_by])
    bets: Mapped[list["Bet"]] = relationship(back_populates="question", cascade="all, delete-orphan")
    targets: Mapped[list["QuestionTarget"]] = relationship(back_populates="question", cascade="all, delete-orphan")


class QuestionTarget(Base):
    __tablename__ = "question_targets"
    __table_args__ = (UniqueConstraint("question_id", "person_id", name="uq_question_target"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    question_id: Mapped[str] = mapped_column(ForeignKey("questions.id", ondelete="CASCADE"), nullable=False)
    person_id: Mapped[int] = mapped_column(ForeignKey("people.id", ondelete="RESTRICT"), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    question: Mapped[Question] = relationship(back_populates="targets")
    person: Mapped[Person] = relationship(back_populates="question_links")


class Bet(Base):
    __tablename__ = "bets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    question_id: Mapped[str] = mapped_column(ForeignKey("questions.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("profiles.id", ondelete="RESTRICT"), nullable=False)
    side: Mapped[str] = mapped_column(String(8), nullable=False)
    amount: Mapped[float] = mapped_column(Float, nullable=False)
    payout_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    question: Mapped[Question] = relationship(back_populates="bets")
    user: Mapped[Profile] = relationship(back_populates="bets")
