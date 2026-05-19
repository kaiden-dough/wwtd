from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Bet, Profile, Question


def refund_question_bets(db: Session, question: Question) -> int:
    """Return all stakes for a question. Returns number of bets refunded."""
    bets = list(db.scalars(select(Bet).where(Bet.question_id == question.id)))
    for bet in bets:
        profile = db.get(Profile, bet.user_id)
        if profile is not None:
            profile.balance_points += bet.amount
    return len(bets)
