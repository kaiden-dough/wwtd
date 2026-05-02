from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_DEFAULT_DB = Path(__file__).resolve().parent.parent / "data" / "wwtd.db"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    supabase_jwt_secret: str = ""
    supabase_jwt_audience: str = "authenticated"
    sqlite_path: Path = _DEFAULT_DB
    cors_origins: str = "*"


settings = Settings()
