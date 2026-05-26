class RoomDiscover {
  const RoomDiscover({
    required this.id,
    required this.personName,
    required this.moderatorName,
    this.isMember = false,
  });

  final String id;
  final String personName;
  final String moderatorName;
  final bool isMember;

  factory RoomDiscover.fromJson(Map<String, dynamic> json) {
    return RoomDiscover(
      id: json['id'] as String,
      personName: json['person_name'] as String,
      moderatorName: json['moderator_name'] as String,
      isMember: json['is_member'] as bool? ?? false,
    );
  }
}
