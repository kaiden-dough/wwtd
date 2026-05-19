import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/models/leaderboard_entry.dart';
import 'package:wwtd/providers/app_state.dart';

/// Room leaderboard — designed for a sticky side panel.
class RoomLeaderboardSection extends StatelessWidget {
  const RoomLeaderboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final List<LeaderboardEntry> entries = appState.leaderboard;
    final String? personName = appState.selectedRoom?.personName;

    if (personName == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Leaderboard',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              entries.isEmpty
                  ? 'No resolved bets yet.'
                  : '$personName\'s room · you are #${appState.currentUserRank()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF526170)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: entries.isEmpty
                  ? Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        'Resolve questions to rank players.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 6),
                      itemBuilder: (BuildContext context, int index) {
                        final LeaderboardEntry entry = entries[index];
                        final int rank = index + 1;
                        final bool isCurrent =
                            entry.userId != null && entry.userId == appState.user?.id;
                        return _LeaderboardRow(rank: rank, entry: entry, isCurrent: isCurrent);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.isCurrent,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent ? const Color(0xFFE8F1FE) : const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 14,
            backgroundColor: isCurrent ? const Color(0xFF1B67C9) : const Color(0xFFE8EEF5),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isCurrent ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  '${entry.winRate.toStringAsFixed(0)}% wins',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF607182)),
                ),
              ],
            ),
          ),
          Text(
            _formatNet(entry.totalPoints),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: entry.isTrendingUp ? const Color(0xFF1F9D67) : const Color(0xFFD35A4A),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatNet(int points) {
  if (points > 0) {
    return '+$points';
  }
  return '$points';
}
