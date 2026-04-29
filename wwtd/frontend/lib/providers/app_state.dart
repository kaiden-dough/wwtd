import 'package:flutter/material.dart';
import 'package:wwtd/data/mock_data.dart';
import 'package:wwtd/models/leaderboard_entry.dart';
import 'package:wwtd/models/prediction_market.dart';

class AppState extends ChangeNotifier {
  AppState()
      : _selectedPerson = samplePeople.first,
        _markets = List<PredictionMarket>.from(marketData),
        _leaderboard = List<LeaderboardEntry>.from(leaderboardData);

  String _selectedPerson;
  int _selectedTabIndex = 0;
  double _betAmount = 10;
  double _userBalance = 500;
  final List<PredictionMarket> _markets;
  final List<LeaderboardEntry> _leaderboard;

  String get selectedPerson => _selectedPerson;
  int get selectedTabIndex => _selectedTabIndex;
  double get betAmount => _betAmount;
  double get userBalance => _userBalance;
  List<LeaderboardEntry> get leaderboard => _leaderboard;

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

  int currentUserRank() {
    final int index = _leaderboard.indexWhere((LeaderboardEntry entry) => entry.username == currentUsername);
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
