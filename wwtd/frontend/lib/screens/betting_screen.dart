import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      child: Stack(
        children: <Widget>[
          Center(
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
                    people: appState.people,
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
                  const SizedBox(height: 88),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              onPressed: () => _showCreateMarketSheet(context, appState),
              tooltip: 'Add market',
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showCreateMarketSheet(BuildContext context, AppState appState) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: _CreateMarketCard(
          selectedPerson: appState.selectedPerson,
          people: appState.people,
          showAsCard: false,
          onCreate: ({
            required String person,
            required String question,
            required String dateLabel,
            required bool creatorPickedYes,
            required double creatorStake,
          }) {
            appState.createMarket(
              person: person,
              question: question,
              dateLabel: dateLabel,
              creatorPickedYes: creatorPickedYes,
              creatorStake: creatorStake,
            );
            Navigator.of(sheetContext).pop();
          },
        ),
      );
    },
  );
}

class _PeopleSelector extends StatelessWidget {
  const _PeopleSelector({
    required this.people,
    required this.selectedPerson,
    required this.onChanged,
  });

  final List<String> people;
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
            items: people.map((String person) {
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
          segments: people
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

class _CreateMarketCard extends StatefulWidget {
  const _CreateMarketCard({
    required this.selectedPerson,
    required this.people,
    required this.onCreate,
    this.showAsCard = true,
  });

  final String selectedPerson;
  final List<String> people;
  final void Function({
    required String person,
    required String question,
    required String dateLabel,
    required bool creatorPickedYes,
    required double creatorStake,
  }) onCreate;
  final bool showAsCard;

  @override
  State<_CreateMarketCard> createState() => _CreateMarketCardState();
}

class _CreateMarketCardState extends State<_CreateMarketCard> {
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _stakeController = TextEditingController(text: '500');
  late String _person;
  String _dateLabel = 'Today';
  bool _creatorPickedYes = true;

  @override
  void initState() {
    super.initState();
    _person = widget.selectedPerson;
  }

  @override
  void didUpdateWidget(covariant _CreateMarketCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.people.contains(_person) && widget.people.isNotEmpty) {
      _person = widget.people.first;
    } else if (oldWidget.selectedPerson != widget.selectedPerson && oldWidget.selectedPerson == _person) {
      _person = widget.selectedPerson;
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _stakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Create Market',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _person,
            decoration: const InputDecoration(
              labelText: 'Person',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: widget.people
                .map((String person) => DropdownMenuItem<String>(value: person, child: Text(person)))
                .toList(),
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _person = value);
              }
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _questionController,
            decoration: const InputDecoration(
              labelText: 'Question',
              hintText: 'Will ... ?',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _dateLabel,
            decoration: const InputDecoration(
              labelText: 'Date Group',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'Today', child: Text('Today')),
              DropdownMenuItem<String>(value: 'Tomorrow', child: Text('Tomorrow')),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _dateLabel = value);
              }
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Your starting side',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF526170),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const <ButtonSegment<bool>>[
              ButtonSegment<bool>(value: true, label: Text('Yes')),
              ButtonSegment<bool>(value: false, label: Text('No')),
            ],
            selected: <bool>{_creatorPickedYes},
            onSelectionChanged: (Set<bool> selection) {
              setState(() => _creatorPickedYes = selection.first);
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _stakeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Starting pot (points)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submit,
              child: const Text('Add Market'),
            ),
          ),
        ],
      ),
    );
    if (widget.showAsCard) {
      return Card(child: content);
    }
    return content;
  }

  void _submit() {
    final String person = _person.trim();
    final String question = _questionController.text.trim();
    final double stake = double.tryParse(_stakeController.text.trim()) ?? 0;
    if (person.isEmpty || question.isEmpty || stake <= 0) {
      return;
    }
    widget.onCreate(
      person: person,
      question: question,
      dateLabel: _dateLabel,
      creatorPickedYes: _creatorPickedYes,
      creatorStake: stake,
    );
    _questionController.clear();
    FocusScope.of(context).unfocus();
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
