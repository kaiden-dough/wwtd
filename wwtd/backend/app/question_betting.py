from datetime import UTC, date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from app.models import Question

EASTERN = ZoneInfo("America/New_York")


def _as_utc(when: datetime) -> datetime:
    if when.tzinfo is None:
        return when.replace(tzinfo=UTC)
    return when.astimezone(UTC)


def default_expiry_date(now: datetime | None = None) -> date:
    moment = now or datetime.now(UTC)
    return _as_utc(moment).astimezone(EASTERN).date()


def eastern_eod_for(day: date) -> datetime:
    next_midnight = datetime.combine(day + timedelta(days=1), time.min, tzinfo=EASTERN)
    return next_midnight.astimezone(UTC)


def betting_closes_at_for(
    *,
    created_at: datetime,
    betting_closes_at: datetime | None = None,
) -> datetime:
    if betting_closes_at is not None:
        return _as_utc(betting_closes_at)
    created_day = _as_utc(created_at).astimezone(EASTERN).date()
    return eastern_eod_for(created_day)


def betting_open_for(
    *,
    status: str,
    created_at: datetime,
    betting_closes_at: datetime | None = None,
    now: datetime | None = None,
) -> bool:
    """True when new picks are allowed until the selected Eastern end-of-day."""
    if status != "open":
        return False
    moment = now or datetime.now(UTC)
    return _as_utc(moment) < betting_closes_at_for(
        created_at=created_at,
        betting_closes_at=betting_closes_at,
    )


def is_betting_open(question: Question, *, now: datetime | None = None) -> bool:
    return betting_open_for(
        status=question.status,
        created_at=question.created_at,
        betting_closes_at=question.betting_closes_at,
        now=now,
    )


def is_past_question(question: Question, *, now: datetime | None = None) -> bool:
    """Resolved or picking window has ended."""
    if question.status == "resolved":
        return True
    return not is_betting_open(question, now=now)
