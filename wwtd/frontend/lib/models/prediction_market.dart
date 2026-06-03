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
    this.isModerator = false,
    this.status = 'open',
    this.winningSide,
    this.bettingOpen = true,
    this.userYesBet = 0,
    this.userNoBet = 0,
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
  final bool isModerator;
  final String status;
  final String? winningSide;
  final bool bettingOpen;
  final double userYesBet;
  final double userNoBet;

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
      createdAt: DateTime.parse(json['created_at'] as String),
      bettingOpen: json['betting_open'] as bool? ?? true,
      yesWageredPoints: (json['yes_wagered_points'] as num).toDouble(),
      noWageredPoints: (json['no_wagered_points'] as num).toDouble(),
      userYesBet: (json['user_yes_bet'] as num?)?.toDouble() ?? 0,
      userNoBet: (json['user_no_bet'] as num?)?.toDouble() ?? 0,
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
      isModerator: isModerator ?? this.isModerator,
      status: status ?? this.status,
      winningSide: winningSide ?? this.winningSide,
      bettingOpen: bettingOpen ?? this.bettingOpen,
      yesWageredPoints: yesWageredPoints ?? this.yesWageredPoints,
      noWageredPoints: noWageredPoints ?? this.noWageredPoints,
      userYesBet: userYesBet ?? this.userYesBet,
      userNoBet: userNoBet ?? this.userNoBet,
    );
  }
}
