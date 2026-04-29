import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/data/mock_data.dart';
import 'package:wwtd/models/leaderboard_entry.dart';
import 'package:wwtd/providers/app_state.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool useCards = MediaQuery.sizeOf(context).width < 760;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Leaderboard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'You are currently #${appState.currentUserRank()}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF526170)),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: useCards
                      ? _LeaderboardCards(entries: appState.leaderboard)
                      : _LeaderboardTable(entries: appState.leaderboard),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardCards extends StatelessWidget {
  const _LeaderboardCards({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final LeaderboardEntry entry = entries[index];
        final bool isCurrent = entry.username == currentUsername;
        return Card(
          color: isCurrent ? const Color(0xFFE8F1FE) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isCurrent ? const Color(0xFF1B67C9) : const Color(0xFFE8EEF5),
              child: Text(
                '${index + 1}',
                style: TextStyle(color: isCurrent ? Colors.white : const Color(0xFF334155)),
              ),
            ),
            title: Text(entry.username, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Win rate ${entry.winRate.toStringAsFixed(1)}%'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  entry.isTrendingUp ? Icons.trending_up : Icons.trending_down,
                  color: entry.isTrendingUp ? const Color(0xFF1F9D67) : const Color(0xFFD35A4A),
                ),
                const SizedBox(width: 8),
                Text('${entry.totalPoints}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LeaderboardTable extends StatelessWidget {
  const _LeaderboardTable({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE5EBF2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          headingTextStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          columns: const <DataColumn>[
            DataColumn(label: Text('Rank')),
            DataColumn(label: Text('User')),
            DataColumn(label: Text('Points')),
            DataColumn(label: Text('Win Rate')),
            DataColumn(label: Text('Trend')),
          ],
          rows: entries.asMap().entries.map((MapEntry<int, LeaderboardEntry> row) {
            final int rank = row.key + 1;
            final LeaderboardEntry entry = row.value;
            final bool isCurrent = entry.username == currentUsername;
            final TextStyle? style = Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                  color: isCurrent ? const Color(0xFF154FA0) : null,
                );
            return DataRow(
              color: WidgetStateProperty.resolveWith<Color?>(
                (Set<WidgetState> states) => isCurrent ? const Color(0xFFEFF5FE) : null,
              ),
              cells: <DataCell>[
                DataCell(Text('$rank', style: style)),
                DataCell(Text(entry.username, style: style)),
                DataCell(Text('${entry.totalPoints}', style: style)),
                DataCell(Text('${entry.winRate.toStringAsFixed(1)}%', style: style)),
                DataCell(
                  Icon(
                    entry.isTrendingUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                    size: 20,
                    color: entry.isTrendingUp ? const Color(0xFF1F9D67) : const Color(0xFFD35A4A),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
