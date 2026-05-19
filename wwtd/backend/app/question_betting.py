from datetime import UTC, datetime, timedelta

from app.models import Question

BETTING_WINDOW = timedelta(days=1)


def _as_utc(when: datetime) -> datetime:
    if when.tzinfo is None:
        return when.replace(tzinfo=UTC)
    return when.astimezone(UTC)


def betting_open_for(*, status: str, created_at: datetime, now: datetime | None = None) -> bool:
    """True when new bets are allowed (open status and within 24h of creation)."""
    if status != "open":
        return False
    moment = now or datetime.now(UTC)
    return moment - _as_utc(created_at) <= BETTING_WINDOW


def is_betting_open(question: Question, *, now: datetime | None = None) -> bool:
    return betting_open_for(status=question.status, created_at=question.created_at, now=now)


def is_past_question(question: Question, *, now: datetime | None = None) -> bool:
    """Resolved or betting window has ended."""
    if question.status == "resolved":
        return True
    return not is_betting_open(question, now=now)
