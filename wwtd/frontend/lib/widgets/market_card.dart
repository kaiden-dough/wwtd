import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/models/prediction_market.dart';
import 'package:wwtd/providers/app_state.dart';

class MarketCard extends StatelessWidget {
  const MarketCard({
    required this.market,
    super.key,
  });

  final PredictionMarket market;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final double betAmount = appState.betAmount;
    final double yesPayout = appState.expectedPayout(market: market, isYes: true, bet: betAmount);
    final double noPayout = appState.expectedPayout(market: market, isYes: false, bet: betAmount);

    return Card(
      elevation: 1,
      shadowColor: Colors.black12,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              market.question,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _oddsLabel(context, 'Yes ${market.yesPercent.toStringAsFixed(0)}%', const Color(0xFF1E7D53)),
                _oddsLabel(context, 'No ${market.noPercent.toStringAsFixed(0)}%', const Color(0xFFC74A3E)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      flex: (market.yesPercent * 100).round(),
                      child: const ColoredBox(color: Color(0xFF2FB879)),
                    ),
                    Expanded(
                      flex: (market.noPercent * 100).round(),
                      child: const ColoredBox(color: Color(0xFFE97B70)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Total pot: ${_formatPoints(market.totalPot)} points',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF526170)),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2C9B67),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => context.read<AppState>().placeBet(marketId: market.id, isYes: true),
                    child: const Text('Bet Yes'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF7DEDB),
                      foregroundColor: const Color(0xFFB24338),
                    ),
                    onPressed: () => context.read<AppState>().placeBet(marketId: market.id, isYes: false),
                    child: const Text('Bet No'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F8FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Bet ${betAmount.toStringAsFixed(0)} points -> '
                'Yes wins ${yesPayout.toStringAsFixed(1)} | '
                'No wins ${noPayout.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF314355),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _oddsLabel(BuildContext context, String text, Color color) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
    );
  }

  String _formatPoints(double points) => points.toStringAsFixed(0);
}
