import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/models/game_room.dart';
import 'package:wwtd/models/prediction_market.dart';
import 'package:wwtd/providers/app_state.dart';
import 'package:wwtd/widgets/join_room_sheet.dart';
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
        final Widget questionsColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (room != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: _MarketBar(
                  onAddQuestion: () => _showAddQuestionSheet(context, appState),
                ),
              ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(14, room != null ? 12 : 12, 14, 12),
                children: _buildQuestionChildren(context, room, displayMarkets),
              ),
            ),
          ],
        );

        if (room == null) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                children: <Widget>[
                  _RoomSidebar(appState: appState, room: room),
                  if (room != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _MarketBar(
                      onAddQuestion: () =>
                          _showAddQuestionSheet(context, appState),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ..._buildQuestionChildren(context, room, displayMarkets),
                ],
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 270,
                    height: constraints.maxHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 14,
                        top: 12,
                        bottom: 12,
                      ),
                      child: _RoomSidebar(appState: appState, room: room),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: questionsColumn),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 280,
                    height: constraints.maxHeight,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 12, right: 14, bottom: 12),
                      child: SizedBox.expand(child: RoomLeaderboardSection()),
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

  List<Widget> _buildQuestionChildren(
    BuildContext context,
    GameRoom? room,
    List<PredictionMarket> displayMarkets,
  ) {
    return <Widget>[
      if (room == null)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Text(
            'Create a room and share the join code, or enter a code to join someone else\'s.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF607182)),
          ),
        )
      else if (displayMarkets.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'No questions yet. Anyone in the room can add one.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF607182)),
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

class _RoomSidebar extends StatelessWidget {
  const _RoomSidebar({required this.appState, required this.room});

  final AppState appState;
  final GameRoom? room;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showJoinRoomSheet(context),
                    icon: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('Join'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _showCreateRoomSheet(context, appState),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create'),
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
              if (room!.isModerator) ...<Widget>[
                Text(
                  'Join code: ${room!.joinCode}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF1454A7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Toolbar above the question list in the center column.
class _MarketBar extends StatelessWidget {
  const _MarketBar({required this.onAddQuestion});

  final VoidCallback onAddQuestion;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Center(
          child: FilledButton.icon(
            onPressed: onAddQuestion,
            icon: const Icon(Icons.add_comment_outlined, size: 18),
            label: const Text(
              'Add question',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showCreateRoomSheet(
  BuildContext context,
  AppState appState,
) async {
  final TextEditingController personController = TextEditingController();
  bool isGroup = false;
  await showDialog<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: StatefulBuilder(
          builder: (BuildContext sheetContext, StateSetter setSheetState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Create room',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You\'ll get a join code. Members can add their own questions; you moderate and can delete questions (bets are refunded).',
                      style: Theme.of(sheetContext).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF607182)),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const <ButtonSegment<bool>>[
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.person_outline),
                          label: Text('Individual'),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.groups_outlined),
                          label: Text('Group'),
                        ),
                      ],
                      selected: <bool>{isGroup},
                      onSelectionChanged: (Set<bool> value) {
                        setSheetState(() {
                          isGroup = value.first;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: personController,
                      decoration: InputDecoration(
                        labelText: isGroup
                            ? 'People in this room'
                            : 'Who is this about?',
                        hintText: isGroup
                            ? 'e.g. Bob, Josh, Dillon'
                            : 'e.g. Alex',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        final List<String> people = personController.text
                            .split(',')
                            .map((String value) => value.trim())
                            .where((String value) => value.isNotEmpty)
                            .toList(growable: false);
                        final GameRoom? room = await appState.createRoom(
                          personNames: people,
                          isGroup: isGroup,
                        );
                        if (!sheetContext.mounted) {
                          return;
                        }
                        if (room != null) {
                          Navigator.of(sheetContext).pop();
                          await _showJoinCodeDialog(
                            context,
                            room.joinCode,
                            room.personName,
                          );
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
              ),
            );
          },
        ),
      );
    },
  );
  personController.dispose();
}

Future<void> _showAddQuestionSheet(
  BuildContext context,
  AppState appState,
) async {
  final TextEditingController controller = TextEditingController();
  final GameRoom? room = appState.selectedRoom;
  final List<String> people = room?.personNames ?? <String>[];
  final Set<String> selectedTargets = <String>{...people};
  await showDialog<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: StatefulBuilder(
          builder: (BuildContext sheetContext, StateSetter setSheetState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Add question',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
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
                    if (people.length > 1) ...<Widget>[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: people
                            .map(
                              (String person) => FilterChip(
                                label: Text(person),
                                selected: selectedTargets.contains(person),
                                onSelected: (bool selected) {
                                  setSheetState(() {
                                    if (selected) {
                                      selectedTargets.add(person);
                                    } else {
                                      selectedTargets.remove(person);
                                    }
                                  });
                                },
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (people.length > 1 && selectedTargets.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('Pick at least one person'),
                            ),
                          );
                          return;
                        }
                        final PredictionMarket? q = await appState.addQuestion(
                          controller.text,
                          targetNames: selectedTargets.toList(growable: false),
                        );
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
              ),
            );
          },
        ),
      );
    },
  );
  controller.dispose();
}

Future<void> _showJoinCodeDialog(
  BuildContext context,
  String code,
  String personName,
) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Room created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Room for $personName',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
              style: Theme.of(
                dialogContext,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF607182)),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Code copied')));
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

  static const TextStyle _moderatorStyle = TextStyle(
    color: Color(0xFF165AB0),
    fontWeight: FontWeight.w600,
    fontSize: 13,
  );

  @override
  Widget build(BuildContext context) {
    final List<GameRoom> sorted = List<GameRoom>.from(rooms)
      ..sort((GameRoom a, GameRoom b) {
        if (a.isModerator != b.isModerator) {
          return a.isModerator ? -1 : 1;
        }
        return a.personName.compareTo(b.personName);
      });

    final String? value =
        selectedId != null && sorted.any((GameRoom r) => r.id == selectedId)
        ? selectedId
        : null;

    return DropdownButtonFormField<String>(
      // Controlled selection when rooms load or change from AppState.
      // ignore: deprecated_member_use
      value: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Active room',
        border: OutlineInputBorder(),
      ),
      selectedItemBuilder: (BuildContext context) {
        return sorted
            .map(
              (GameRoom r) => SizedBox(
                width: double.infinity,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _selectedRoomLabel(r),
                ),
              ),
            )
            .toList();
      },
      items: sorted
          .map(
            (GameRoom r) => DropdownMenuItem<String>(
              value: r.id,
              child: _dropdownRoomLabel(r),
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

  Widget _selectedRoomLabel(GameRoom room) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
        children: <InlineSpan>[
          TextSpan(
            text: room.personName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: ' · '),
          TextSpan(text: room.moderatorName, style: _moderatorStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _dropdownRoomLabel(GameRoom room) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          room.personName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        if (room.isModerator) ...<Widget>[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'You moderate',
              style: TextStyle(
                color: Color(0xFF1454A7),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 2),
        Text(
          room.isModerator
              ? 'Moderator: You'
              : 'Moderator: ${room.moderatorName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _moderatorStyle,
        ),
      ],
    );
  }
}
