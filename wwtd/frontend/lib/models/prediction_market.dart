class PredictionMarket {
  PredictionMarket({
    required this.id,
    required this.roomId,
    required this.joinCode,
    required this.person,
    required this.targetNames,
    required this.question,
    required this.yesWageredPoints,
    required this.noWageredPoints,
    required this.createdBy,
    required this.createdAt,
    required this.bettingClosesAt,
    this.isModerator = false,
    this.status = 'open',
    this.winningSide,
    this.bettingOpen = true,
    this.userYesBet = 0,
    this.userNoBet = 0,
    this.pickHistory = const <PickHistoryEntry>[],
  });

  final String id;
  final String roomId;
  final String joinCode;
  final String person;
  final List<String> targetNames;
  final String question;
  final double yesWageredPoints;
  final double noWageredPoints;
  final String createdBy;
  final DateTime createdAt;
  final DateTime bettingClosesAt;
  final bool isModerator;
  final String status;
  final String? winningSide;
  final bool bettingOpen;
  final double userYesBet;
  final double userNoBet;
  final List<PickHistoryEntry> pickHistory;

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved';
  bool get isBettingOpen => isOpen && bettingOpen;
  bool get isPast => isResolved || !bettingOpen;

  double get totalPot => yesWageredPoints + noWageredPoints;
  double get yesPercent =>
      totalPot == 0 ? 50 : (yesWageredPoints / totalPot) * 100;
  double get noPercent =>
      totalPot == 0 ? 50 : (noWageredPoints / totalPot) * 100;

  factory PredictionMarket.fromJson(Map<String, dynamic> json) {
    final DateTime createdAt = DateTime.parse(json['created_at'] as String);
    return PredictionMarket(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      joinCode: json['join_code'] as String,
      person: json['person_name'] as String,
      targetNames:
          ((json['target_names'] as List<dynamic>?) ??
                  <dynamic>[json['person_name']])
              .whereType<String>()
              .toList(growable: false),
      question: json['question'] as String,
      createdBy: json['created_by'] as String,
      isModerator: json['is_moderator'] as bool? ?? false,
      status: json['status'] as String? ?? 'open',
      winningSide: json['winning_side'] as String?,
      createdAt: createdAt,
      bettingClosesAt:
          _parseNullableDateTime(json['betting_closes_at']) ??
          _localEndOfDay(createdAt),
      bettingOpen: json['betting_open'] as bool? ?? true,
      yesWageredPoints: (json['yes_wagered_points'] as num).toDouble(),
      noWageredPoints: (json['no_wagered_points'] as num).toDouble(),
      userYesBet: (json['user_yes_bet'] as num?)?.toDouble() ?? 0,
      userNoBet: (json['user_no_bet'] as num?)?.toDouble() ?? 0,
      pickHistory: ((json['pick_history'] as List<dynamic>?) ?? <dynamic>[])
          .map(
            (dynamic item) =>
                PickHistoryEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  PredictionMarket copyWith({
    double? yesWageredPoints,
    double? noWageredPoints,
    double? userYesBet,
    double? userNoBet,
    String? status,
    String? winningSide,
    bool? bettingOpen,
    bool? isModerator,
    List<PickHistoryEntry>? pickHistory,
    DateTime? bettingClosesAt,
  }) {
    return PredictionMarket(
      id: id,
      roomId: roomId,
      joinCode: joinCode,
      person: person,
      targetNames: targetNames,
      question: question,
      createdBy: createdBy,
      createdAt: createdAt,
      bettingClosesAt: bettingClosesAt ?? this.bettingClosesAt,
      isModerator: isModerator ?? this.isModerator,
      status: status ?? this.status,
      winningSide: winningSide ?? this.winningSide,
      bettingOpen: bettingOpen ?? this.bettingOpen,
      yesWageredPoints: yesWageredPoints ?? this.yesWageredPoints,
      noWageredPoints: noWageredPoints ?? this.noWageredPoints,
      userYesBet: userYesBet ?? this.userYesBet,
      userNoBet: userNoBet ?? this.userNoBet,
      pickHistory: pickHistory ?? this.pickHistory,
    );
  }
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

DateTime _localEndOfDay(DateTime value) {
  final DateTime local = value.toLocal();
  return DateTime(local.year, local.month, local.day + 1);
}

class PickHistoryEntry {
  const PickHistoryEntry({
    required this.side,
    required this.amount,
    required this.createdAt,
  });

  final String side;
  final double amount;
  final DateTime createdAt;

  factory PickHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PickHistoryEntry(
      side: json['side'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
