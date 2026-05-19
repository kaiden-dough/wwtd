from collections.abc import Generator
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

from sqlalchemy import create_engine, event
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from app.config import settings


def _ensure_sqlite_parent_dir(database_url: str) -> None:
    if database_url.startswith("sqlite:///"):
        path = Path(database_url.removeprefix("sqlite:///"))
        path.parent.mkdir(parents=True, exist_ok=True)


def normalize_database_url(raw: str) -> str:
    """Accept Supabase-style postgres:// URLs and ensure psycopg driver."""
    url = raw.strip()
    if not url:
        raise ValueError("DATABASE_URL is empty")

    if url.startswith("postgres://"):
        url = "postgresql+psycopg://" + url.removeprefix("postgres://")
    elif url.startswith("postgresql://") and "+psycopg" not in url.split("://", 1)[0]:
        url = "postgresql+psycopg://" + url.removeprefix("postgresql://")

    # Supabase pooler URLs often include ?pgbouncer=true — psycopg handles it; strip for SQLAlchemy compat if needed.
    parsed = urlparse(url)
    if parsed.query:
        query = [(k, v) for k, v in parse_qsl(parsed.query) if k.lower() not in {"pgbouncer"}]
        url = urlunparse(parsed._replace(query=urlencode(query)))

    return url


def resolve_database_url() -> str:
    if settings.database_url.strip():
        return normalize_database_url(settings.database_url)
    path = settings.sqlite_path.as_posix()
    return f"sqlite:///{path}"


def create_app_engine() -> Engine:
    database_url = resolve_database_url()
    _ensure_sqlite_parent_dir(database_url)

    if database_url.startswith("sqlite"):
        return create_engine(
            database_url,
            connect_args={"check_same_thread": False},
            pool_pre_ping=True,
        )

    return create_engine(
        database_url,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
    )


engine = create_app_engine()


@event.listens_for(engine, "connect")
def _on_connect(dbapi_connection, _connection_record) -> None:
    if engine.dialect.name != "sqlite":
        return
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


def is_postgres() -> bool:
    return engine.dialect.name == "postgresql"
