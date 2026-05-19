from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_DEFAULT_DB = Path(__file__).resolve().parent.parent / "data" / "wwtd.db"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    starting_balance_points: float = 500.0
    jwt_secret: str = "dev-change-me"
    jwt_expire_days: int = 30
    otp_expire_minutes: int = 10
    otp_max_attempts: int = 5

    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""
    smtp_use_tls: bool = True
    # When SMTP is not set, return the OTP in the API response (local dev only).
    expose_dev_otp: bool = True

    # Supabase / Postgres: set DATABASE_URL to the Supabase connection string (Session or Transaction pooler).
    # Leave unset for local SQLite at sqlite_path.
    database_url: str = ""
    sqlite_path: Path = _DEFAULT_DB
    cors_origins: str = "*"


settings = Settings()
