import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wwtd/config/api_config.dart';
import 'package:wwtd/models/game_room.dart';
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
  double _betAmount = 10;
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
    final List<PredictionMarket> sorted = List<PredictionMarket>.from(_questions);
    sorted.sort((PredictionMarket a, PredictionMarket b) {
      final int pastCmp = (a.isPast ? 1 : 0).compareTo(b.isPast ? 1 : 0);
      if (pastCmp != 0) {
        return pastCmp;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }
  double get betAmount => _betAmount;

  /// Bets for the currently selected room only.
  List<UserBet> get roomBets {
    if (_selectedRoomId == null) {
      return <UserBet>[];
    }
    final List<UserBet> bets =
        _myBets.where((UserBet b) => b.roomId == _selectedRoomId).toList();
    bets.sort((UserBet a, UserBet b) {
      final int pastCmp = (a.isPast ? 1 : 0).compareTo(b.isPast ? 1 : 0);
      if (pastCmp != 0) {
        return pastCmp;
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return bets;
  }
  double get userBalance => _user?.balancePoints ?? 0;
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

  Future<void> _refreshGameData() async {
    _setGameLoading(true);
    try {
      final UserProfile profile = await _api.fetchMe();
      final List<GameRoom> rooms = await _api.fetchRooms();
      final List<RoomLeaderboard> board = await _api.fetchLeaderboard();
      final List<UserBet> bets = await _api.fetchMyBets();
      _user = profile;
      _rooms = rooms;
      _roomLeaderboards = board;
      _myBets = bets;
      _gameError = null;
      _ensureSelectedRoomValid();
      await _loadQuestionsForSelectedRoom();
    } finally {
      _setGameLoading(false);
    }
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
    if (_selectedRoomId == null || !_rooms.any((GameRoom r) => r.id == _selectedRoomId)) {
      _selectedRoomId = _rooms.first.id;
    }
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
    await _loadQuestionsForSelectedRoom();
    notifyListeners();
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

    await _authenticate(() => _api.register(
          username: username,
          password: password,
        ));
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

    await _authenticate(() => _api.login(username: username, password: password));
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
      await _refreshGameData();
    } on ApiException catch (e) {
      _authError = e.message;
    } on http.ClientException {
      _authError = _offlineMessage;
    } catch (e) {
      _authError = 'Sign-in failed: $e';
    } finally {
      _setAuthLoading(false);
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

  void updateBetAmount(double value) {
    final double sanitized = value.clamp(1, 5000);
    if ((_betAmount - sanitized).abs() < 0.001) {
      return;
    }
    _betAmount = sanitized;
    notifyListeners();
  }

  double expectedPayout({
    required PredictionMarket market,
    required bool isYes,
    required double bet,
  }) {
    final double sidePool = isYes ? market.yesWageredPoints : market.noWageredPoints;
    final double totalPoolAfterBet = market.totalPot + bet;
    final double sideAfterBet = sidePool + bet;
    if (sideAfterBet <= 0) {
      return 0;
    }
    return totalPoolAfterBet * (bet / sideAfterBet);
  }

  Future<bool> placeBet({
    required String marketId,
    required bool isYes,
  }) async {
    if (!isLoggedIn) {
      _gameError = 'Sign in to place bets';
      notifyListeners();
      return false;
    }
    if (_betAmount > userBalance) {
      _gameError = 'Not enough points';
      notifyListeners();
      return false;
    }

    try {
      final PredictionMarket updated = await _api.placeBet(
        marketId: marketId,
        isYes: isYes,
        amount: _betAmount,
      );
      final int index = _questions.indexWhere((PredictionMarket m) => m.id == marketId);
      if (index != -1) {
        _questions[index] = updated;
      }
      _user = await _api.fetchMe();
      _myBets = await _api.fetchMyBets();
      _roomLeaderboards = await _api.fetchLeaderboard();
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

  Future<GameRoom?> joinRoom(String joinCode) async {
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
      final GameRoom room = await _api.joinRoom(code);
      final int existing = _rooms.indexWhere((GameRoom r) => r.id == room.id);
      if (existing == -1) {
        _rooms.insert(0, room);
      } else {
        _rooms[existing] = room;
      }
      _selectedRoomId = room.id;
      await _loadQuestionsForSelectedRoom();
      _user = await _api.fetchMe();
      _myBets = await _api.fetchMyBets();
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

  Future<GameRoom?> createRoom(String person) async {
    if (!isLoggedIn) {
      _gameError = 'Sign in to create a room';
      notifyListeners();
      return null;
    }
    final String normalizedPerson = person.trim();
    if (normalizedPerson.isEmpty) {
      return null;
    }
    try {
      final GameRoom room = await _api.createRoom(normalizedPerson);
      _rooms.insert(0, room);
      _selectedRoomId = room.id;
      _questions = <PredictionMarket>[];
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
      _gameError = 'Could not create room: $e';
      notifyListeners();
      return null;
    }
  }

  Future<PredictionMarket?> addQuestion(String questionText) async {
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
      final PredictionMarket question = await _api.addQuestion(roomId: _selectedRoomId!, question: q);
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
      await _api.deleteQuestion(roomId: _selectedRoomId!, questionId: questionId);
      _questions.removeWhere((PredictionMarket q) => q.id == questionId);
      _user = await _api.fetchMe();
      _myBets = await _api.fetchMyBets();
      _roomLeaderboards = await _api.fetchLeaderboard();
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
      final int index = _questions.indexWhere((PredictionMarket m) => m.id == marketId);
      if (index != -1) {
        _questions[index] = updated;
      }
      _user = await _api.fetchMe();
      _myBets = await _api.fetchMyBets();
      _roomLeaderboards = await _api.fetchLeaderboard();
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
    final int index = entries.indexWhere((LeaderboardEntry e) => e.userId == _user!.id);
    if (index == -1) {
      return entries.isEmpty ? 0 : entries.length;
    }
    return index + 1;
  }
}
