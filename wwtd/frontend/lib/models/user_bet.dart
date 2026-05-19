class UserBet {
  const UserBet({
    required this.id,
    required this.roomId,
    required this.marketQuestion,
    required this.personName,
    required this.side,
    required this.amount,
    required this.marketStatus,
    this.payoutAmount,
    this.winningSide,
  });

  final int id;
  final String roomId;
  final String marketQuestion;
  final String personName;
  final String side;
  final double amount;
  final double? payoutAmount;
  final String marketStatus;
  final String? winningSide;

  factory UserBet.fromJson(Map<String, dynamic> json) {
    return UserBet(
      id: json['id'] as int,
      roomId: json['room_id'] as String? ?? '',
      marketQuestion: json['market_question'] as String,
      personName: json['person_name'] as String,
      side: json['side'] as String,
      amount: (json['amount'] as num).toDouble(),
      payoutAmount: (json['payout_amount'] as num?)?.toDouble(),
      marketStatus: json['market_status'] as String,
      winningSide: json['winning_side'] as String?,
    );
  }
}
