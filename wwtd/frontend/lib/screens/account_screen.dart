import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/models/user_bet.dart';
import 'package:wwtd/models/user_profile.dart';
import 'package:wwtd/providers/app_state.dart';

Future<void> showAccountSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext sheetContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
          ),
          child: AccountSheetContent(scrollController: ScrollController()),
        ),
      );
    },
  );
}

class AccountSheetContent extends StatefulWidget {
  const AccountSheetContent({required this.scrollController, super.key});

  final ScrollController scrollController;

  @override
  State<AccountSheetContent> createState() => _AccountSheetContentState();
}

class _AccountSheetContentState extends State<AccountSheetContent> {
  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: <Widget>[
        Text(
          appState.isLoggedIn ? 'Account' : 'Sign in',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        _LoggedInSection(user: appState.user!, onLogout: appState.logout),
        const SizedBox(height: 20),
        _BetHistorySection(
          bets: appState.roomBets,
          roomLabel: appState.selectedRoom?.personName,
        ),
      ],
    );
  }
}

class _BetHistorySection extends StatelessWidget {
  const _BetHistorySection({required this.bets, this.roomLabel});

  final List<UserBet> bets;
  final String? roomLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          roomLabel != null ? 'Your picks in $roomLabel\'s room' : 'Your picks',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (roomLabel == null)
          Text(
            'Select a room to see picks for that room.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
          )
        else if (bets.isEmpty)
          Text(
            'No picks in this room yet.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
          )
        else
          ...bets.take(20).map((UserBet bet) {
            final String payoutLabel = bet.isResolved
                ? (bet.payoutAmount != null && bet.payoutAmount! > 0
                      ? 'Won'
                      : 'Lost')
                : (bet.isPast ? 'Locked' : 'Open');
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  bet.marketQuestion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(bet.side.toUpperCase()),
                trailing: Text(
                  payoutLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: payoutLabel.startsWith('Won')
                        ? const Color(0xFF2C9B67)
                        : const Color(0xFF607182),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _LoggedInSection extends StatelessWidget {
  const _LoggedInSection({required this.user, required this.onLogout});

  final UserProfile user;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final String label = user.username.isNotEmpty
        ? user.username
        : (user.displayName ?? 'Player');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: const Color(0xFF165AB0),
              child: Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (user.username.isNotEmpty)
                    Text(
                      '@${user.username}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF607182),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () async {
            Navigator.of(context).pop();
            await onLogout();
          },
          child: const Text('Log out'),
        ),
      ],
    );
  }
}
