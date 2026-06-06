import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/models/game_room.dart';
import 'package:wwtd/models/prediction_market.dart';
import 'package:wwtd/providers/app_state.dart';
import 'package:wwtd/utils/app_snack_bar.dart';
import 'package:wwtd/utils/clipboard_copy.dart';
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
        final bool compact = constraints.maxWidth < 900;
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
                padding: EdgeInsets.fromLTRB(
                  14,
                  room != null ? 12 : 12,
                  14,
                  12,
                ),
                children: _buildQuestionChildren(context, room, displayMarkets),
              ),
            ),
          ],
        );

        if (compact) {
          return DefaultTabController(
            length: 3,
            initialIndex: 1,
            child: Column(
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const TabBar(
                    tabs: <Widget>[
                      Tab(icon: Icon(Icons.tune_outlined), text: 'Room'),
                      Tab(icon: Icon(Icons.forum_outlined), text: 'Markets'),
                      Tab(
                        icon: Icon(Icons.leaderboard_outlined),
                        text: 'Leaderboard',
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: _RoomSidebar(appState: appState, room: room),
                      ),
                      _MobileMarketsTab(
                        room: room,
                        displayMarkets: displayMarkets,
                        onAddQuestion: () =>
                            _showAddQuestionSheet(context, appState),
                        buildQuestionChildren: _buildQuestionChildren,
                      ),
                      const Padding(
                        padding: EdgeInsets.all(14),
                        child: RoomLeaderboardSection(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

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
              if (room!.canModerate) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Join code: ${room!.joinCode}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF1454A7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final bool copied = await copyTextToClipboard(
                            room!.joinCode,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          if (copied) {
                            showAppSnackBar(
                              context,
                              const SnackBar(content: Text('Join code copied')),
                            );
                          } else {
                            await _showManualCopyCodeDialog(
                              context,
                              room!.joinCode,
                            );
                          }
                        } catch (_) {
                          if (!context.mounted) {
                            return;
                          }
                          await _showManualCopyCodeDialog(
                            context,
                            room!.joinCode,
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('Copy'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 34),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showEditRoomSheet(context, appState, room!),
                    icon: const Icon(Icons.tune_outlined, size: 18),
                    label: const Text('Room settings'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () =>
                        _confirmDeleteRoom(context, appState, room!),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete room'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFB24338),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _shareRoomLink(context, room!),
                  icon: const Icon(Icons.ios_share_outlined, size: 18),
                  label: const Text('Share room link'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _shareRoomLink(BuildContext context, GameRoom room) async {
  final Uri current = Uri.base;
  final Uri link = current.replace(
    path: current.path.isEmpty ? '/' : current.path,
    queryParameters: <String, String>{'room': room.id},
    fragment: '',
  );
  try {
    final bool copied = await copyTextToClipboard(link.toString());
    if (!context.mounted) {
      return;
    }
    if (copied) {
      showAppSnackBar(
        context,
        const SnackBar(content: Text('Room link copied')),
      );
    } else {
      await _showManualCopyCodeDialog(
        context,
        link.toString(),
        label: 'room link',
      );
    }
  } catch (_) {
    if (!context.mounted) {
      return;
    }
    await _showManualCopyCodeDialog(
      context,
      link.toString(),
      label: 'room link',
    );
  }
}

class _MobileMarketsTab extends StatelessWidget {
  const _MobileMarketsTab({
    required this.room,
    required this.displayMarkets,
    required this.onAddQuestion,
    required this.buildQuestionChildren,
  });

  final GameRoom? room;
  final List<PredictionMarket> displayMarkets;
  final VoidCallback onAddQuestion;
  final List<Widget> Function(
    BuildContext context,
    GameRoom? room,
    List<PredictionMarket> displayMarkets,
  )
  buildQuestionChildren;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (room != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: _MarketBar(onAddQuestion: onAddQuestion),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            children: buildQuestionChildren(context, room, displayMarkets),
          ),
        ),
      ],
    );
  }
}

/// Toolbar above the question list in the center column.
class _MarketBar extends StatelessWidget {
  const _MarketBar({required this.onAddQuestion});

  final VoidCallback onAddQuestion;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onAddQuestion,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        icon: const Icon(Icons.add_comment_outlined, size: 20),
        label: const Text(
          'Add question',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

Widget _roomPeopleFields({
  required bool isGroup,
  required List<TextEditingController> controllers,
  required StateSetter setSheetState,
}) {
  if (!isGroup) {
    return TextField(
      controller: controllers.first,
      decoration: const InputDecoration(
        labelText: 'Who is this about?',
        hintText: 'e.g. Alex',
        border: OutlineInputBorder(),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int index = 0; index < controllers.length; index++) ...<Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controllers[index],
                decoration: InputDecoration(
                  labelText: 'Person ${index + 1}',
                  hintText: index == 0
                      ? 'e.g. Bob'
                      : index == 1
                      ? 'e.g. Josh'
                      : 'e.g. Dillon',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (controllers.length > 2) ...<Widget>[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove person',
                onPressed: () {
                  final TextEditingController removed = controllers.removeAt(
                    index,
                  );
                  removed.dispose();
                  setSheetState(() {});
                },
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ],
        ),
        if (index != controllers.length - 1) const SizedBox(height: 10),
      ],
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () {
          controllers.add(TextEditingController());
          setSheetState(() {});
        },
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add person'),
      ),
    ],
  );
}

List<String> _peopleFromControllers(
  List<TextEditingController> controllers, {
  required bool isGroup,
}) {
  final Iterable<TextEditingController> activeControllers = isGroup
      ? controllers
      : controllers.take(1);
  return activeControllers
      .map((TextEditingController controller) => controller.text.trim())
      .where((String value) => value.isNotEmpty)
      .toList(growable: false);
}

void _ensureGroupPersonInputs(
  List<TextEditingController> controllers, {
  required int minimum,
}) {
  while (controllers.length < minimum) {
    controllers.add(TextEditingController());
  }
}

Future<void> _showCreateRoomSheet(
  BuildContext context,
  AppState appState,
) async {
  final List<TextEditingController> personControllers = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];
  final TextEditingController joinCodeController = TextEditingController();
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
                      'You\'ll get a join code. Members can add their own questions; you moderate and can delete questions.',
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
                          if (isGroup) {
                            _ensureGroupPersonInputs(
                              personControllers,
                              minimum: 2,
                            );
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _roomPeopleFields(
                      isGroup: isGroup,
                      controllers: personControllers,
                      setSheetState: setSheetState,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: joinCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Custom join code',
                        hintText: 'Optional, 4-8 letters or numbers',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        final List<String> people = _peopleFromControllers(
                          personControllers,
                          isGroup: isGroup,
                        );
                        final GameRoom? room = await appState.createRoom(
                          personNames: people,
                          isGroup: isGroup,
                          joinCode: joinCodeController.text,
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
                          showAppSnackBar(
                            sheetContext,
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
  for (final TextEditingController controller in personControllers) {
    controller.dispose();
  }
  joinCodeController.dispose();
}

Future<void> _showEditRoomSheet(
  BuildContext context,
  AppState appState,
  GameRoom room,
) async {
  final List<String> initialPeople = room.personNames.isEmpty
      ? <String>['']
      : room.personNames;
  final List<TextEditingController> personControllers = initialPeople
      .map((String person) => TextEditingController(text: person))
      .toList(growable: true);
  _ensureGroupPersonInputs(personControllers, minimum: room.isGroup ? 2 : 1);
  final TextEditingController joinCodeController = TextEditingController(
    text: room.joinCode,
  );
  bool isGroup = room.isGroup;
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
                      'Room settings',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
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
                          if (isGroup) {
                            _ensureGroupPersonInputs(
                              personControllers,
                              minimum: 2,
                            );
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    _roomPeopleFields(
                      isGroup: isGroup,
                      controllers: personControllers,
                      setSheetState: setSheetState,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: joinCodeController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Join code',
                        hintText: '4-8 letters or numbers',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        final List<String> people = _peopleFromControllers(
                          personControllers,
                          isGroup: isGroup,
                        );
                        final GameRoom? updated = await appState.updateRoom(
                          roomId: room.id,
                          personNames: people,
                          isGroup: isGroup,
                          joinCode: joinCodeController.text,
                        );
                        if (!sheetContext.mounted) {
                          return;
                        }
                        if (updated != null) {
                          Navigator.of(sheetContext).pop();
                          showAppSnackBar(
                            context,
                            const SnackBar(content: Text('Room updated')),
                          );
                        } else if (appState.gameError != null) {
                          showAppSnackBar(
                            sheetContext,
                            SnackBar(content: Text(appState.gameError!)),
                          );
                        }
                      },
                      child: const Text('Save room'),
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
  for (final TextEditingController controller in personControllers) {
    controller.dispose();
  }
  joinCodeController.dispose();
}

Future<void> _confirmDeleteRoom(
  BuildContext context,
  AppState appState,
  GameRoom room,
) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Delete room?'),
        content: Text(
          '${room.personName} will be removed. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB24338),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }

  final bool ok = await appState.deleteRoom(room.id);
  if (!context.mounted) {
    return;
  }
  if (ok) {
    showAppSnackBar(context, const SnackBar(content: Text('Room deleted')));
  } else if (appState.gameError != null) {
    showAppSnackBar(context, SnackBar(content: Text(appState.gameError!)));
  }
}

Future<void> _showAddQuestionSheet(
  BuildContext context,
  AppState appState,
) async {
  final GameRoom? room = appState.selectedRoom;
  final List<String> people = room?.personNames ?? <String>[];
  final Set<String> selectedTargets = <String>{...people};
  List<String> selectedTargetNames() => people
      .where((String person) => selectedTargets.contains(person))
      .toList(growable: false);
  String questionLead() =>
      'Will ${_formatQuestionTargets(selectedTargetNames())}';
  final TextEditingController controller = TextEditingController();
  DateTime expiryDate = DateTime.now();

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            questionLead(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(sheetContext).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            autofocus: true,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              hintText: 'order pizza',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '?',
                          style: Theme.of(sheetContext).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
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
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: _dateOnly(expiryDate),
                          firstDate: DateTime(now.year, now.month, now.day),
                          lastDate: now.add(const Duration(days: 365)),
                        );
                        if (!sheetContext.mounted || picked == null) {
                          return;
                        }
                        setSheetState(() {
                          expiryDate = _dateOnly(picked);
                        });
                      },
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        'Expires EOD Eastern: ${_formatDate(expiryDate)}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        if (people.length > 1 && selectedTargets.isEmpty) {
                          showAppSnackBar(
                            sheetContext,
                            const SnackBar(
                              content: Text('Pick at least one person'),
                            ),
                          );
                          return;
                        }
                        final String questionMiddle = controller.text.trim();
                        if (questionMiddle.isEmpty) {
                          showAppSnackBar(
                            sheetContext,
                            const SnackBar(
                              content: Text('Add the question text'),
                            ),
                          );
                          return;
                        }
                        final String questionBody = questionMiddle.replaceAll(
                          RegExp(r'\?+$'),
                          '',
                        );
                        final String question =
                            '${questionLead()} $questionBody?';
                        final PredictionMarket? q = await appState.addQuestion(
                          question,
                          targetNames: selectedTargets.toList(growable: false),
                          expiresOn: expiryDate,
                        );
                        if (!sheetContext.mounted) {
                          return;
                        }
                        if (q != null) {
                          Navigator.of(sheetContext).pop();
                        } else if (appState.gameError != null) {
                          showAppSnackBar(
                            sheetContext,
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

String _formatQuestionTargets(List<String> names) {
  if (names.isEmpty) {
    return 'they';
  }
  if (names.length == 1) {
    return names.single;
  }
  if (names.length == 2) {
    return '${names[0]} and ${names[1]}';
  }
  return '${names.take(names.length - 1).join(', ')}, and ${names.last}';
}

String _formatDate(DateTime value) {
  return '${value.month}/${value.day}/${value.year}';
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
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
            onPressed: () async {
              try {
                final bool copied = await copyTextToClipboard(code);
                if (!context.mounted) {
                  return;
                }
                if (copied) {
                  showAppSnackBar(
                    context,
                    const SnackBar(content: Text('Code copied')),
                  );
                } else {
                  await _showManualCopyCodeDialog(context, code);
                }
              } catch (_) {
                if (!context.mounted) {
                  return;
                }
                await _showManualCopyCodeDialog(context, code);
              }
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

Future<void> _showManualCopyCodeDialog(
  BuildContext context,
  String value, {
  String label = 'join code',
}) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('Copy $label'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Clipboard access is blocked in this browser.'),
            const SizedBox(height: 12),
            SelectableText(
              value,
              style: Theme.of(dialogContext).textTheme.headlineSmall?.copyWith(
                letterSpacing: label == 'join code' ? 3 : 0,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1454A7),
              ),
            ),
          ],
        ),
        actions: <Widget>[
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
