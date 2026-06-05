class GameRoom {
  const GameRoom({
    required this.id,
    required this.joinCode,
    required this.personName,
    required this.personNames,
    required this.roomType,
    required this.moderatorName,
    required this.isModerator,
    required this.canModerate,
    required this.balancePoints,
  });

  final String id;
  final String joinCode;
  final String personName;
  final List<String> personNames;
  final String roomType;
  final String moderatorName;
  final bool isModerator;
  final bool canModerate;
  final double balancePoints;

  bool get isGroup => roomType == 'group' || personNames.length > 1;

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    return GameRoom(
      id: json['id'] as String,
      joinCode: json['join_code'] as String,
      personName: json['person_name'] as String,
      personNames:
          ((json['person_names'] as List<dynamic>?) ??
                  <dynamic>[json['person_name']])
              .whereType<String>()
              .toList(growable: false),
      roomType: json['room_type'] as String? ?? 'individual',
      moderatorName: json['moderator_name'] as String? ?? '',
      isModerator: json['is_moderator'] as bool? ?? false,
      canModerate: json['can_moderate'] as bool? ?? false,
      balancePoints: (json['balance_points'] as num?)?.toDouble() ?? 500,
    );
  }
}
