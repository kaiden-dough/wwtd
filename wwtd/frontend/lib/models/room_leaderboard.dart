import 'package:wwtd/models/leaderboard_entry.dart';

class RoomLeaderboard {
  const RoomLeaderboard({
    required this.roomId,
    required this.personName,
    required this.entries,
  });

  final String roomId;
  final String personName;
  final List<LeaderboardEntry> entries;

  factory RoomLeaderboard.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['entries'] as List<dynamic>? ?? <dynamic>[];
    return RoomLeaderboard(
      roomId: json['room_id'] as String,
      personName: json['person_name'] as String,
      entries: raw
          .map((dynamic e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
