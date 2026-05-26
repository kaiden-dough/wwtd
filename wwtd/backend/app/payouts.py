from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import Bet, Question
from app.room_balance import credit_room_balance


def resolve_question(db: Session, question: Question, winning_side: str) -> None:
    """Parimutuel payout: winning side splits the full pool by stake share."""
    side = winning_side.lower()
    if side not in ("yes", "no"):
        raise ValueError("winning_side must be yes or no")

    bets = list(db.scalars(select(Bet).where(Bet.question_id == question.id)))
    total_pool = sum(b.amount for b in bets)
    winning_pool = sum(b.amount for b in bets if b.side == side)

    for bet in bets:
        if winning_pool <= 0:
            credit_room_balance(db, question.room_id, bet.user_id, bet.amount)
            bet.payout_amount = bet.amount
        elif bet.side == side:
            payout = total_pool * (bet.amount / winning_pool)
            credit_room_balance(db, question.room_id, bet.user_id, payout)
            bet.payout_amount = payout
        else:
            bet.payout_amount = 0.0

    question.status = "resolved"
    question.winning_side = side
