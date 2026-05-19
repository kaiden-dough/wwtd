import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/models/game_room.dart';
import 'package:wwtd/models/prediction_market.dart';
import 'package:wwtd/providers/app_state.dart';
import 'package:wwtd/widgets/market_card.dart';
import 'package:wwtd/widgets/room_leaderboard_section.dart';

class BettingScreen extends StatelessWidget {
  const BettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final GameRoom? room = appState.selectedRoom;
    final List<PredictionMarket> displayMarkets = appState.displayMarkets;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget mainColumn = ListView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: _buildMainChildren(context, appState, room, displayMarkets),
        );

        if (room == null) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: mainColumn,
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(child: mainColumn),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 280,
                    height: constraints.maxHeight,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 12, right: 14, bottom: 12),
                      child: RoomLeaderboardSection(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMainChildren(
    BuildContext context,
    AppState appState,
    GameRoom? room,
    List<PredictionMarket> displayMarkets,
  ) {
    return <Widget>[
      Text(
        'Room',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showJoinSheet(context, appState),
              icon: const Icon(Icons.vpn_key_outlined, size: 18),
              label: const Text('Join code'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _showCreateRoomSheet(context, appState),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create room'),
            ),
          ),
        ],
      ),
      if (appState.rooms.isNotEmpty) ...<Widget>[
        const SizedBox(height: 14),
        _RoomPicker(
          rooms: appState.rooms,
          selectedId: appState.selectedRoom?.id,
          onChanged: (String id) => appState.selectRoom(id),
        ),
      ],
      if (room != null) ...<Widget>[
        const SizedBox(height: 10),
        if (room.isModerator) ...<Widget>[
          Text(
            'Join code: ${room.joinCode} — share so friends can join',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF1454A7),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton.icon(
          onPressed: () => _showAddQuestionSheet(context, appState),
          icon: const Icon(Icons.help_outline, size: 18),
          label: const Text('Add a question'),
        ),
        const SizedBox(height: 14),
        _BetAmountField(
          value: appState.betAmount,
          onChanged: appState.updateBetAmount,
        ),
        const SizedBox(height: 14),
      ],
      if (room == null)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text(
            'Create a room and share the join code, or enter a code to join someone else\'s.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF607182)),
          ),
        )
      else if (displayMarkets.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'No questions yet. Anyone in the room can add one.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF607182)),
          ),
        )
      else
        ...displayMarkets.map(
          (PredictionMarket market) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MarketCard(market: market),
          ),
        ),
      const SizedBox(height: 24),
    ];
  }
}

Future<void> _showJoinSheet(BuildContext context, AppState appState) async {
  final TextEditingController controller = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Join room',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                labelText: 'Join code',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final GameRoom? joined = await appState.joinRoom(controller.text);
                if (!sheetContext.mounted) {
                  return;
                }
                if (joined != null) {
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Joined room for ${joined.personName}')),
                  );
                } else if (appState.gameError != null) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(appState.gameError!)),
                  );
                }
              },
              child: const Text('Join'),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
}

Future<void> _showCreateRoomSheet(BuildContext context, AppState appState) async {
  final TextEditingController personController = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Create room',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ll get a join code. Members can add their own questions; you moderate and can delete questions (bets are refunded).',
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(color: const Color(0xFF607182)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: personController,
              decoration: const InputDecoration(
                labelText: 'Who is this about?',
                hintText: 'e.g. Alex',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final GameRoom? room = await appState.createRoom(personController.text);
                if (!sheetContext.mounted) {
                  return;
                }
                if (room != null) {
                  Navigator.of(sheetContext).pop();
                  await _showJoinCodeDialog(context, room.joinCode, room.personName);
                } else if (appState.gameError != null) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(appState.gameError!)),
                  );
                }
              },
              child: const Text('Create & get join code'),
            ),
          ],
        ),
      );
    },
  );
  personController.dispose();
}

Future<void> _showAddQuestionSheet(BuildContext context, AppState appState) async {
  final TextEditingController controller = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Add question',
              style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Question',
                hintText: 'Will they ...?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final PredictionMarket? q = await appState.addQuestion(controller.text);
                if (!sheetContext.mounted) {
                  return;
                }
                if (q != null) {
                  Navigator.of(sheetContext).pop();
                } else if (appState.gameError != null) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text(appState.gameError!)),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
}

Future<void> _showJoinCodeDialog(BuildContext context, String code, String personName) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Room created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Room for $personName', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            const Text('Share this join code:'),
            const SizedBox(height: 8),
            SelectableText(
              code,
              style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1454A7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Friends join with this code, then anyone can add questions. You are the moderator.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(color: const Color(0xFF607182)),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

class _RoomPicker extends StatelessWidget {
  const _RoomPicker({
    required this.rooms,
    required this.selectedId,
    required this.onChanged,
  });

  final List<GameRoom> rooms;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedId,
      decoration: const InputDecoration(
        labelText: 'Active room',
        border: OutlineInputBorder(),
      ),
      items: rooms
          .map(
            (GameRoom r) => DropdownMenuItem<String>(
              value: r.id,
              child: Text(
                r.personName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (String? id) {
        if (id != null) {
          onChanged(id);
        }
      },
    );
  }
}

class _BetAmountField extends StatefulWidget {
  const _BetAmountField({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<_BetAmountField> createState() => _BetAmountFieldState();
}

class _BetAmountFieldState extends State<_BetAmountField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toStringAsFixed(0));
  }

  @override
  void didUpdateWidget(covariant _BetAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String next = widget.value.toStringAsFixed(0);
    if (_controller.text != next) {
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Bet amount (points)',
        border: OutlineInputBorder(),
      ),
      onChanged: (String value) {
        final double? parsed = double.tryParse(value);
        if (parsed != null) {
          widget.onChanged(parsed);
        }
      },
    );
  }
}
