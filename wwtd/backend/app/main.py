import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.db import Base, engine
from app.routers import markets, me, people


@asynccontextmanager
async def lifespan(_app: FastAPI):
    Base.metadata.create_all(bind=engine)
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

app.include_router(me.router, prefix="/api")
app.include_router(people.router, prefix="/api")
app.include_router(markets.router, prefix="/api")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", "8000"))
    uvicorn.run("app.main:app", host="0.0.0.0", port=port, reload=False)
