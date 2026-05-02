from collections.abc import Generator
from pathlib import Path

from sqlalchemy import create_engine, event
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings


def _ensure_parent_dir(database_url: str) -> None:
    if database_url.startswith("sqlite:///"):
        path = Path(database_url.removeprefix("sqlite:///"))
        path.parent.mkdir(parents=True, exist_ok=True)


database_url = f"sqlite:///{settings.sqlite_path.as_posix()}"
_ensure_parent_dir(database_url)

engine = create_engine(
    database_url,
    connect_args={"check_same_thread": False},
    pool_pre_ping=True,
)


@event.listens_for(engine, "connect")
def _set_sqlite_pragma(dbapi_connection, _connection_record) -> None:
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.close()


class Base(DeclarativeBase):
    pass


SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
