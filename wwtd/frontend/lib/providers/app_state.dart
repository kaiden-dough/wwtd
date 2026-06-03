import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wwtd/config/api_config.dart';
import 'package:wwtd/models/game_room.dart';
import 'package:wwtd/models/room_discover.dart';
import 'package:wwtd/models/leaderboard_entry.dart';
import 'package:wwtd/models/room_leaderboard.dart';
import 'package:wwtd/models/prediction_market.dart';
import 'package:wwtd/models/user_bet.dart';
import 'package:wwtd/models/user_profile.dart';
import 'package:wwtd/services/api_client.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? apiClient}) : _api = apiClient ?? ApiClient() {
    _init();
  }

  static const String _tokenKey = 'auth_token';

  final ApiClient _api;

  String? _selectedRoomId;
  static const double _defaultPickWeight = 1;
  List<GameRoom> _rooms = <GameRoom>[];
  List<PredictionMarket> _questions = <PredictionMarket>[];
  List<RoomLeaderboard> _roomLeaderboards = <RoomLeaderboard>[];
  List<UserBet> _myBets = <UserBet>[];

  UserProfile? _user;
  bool _sessionReady = false;
  bool _authLoading = false;
  bool _gameLoading = false;
  String? _authError;
  String? _gameError;
  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get sessionReady => _sessionReady;
  bool get authLoading => _authLoading == true;
  bool get gameLoading => _gameLoading == true;
  String? get authError => _authError;
  String? get gameError => _gameError;
  List<UserBet> get myBets => _myBets;

  List<GameRoom> get rooms => _rooms;
  List<PredictionMarket> get questions => _questions;

  GameRoom? get selectedRoom {
    if (_selectedRoomId == null) {
      return null;
    }
    for (final GameRoom room in _rooms) {
      if (room.id == _selectedRoomId) {
        return room;
      }
    }
    return null;
  }

  String get selectedPerson => selectedRoom?.personName ?? 'they';
  List<PredictionMarket> get displayMarkets {
    final List<PredictionMarket> sorted = List<PredictionMarket>.from(
      _questions,
    );
    sorted.sort((PredictionMarket a, PredictionMarket b) {
      final int pastCmp = (a.isPast ? 1 : 0).compareTo(b.isPast ? 1 : 0);
      if (pastCmp != 0) {
        return pastCmp;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  /// Bets for the currently selected room only.
  List<UserBet> get roomBets {
    if (_selectedRoomId == null) {
      return <UserBet>[];
    }
    final List<UserBet> bets = _myBets
        .where((UserBet b) => b.roomId == _selectedRoomId)
        .toList();
    bets.sort((UserBet a, UserBet b) {
      final int pastCmp = (a.isPast ? 1 : 0).compareTo(b.isPast ? 1 : 0);
      if (pastCmp != 0) {
        return pastCmp;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return bets;
  }

  List<RoomLeaderboard> get roomLeaderboards => _roomLeaderboards;

  List<LeaderboardEntry> get leaderboard {
    if (_selectedRoomId == null) {
      return <LeaderboardEntry>[];
    }
    for (final RoomLeaderboard board in _roomLeaderboards) {
      if (board.roomId == _selectedRoomId) {
        return board.entries;
      }
    }
    return <LeaderboardEntry>[];
  }

  Future<void> _init() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString(_tokenKey);
      if (token != null && token.isNotEmpty) {
        _api.setToken(token);
        await _restoreSession(prefs);
      }
    } finally {
      _sessionReady = true;
      notifyListeners();
    }
  }

  Future<void> _restoreSession(SharedPreferences prefs) async {
    _setAuthLoading(true);
    try {
      await _refreshGameData();
      _authError = null;
    } catch (_) {
      await prefs.remove(_tokenKey);
      _api.setToken(null);
      _user = null;
      _clearGameData();
    } finally {
      _setAuthLoading(false);
    }
  }

  Future<void> _refreshGameData({bool skipProfile = false}) async {
    _setGameLoading(true);
    try {
      final Future<UserProfile>? profileFuture = skipProfile
          ? null
          : _api.fetchMe();
      final Future<List<GameRoom>> roomsFuture = _api.fetchRooms();
      final Future<List<UserBet>> betsFuture = _api.fetchMyBets();

      if (profileFuture != null) {
        final List<dynamic> batch = await Future.wait<dynamic>(
          <Future<dynamic>>[profileFuture, roomsFuture, betsFuture],
        );
        _user = batch[0] as UserProfile;
        _rooms = batch[1] as List<GameRoom>;
        _myBets = batch[2] as List<UserBet>;
      } else {
        final List<dynamic> batch = await Future.wait<dynamic>(
          <Future<dynamic>>[roomsFuture, betsFuture],
        );
        _rooms = batch[0] as List<GameRoom>;
        _myBets = batch[1] as List<UserBet>;
      }

      _gameError = null;
      _ensureSelectedRoomValid();
      await _loadRoomContext();
    } finally {
      _setGameLoading(false);
    }
  }

  Future<void> _loadLeaderboardForRoom(String roomId) async {
    final List<RoomLeaderboard> boards = await _api.fetchLeaderboard(
      roomId: roomId,
    );
    if (boards.isEmpty) {
      return;
    }
    final RoomLeaderboard board = boards.first;
    final int index = _roomLeaderboards.indexWhere(
      (RoomLeaderboard b) => b.roomId == roomId,
    );
    if (index == -1) {
      _roomLeaderboards = <RoomLeaderboard>[..._roomLeaderboards, board];
    } else {
      final List<RoomLeaderboard> updated = List<RoomLeaderboard>.from(
        _roomLeaderboards,
      );
      updated[index] = board;
      _roomLeaderboards = updated;
    }
  }

  Future<void> _loadRoomContext() async {
    if (_selectedRoomId == null) {
      _questions = <PredictionMarket>[];
      return;
    }
    await Future.wait<void>(<Future<void>>[
      _loadQuestionsForSelectedRoom(),
      _loadLeaderboardForRoom(_selectedRoomId!),
    ]);
  }

  void _clearGameData() {
    _rooms = <GameRoom>[];
    _questions = <PredictionMarket>[];
    _roomLeaderboards = <RoomLeaderboard>[];
    _myBets = <UserBet>[];
    _selectedRoomId = null;
  }

  void _ensureSelectedRoomValid() {
    if (_rooms.isEmpty) {
      _selectedRoomId = null;
      return;
    }
    if (_selectedRoomId == null ||
        !_rooms.any((GameRoom r) => r.id == _selectedRoomId)) {
      _selectedRoomId = _rooms.first.id;
    }
  }

  Future<void> _refreshRooms() async {
    _rooms = await _api.fetchRooms();
    _ensureSelectedRoomValid();
  }

  Future<void> _loadQuestionsForSelectedRoom() async {
    if (_selectedRoomId == null) {
      _questions = <PredictionMarket>[];
      return;
    }
    _questions = await _api.fetchRoomQuestions(_selectedRoomId!);
  }

  Future<void> selectRoom(String roomId) async {
    if (_selectedRoomId == roomId) {
      return;
    }
    _selectedRoomId = roomId;
    _setGameLoading(true);
    try {
      await _loadRoomContext();
    } finally {
      _setGameLoading(false);
    }
    notifyListeners();
  }

  Future<({bool available, String? message})> checkUsername(
    String username,
  ) async {
    return _api.checkUsername(username);
  }

  Future<void> register({
    required String username,
    required String password,
  }) async {
    final String? validationError = _validateCredentials(username, password);
    if (validationError != null) {
      _authError = validationError;
      notifyListeners();
      return;
    }

    await _authenticate(
      () => _api.register(username: username, password: password),
    );
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final String? validationError = _validateCredentials(username, password);
    if (validationError != null) {
      _authError = validationError;
      notifyListeners();
      return;
    }

    await _authenticate(
      () => _api.login(username: username, password: password),
    );
  }

  Future<void> adminLogin() async {
    await _authenticate(() => _api.adminLogin());
  }

  Future<void> _authenticate(Future<UserProfile> Function() request) async {
    _setAuthLoading(true);
    _authError = null;
    notifyListeners();

    try {
      final UserProfile profile = await request();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = _api.token ?? '';
      if (token.isNotEmpty) {
        await prefs.setString(_tokenKey, token);
      }
      _user = profile;
      notifyListeners();
      _setAuthLoading(false);
      await _refreshGameData(skipProfile: true);
    } on ApiException catch (e) {
      _authError = e.message;
      _setAuthLoading(false);
      notifyListeners();
    } on http.ClientException {
      _authError = _offlineMessage;
      _setAuthLoading(false);
      notifyListeners();
    } catch (e) {
      _authError = 'Sign-in failed: $e';
      _setAuthLoading(false);
      notifyListeners();
    }
  }

  Future<bool> completeDisplayName(String displayName) async {
    final String name = displayName.trim();
    if (name.isEmpty) {
      _authError = 'Enter a display name';
      notifyListeners();
      return false;
    }
    if (!isLoggedIn) {
      return false;
    }

    _setAuthLoading(true);
    _authError = null;
    notifyListeners();

    try {
      _user = await _api.updateDisplayName(name);
      await _refreshGameData();
      _authError = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _authError = e.message;
      notifyListeners();
      return false;
    } on http.ClientException {
      _authError = _offlineMessage;
      notifyListeners();
      return false;
    } catch (e) {
      _authError = 'Could not save name: $e';
      notifyListeners();
      return false;
    } finally {
      _setAuthLoading(false);
    }
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _api.setToken(null);
    _user = null;
    _authError = null;
    _gameError = null;
    _clearGameData();
    notifyListeners();
  }

  void clearAuthError() {
    if (_authError == null) {
      return;
    }
    _authError = null;
    notifyListeners();
  }

  void clearGameError() {
    if (_gameError == null) {
      return;
    }
    _gameError = null;
    notifyListeners();
  }

  String? _validateCredentials(String username, String password) {
    final String normalized = username.trim().toLowerCase();
    if (!RegExp(r'^[a-zA-Z0-9_]{3,32}$').hasMatch(normalized)) {
      return 'Username must be 3–32 characters: letters, numbers, underscore only';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String get _offlineMessage =>
      'Cannot reach the API at ${ApiConfig.baseUrl}. Start the server with: '
      'python -m uvicorn app.main:app --reload --port 8000';

  void _setAuthLoading(bool value) {
    _authLoading = value;
    notifyListeners();
  }

  void _setGameLoading(bool value) {
    _gameLoading = value;
    notifyListeners();
  }

  Future<bool> placeBet({required String marketId, required bool isYes}) async {
    if (!isLoggedIn) {
      _gameError = 'Sign in to place bets';
      notifyListeners();
      return false;
    }
    try {
      final PredictionMarket updated = await _api.placeBet(
        marketId: marketId,
        isYes: isYes,
        amount: _defaultPickWeight,
      );
      final int index = _questions.indexWhere(
        (PredictionMarket m) => m.id == marketId,
      );
      if (index != -1) {
        _questions[index] = updated;
      }
      await Future.wait<void>(<Future<void>>[
        _refreshRooms(),
        _api.fetchMyBets().then((List<UserBet> bets) => _myBets = bets),
        if (_selectedRoomId != null) _loadLeaderboardForRoom(_selectedRoomId!),
      ]);
      _gameError = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _gameError = e.message;
      notifyListeners();
      return false;
    } on http.ClientException {
      _gameError = _offlineMessage;
      notifyListeners();
      return false;
    } catch (e) {
      _gameError = 'Bet failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<List<RoomDiscover>> searchRooms(String query) async {
    if (!isLoggedIn) {
      return <RoomDiscover>[];
    }
    try {
      return await _api.discoverRooms(query);
    } catch (_) {
      return <RoomDiscover>[];
    }
  }

  Future<GameRoom?> joinRoom({required String joinCode, String? roomId}) async {
    if (!isLoggedIn) {
      _gameError = 'Sign in to join a room';
      notifyListeners();
      return null;
    }
    final String code = joinCode.trim().toUpperCase();
    if (code.length < 4) {
      _gameError = 'Enter a valid join code';
      notifyListeners();
      return null;
    }
    try {
      final GameRoom room = await _api.joinRoom(joinCode: code, roomId: roomId);
      final int existing = _rooms.indexWhere((GameRoom r) => r.id == room.id);
      if (existing == -1) {
        _rooms.insert(0, room);
      } else {
        _rooms[existing] = room;
      }
      _selectedRoomId = room.id;
      await Future.wait<void>(<Future<void>>[
        _loadRoomContext(),
        _api.fetchMyBets().then((List<UserBet> bets) => _myBets = bets),
      ]);
      _gameError = null;
      notifyListeners();
      return room;
    } on ApiException catch (e) {
      _gameError = e.message;
      notifyListeners();
      return null;
    } on http.ClientException {
      _gameError = _offlineMessage;
      notifyListeners();
      return null;
    } catch (e) {
      _gameError = 'Join failed: $e';
      notifyListeners();
      return null;
    }
  }

  Future<GameRoom?> createRoom({
    required List<String> personNames,
    required bool isGroup,
  }) async {
    if (!isLoggedIn) {
      _gameError = 'Sign in to create a room';
      notifyListeners();
      return null;
    }
    final List<String> normalizedPeople = _normalizePeople(personNames);
    if (normalizedPeople.isEmpty) {
      _gameError = 'Add at least one person';
      notifyListeners();
      return null;
    }
    if (isGroup && normalizedPeople.length < 2) {
      _gameError = 'Group rooms need at least two people';
      notifyListeners();
      return null;
    }
    try {
      final GameRoom room = await _api.createRoom(
        personNames: isGroup
            ? normalizedPeople
            : <String>[normalizedPeople.first],
        roomType: isGroup ? 'group' : 'individual',
      );
      _rooms.insert(0, room);
      _selectedRoomId = room.id;
      _questions = <PredictionMarket>[];
      _gameError = null;
      notifyListeners();
      await _loadLeaderboardForRoom(room.id);
      notifyListeners();
      return room;
    } on ApiException catch (e) {
      _gameError = e.message;
      notifyListeners();
      return null;
    } on http.ClientException {
      _gameError = _offlineMessage;
      notifyListeners();
      return null;
    } catch (e) {
      _gameError = 'Could not create room: $e';
      notifyListeners();
      return null;
    }
  }

  List<String> _normalizePeople(List<String> people) {
    final List<String> normalized = <String>[];
    final Set<String> seen = <String>{};
    for (final String person in people) {
      final String value = person.trim();
      final String key = value.toLowerCase();
      if (value.isEmpty || seen.contains(key)) {
        continue;
      }
      normalized.add(value);
      seen.add(key);
    }
    return normalized;
  }

  Future<PredictionMarket?> addQuestion(
    String questionText, {
    List<String> targetNames = const <String>[],
  }) async {
    if (!isLoggedIn || _selectedRoomId == null) {
      _gameError = 'Select a room first';
      notifyListeners();
      return null;
    }
    final String q = questionText.trim();
    if (q.isEmpty) {
      return null;
    }
    try {
      final PredictionMarket question = await _api.addQuestion(
        roomId: _selectedRoomId!,
        question: q,
        targetNames: targetNames,
      );
      _questions.insert(0, question);
      _gameError = null;
      notifyListeners();
      return question;
    } on ApiException catch (e) {
      _gameError = e.message;
      notifyListeners();
      return null;
    } on http.ClientException {
      _gameError = _offlineMessage;
      notifyListeners();
      return null;
    } catch (e) {
      _gameError = 'Could not add question: $e';
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteQuestion(String questionId) async {
    if (!isLoggedIn || _selectedRoomId == null) {
      return false;
    }
    if (!(selectedRoom?.isModerator ?? false)) {
      _gameError = 'Only the moderator can delete questions';
      notifyListeners();
      return false;
    }
    try {
      await _api.deleteQuestion(
        roomId: _selectedRoomId!,
        questionId: questionId,
      );
      _questions.removeWhere((PredictionMarket q) => q.id == questionId);
      await Future.wait<void>(<Future<void>>[
        _refreshRooms(),
        _api.fetchMyBets().then((List<UserBet> bets) => _myBets = bets),
        if (_selectedRoomId != null) _loadLeaderboardForRoom(_selectedRoomId!),
      ]);
      _gameError = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _gameError = e.message;
      notifyListeners();
      return false;
    } on http.ClientException {
      _gameError = _offlineMessage;
      notifyListeners();
      return false;
    } catch (e) {
      _gameError = 'Delete failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resolveMarket({
    required String marketId,
    required bool winningYes,
  }) async {
    if (!isLoggedIn) {
      return false;
    }
    try {
      final PredictionMarket updated = await _api.resolveMarket(
        marketId: marketId,
        winningYes: winningYes,
      );
      final int index = _questions.indexWhere(
        (PredictionMarket m) => m.id == marketId,
      );
      if (index != -1) {
        _questions[index] = updated;
      }
      await Future.wait<void>(<Future<void>>[
        _refreshRooms(),
        _api.fetchMyBets().then((List<UserBet> bets) => _myBets = bets),
        if (_selectedRoomId != null) _loadLeaderboardForRoom(_selectedRoomId!),
      ]);
      _gameError = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _gameError = e.message;
      notifyListeners();
      return false;
    } on http.ClientException {
      _gameError = _offlineMessage;
      notifyListeners();
      return false;
    } catch (e) {
      _gameError = 'Resolve failed: $e';
      notifyListeners();
      return false;
    }
  }

  bool canResolveMarket(PredictionMarket market) {
    return isLoggedIn && market.isOpen && (selectedRoom?.isModerator ?? false);
  }

  bool canDeleteQuestion(PredictionMarket market) {
    return isLoggedIn && (selectedRoom?.isModerator ?? false);
  }

  int currentUserRank() {
    final List<LeaderboardEntry> entries = leaderboard;
    if (_user == null) {
      return entries.isEmpty ? 0 : entries.length;
    }
    final int index = entries.indexWhere(
      (LeaderboardEntry e) => e.userId == _user!.id,
    );
    if (index == -1) {
      return entries.isEmpty ? 0 : entries.length;
    }
    return index + 1;
  }
}
