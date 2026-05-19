import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import Base, engine, is_postgres
from app.db_migrate import run_migrations
from app.routers import auth, leaderboard, me, people, rooms

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    try:
        Base.metadata.create_all(bind=engine)
        run_migrations(engine)
        logger.info("Database ready (%s)", "postgres" if is_postgres() else "sqlite")
    except Exception:
        logger.exception("Database startup failed — check DATABASE_URL (pooler :6543, URL-encode password)")
        raise
    yield


app = FastAPI(title="wwtd API", lifespan=lifespan)

_origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
_wildcard = not _origins or _origins == ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if _wildcard else _origins,
    allow_credentials=not _wildcard,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api")
app.include_router(me.router, prefix="/api")
app.include_router(people.router, prefix="/api")
app.include_router(rooms.router, prefix="/api")
app.include_router(rooms.markets_router, prefix="/api")
app.include_router(leaderboard.router, prefix="/api")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", "8000"))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
