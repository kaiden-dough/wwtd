import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wwtd/config/api_config.dart';
import 'package:wwtd/data/mock_data.dart';
import 'package:wwtd/models/leaderboard_entry.dart';
import 'package:wwtd/models/prediction_market.dart';
import 'package:wwtd/models/user_profile.dart';
import 'package:wwtd/services/api_client.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? apiClient}) : _api = apiClient ?? ApiClient() {
    _init();
  }

  static const String _tokenKey = 'auth_token';

  final ApiClient _api;

  String _selectedPerson = samplePeople.first;
  int _selectedTabIndex = 0;
  double _betAmount = 10;
  double _userBalance = 500;
  final List<PredictionMarket> _markets = List<PredictionMarket>.from(marketData);
  final List<LeaderboardEntry> _leaderboard = List<LeaderboardEntry>.from(leaderboardData);

  UserProfile? _user;
  bool _authLoading = false;
  String? _authError;
  bool _codeSent = false;
  String _pendingEmail = '';
  String? _devCode;
  String? _sendCodeMessage;

  UserProfile? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get authLoading => _authLoading == true;
  String? get authError => _authError;
  bool get codeSent => _codeSent == true;
  String get pendingEmail => _pendingEmail;
  String? get devCode => _devCode;
  String? get sendCodeMessage => _sendCodeMessage;

  String get selectedPerson => _selectedPerson;
  int get selectedTabIndex => _selectedTabIndex;
  double get betAmount => _betAmount;
  double get userBalance => _userBalance;
  List<LeaderboardEntry> get leaderboard => _leaderboard;
  List<String> get people {
    final List<String> ordered = <String>[];
    for (final PredictionMarket market in _markets) {
      if (!ordered.contains(market.person)) {
        ordered.add(market.person);
      }
    }
    return ordered;
  }

  Future<void> _init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      return;
    }
    _api.setToken(token);
    await _restoreSession(prefs);
  }

  Future<void> _restoreSession(SharedPreferences prefs) async {
    _setAuthLoading(true);
    try {
      _user = await _api.fetchMe();
      _authError = null;
    } catch (_) {
      await prefs.remove(_tokenKey);
      _api.setToken(null);
      _user = null;
    } finally {
      _setAuthLoading(false);
    }
  }

  Future<void> sendLoginCode(String email) async {
    final String normalized = email.trim().toLowerCase();
    if (!_isValidEmail(normalized)) {
      _authError = 'Enter a valid email address';
      notifyListeners();
      return;
    }

    _setAuthLoading(true);
    _authError = null;
    notifyListeners();

    try {
      final result = await _api.sendLoginCode(normalized);
      _pendingEmail = normalized;
      _codeSent = true;
      _devCode = result.devCode;
      _sendCodeMessage = result.message;
    } on ApiException catch (e) {
      _authError = e.message;
    } on http.ClientException {
      _authError =
          'Cannot reach the API at ${ApiConfig.baseUrl}. Start the server with: '
          'python -m uvicorn app.main:app --reload --port 8000';
    } catch (e) {
      _authError = 'Request failed: $e';
    } finally {
      _setAuthLoading(false);
    }
  }

  Future<void> verifyLoginCode(String code) async {
    if (_pendingEmail.isEmpty) {
      _authError = 'Enter your email first';
      notifyListeners();
      return;
    }

    final String digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      _authError = 'Enter the 6-digit code';
      notifyListeners();
      return;
    }

    _setAuthLoading(true);
    _authError = null;
    notifyListeners();

    try {
      final UserProfile profile = await _api.verifyLoginCode(
        email: _pendingEmail,
        code: digits,
      );
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String token = _api.token ?? '';
      if (token.isNotEmpty) {
        await prefs.setString(_tokenKey, token);
      }
      _user = profile;
      _codeSent = false;
      _pendingEmail = '';
      _devCode = null;
      _sendCodeMessage = null;
    } on ApiException catch (e) {
      _authError = e.message;
    } on http.ClientException {
      _authError =
          'Cannot reach the API at ${ApiConfig.baseUrl}. Start the server with: '
          'python -m uvicorn app.main:app --reload --port 8000';
    } catch (e) {
      _authError = 'Sign-in failed: $e';
    } finally {
      _setAuthLoading(false);
    }
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _api.setToken(null);
    _user = null;
    _codeSent = false;
    _pendingEmail = '';
    _devCode = null;
    _sendCodeMessage = null;
    _authError = null;
    notifyListeners();
  }

  void resetLoginFlow() {
    _codeSent = false;
    _pendingEmail = '';
    _devCode = null;
    _sendCodeMessage = null;
    _authError = null;
    notifyListeners();
  }

  void clearAuthError() {
    if (_authError == null) {
      return;
    }
    _authError = null;
    notifyListeners();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  void _setAuthLoading(bool value) {
    _authLoading = value;
    notifyListeners();
  }

  void updateTab(int index) {
    if (_selectedTabIndex == index) {
      return;
    }
    _selectedTabIndex = index;
    notifyListeners();
  }

  void updateSelectedPerson(String person) {
    if (_selectedPerson == person) {
      return;
    }
    _selectedPerson = person;
    _refreshMarketsIfSelectionMissing();
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

  List<PredictionMarket> marketsForSelectedPerson() {
    return _markets.where((PredictionMarket m) => m.person == _selectedPerson).toList();
  }

  Map<String, List<PredictionMarket>> groupedMarkets() {
    final Map<String, List<PredictionMarket>> grouped = <String, List<PredictionMarket>>{};
    for (final PredictionMarket market in marketsForSelectedPerson()) {
      grouped.putIfAbsent(market.dateLabel, () => <PredictionMarket>[]).add(market);
    }
    return grouped;
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

  void placeBet({
    required String marketId,
    required bool isYes,
  }) {
    if (_betAmount > _userBalance) {
      return;
    }

    final int marketIndex = _markets.indexWhere((PredictionMarket m) => m.id == marketId);
    if (marketIndex == -1) {
      return;
    }

    final PredictionMarket market = _markets[marketIndex];
    final PredictionMarket updated = isYes
        ? market.copyWith(
            yesWageredPoints: market.yesWageredPoints + _betAmount,
            userYesBet: market.userYesBet + _betAmount,
          )
        : market.copyWith(
            noWageredPoints: market.noWageredPoints + _betAmount,
            userNoBet: market.userNoBet + _betAmount,
          );

    _markets[marketIndex] = updated;
    _userBalance -= _betAmount;
    notifyListeners();
  }

  void createMarket({
    required String person,
    required String question,
    required String dateLabel,
    required bool creatorPickedYes,
    required double creatorStake,
  }) {
    final String normalizedPerson = person.trim();
    final String normalizedQuestion = question.trim();
    if (normalizedPerson.isEmpty || normalizedQuestion.isEmpty) {
      return;
    }

    final double startingPot = creatorStake.clamp(1, 100000).toDouble();
    final PredictionMarket market = PredictionMarket(
      id: 'u-${DateTime.now().microsecondsSinceEpoch}',
      person: normalizedPerson,
      question: normalizedQuestion,
      dateLabel: dateLabel,
      yesWageredPoints: creatorPickedYes ? startingPot : 0,
      noWageredPoints: creatorPickedYes ? 0 : startingPot,
    );
    _markets.insert(0, market);
    _selectedPerson = normalizedPerson;
    notifyListeners();
  }

  int currentUserRank() {
    final String name = _user?.displayName ?? currentUsername;
    final int index = _leaderboard.indexWhere((LeaderboardEntry entry) => entry.username == name);
    if (index == -1) {
      return _leaderboard.length;
    }
    return index + 1;
  }

  void _refreshMarketsIfSelectionMissing() {
    final bool hasLoadedMarketsForSelection = _markets.any(
      (PredictionMarket market) => market.person == _selectedPerson,
    );
    if (hasLoadedMarketsForSelection) {
      return;
    }

    final bool hasSourceMarketsForSelection = marketData.any(
      (PredictionMarket market) => market.person == _selectedPerson,
    );
    if (!hasSourceMarketsForSelection) {
      return;
    }

    _markets
      ..clear()
      ..addAll(List<PredictionMarket>.from(marketData));
  }
}
