import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/models/game_room.dart';
import 'package:wwtd/models/room_discover.dart';
import 'package:wwtd/providers/app_state.dart';

Future<void> showJoinRoomSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return const Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: _JoinRoomSheet(),
      );
    },
  );
}

class _JoinRoomSheet extends StatefulWidget {
  const _JoinRoomSheet();

  @override
  State<_JoinRoomSheet> createState() => _JoinRoomSheetState();
}

class _JoinRoomSheetState extends State<_JoinRoomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  Timer? _debounce;
  List<RoomDiscover> _results = <RoomDiscover>[];
  RoomDiscover? _selected;
  bool _searching = false;
  bool _joining = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String query) async {
    if (!mounted) {
      return;
    }
    final String term = query.trim();
    if (term.isEmpty) {
      setState(() {
        _results = <RoomDiscover>[];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final AppState appState = context.read<AppState>();
    final List<RoomDiscover> found = await appState.searchRooms(term);
    if (!mounted) {
      return;
    }
    setState(() {
      _results = found;
      _searching = false;
      if (_selected != null &&
          !found.any((RoomDiscover r) => r.id == _selected!.id)) {
        _selected = null;
      }
    });
  }

  Future<void> _submitJoin() async {
    setState(() => _joining = true);
    final AppState appState = context.read<AppState>();
    final GameRoom? joined = await appState.joinRoom(
      joinCode: _codeController.text,
      roomId: _selected?.id,
    );
    if (!mounted) {
      return;
    }
    setState(() => _joining = false);
    if (joined != null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined ${joined.personName}\'s room')),
      );
    } else if (appState.gameError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(appState.gameError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canJoin = _codeController.text.trim().length >= 4;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        width: 520,
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Join room',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a room, then enter the join code from the moderator.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search rooms',
                hintText: 'Name or moderator',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults()),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              obscureText: true,
              autocorrect: false,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: InputDecoration(
                labelText: 'Join code',
                hintText: _selected != null
                    ? 'Code for ${_selected!.personName}\'s room'
                    : 'Ask the moderator for the code',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: canJoin && !_joining ? _submitJoin : null,
              child: _joining
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _selected?.isMember == true ? 'Open room' : 'Join room',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Text(
          'Search by who the room is about or the moderator\'s username.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No rooms found.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
        ),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final RoomDiscover room = _results[index];
        final bool selected = _selected?.id == room.id;
        return Material(
          color: selected ? const Color(0xFFE8F1FE) : const Color(0xFFF5F8FC),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _selected = room),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: <Widget>[
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: const Color(0xFF165AB0),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          room.personName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          'Moderator: ${room.moderatorName}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: const Color(0xFF607182)),
                        ),
                        if (room.isMember)
                          Text(
                            'Already in room',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: const Color(0xFF1454A7),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                      ],
                    ),
                  ),
                  if (room.isMember)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F1FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Already in room',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1454A7),
                        ),
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
}
