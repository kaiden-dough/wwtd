import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/data/mock_data.dart';
import 'package:wwtd/models/prediction_market.dart';
import 'package:wwtd/providers/app_state.dart';
import 'package:wwtd/widgets/market_card.dart';

class BettingScreen extends StatelessWidget {
  const BettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final Map<String, List<PredictionMarket>> grouped = appState.groupedMarkets();

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            children: <Widget>[
              Text(
                'Markets',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              _PeopleSelector(
                selectedPerson: appState.selectedPerson,
                onChanged: appState.updateSelectedPerson,
              ),
              const SizedBox(height: 14),
              _BetAmountField(
                value: appState.betAmount,
                onChanged: appState.updateBetAmount,
              ),
              const SizedBox(height: 14),
              for (final String dateLabel in grouped.keys) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, top: 8),
                  child: Text(
                    dateLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF334155),
                        ),
                  ),
                ),
                ...grouped[dateLabel]!.map<Widget>((PredictionMarket market) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: MarketCard(market: market),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleSelector extends StatelessWidget {
  const _PeopleSelector({
    required this.selectedPerson,
    required this.onChanged,
  });

  final String selectedPerson;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool useDropdown = constraints.maxWidth < 560;
        if (useDropdown) {
          return DropdownButtonFormField<String>(
            initialValue: selectedPerson,
            decoration: const InputDecoration(
              labelText: 'Person',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            items: samplePeople.map((String person) {
              return DropdownMenuItem<String>(
                value: person,
                child: Text(person, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (String? value) {
              if (value != null) {
                onChanged(value);
              }
            },
          );
        }

        return SegmentedButton<String>(
          segments: samplePeople
              .map((String person) => ButtonSegment<String>(value: person, label: Text(person)))
              .toList(),
          selected: <String>{selectedPerson},
          onSelectionChanged: (Set<String> selection) => onChanged(selection.first),
          style: SegmentedButton.styleFrom(
            selectedForegroundColor: Colors.white,
            selectedBackgroundColor: const Color(0xFF1556A8),
          ),
        );
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
    if (oldWidget.value != widget.value && _controller.text != widget.value.toStringAsFixed(0)) {
      _controller.text = widget.value.toStringAsFixed(0);
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
        labelText: 'Bet Amount (points)',
        border: OutlineInputBorder(),
      ),
      onSubmitted: _handleInput,
      onChanged: _handleInput,
    );
  }

  void _handleInput(String raw) {
    final double? value = double.tryParse(raw);
    if (value == null) {
      return;
    }
    widget.onChanged(value);
  }
}
