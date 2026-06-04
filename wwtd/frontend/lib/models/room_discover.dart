class RoomDiscover {
  const RoomDiscover({
    required this.id,
    required this.personName,
    required this.personNames,
    required this.roomType,
    required this.moderatorName,
    required this.memberCount,
    this.isMember = false,
  });

  final String id;
  final String personName;
  final List<String> personNames;
  final String roomType;
  final String moderatorName;
  final int memberCount;
  final bool isMember;

  factory RoomDiscover.fromJson(Map<String, dynamic> json) {
    return RoomDiscover(
      id: json['id'] as String,
      personName: json['person_name'] as String,
      personNames:
          ((json['person_names'] as List<dynamic>?) ??
                  <dynamic>[json['person_name']])
              .whereType<String>()
              .toList(growable: false),
      roomType: json['room_type'] as String? ?? 'individual',
      moderatorName: json['moderator_name'] as String,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      isMember: json['is_member'] as bool? ?? false,
    );
  }
}
