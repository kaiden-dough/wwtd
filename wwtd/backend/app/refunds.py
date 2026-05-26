from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Bet, Question
from app.room_balance import credit_room_balance


def refund_question_bets(db: Session, question: Question) -> int:
    """Return all stakes for a question. Returns number of bets refunded."""
    bets = list(db.scalars(select(Bet).where(Bet.question_id == question.id)))
    for bet in bets:
        credit_room_balance(db, question.room_id, bet.user_id, bet.amount)
    return len(bets)
