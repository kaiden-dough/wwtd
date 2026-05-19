import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/models/user_bet.dart';
import 'package:wwtd/models/user_profile.dart';
import 'package:wwtd/providers/app_state.dart';

Future<void> showAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (BuildContext context, ScrollController scrollController) {
          return AccountSheetContent(scrollController: scrollController);
        },
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        Text(
          appState.isLoggedIn ? 'Account' : 'Sign in',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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

class LoginDisplayNameStep extends StatelessWidget {
  const LoginDisplayNameStep({
    super.key,
    required this.nameController,
    required this.onContinue,
  });

  final TextEditingController nameController;
  final Future<bool> Function() onContinue;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool loading = appState.authLoading;
    final String? authError = appState.authError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Choose display name',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'This is how you appear on room leaderboards.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Display name',
            hintText: 'e.g. Alex',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => appState.clearAuthError(),
          onSubmitted: (_) {
            if (!loading) {
              onContinue();
            }
          },
        ),
        if (authError != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(authError, style: const TextStyle(color: Color(0xFFC62828))),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading ? null : onContinue,
          child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Continue'),
        ),
      ],
    );
  }
}

class LoginEmailStep extends StatelessWidget {
  const LoginEmailStep({
    super.key,
    required this.emailController,
    required this.onSendCode,
  });

  final TextEditingController emailController;
  final VoidCallback onSendCode;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool loading = appState.authLoading;
    final String? authError = appState.authError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Sign in',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'We\'ll email you a 6-digit code.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => appState.clearAuthError(),
          onSubmitted: (_) {
            if (!loading) {
              onSendCode();
            }
          },
        ),
        if (authError != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(authError, style: const TextStyle(color: Color(0xFFC62828))),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading ? null : onSendCode,
          child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Send code'),
        ),
      ],
    );
  }
}

class LoginCodeStep extends StatelessWidget {
  const LoginCodeStep({
    super.key,
    required this.email,
    required this.codeController,
    required this.onVerify,
    required this.onBack,
  });

  final String email;
  final TextEditingController codeController;
  final VoidCallback onVerify;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool loading = appState.authLoading;
    final String? authError = appState.authError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Enter code',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          appState.sendCodeMessage ?? 'Sent to $email',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
        ),
        if (appState.devCode != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF165AB0).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  'Dev login code',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF1454A7),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  appState.devCode!,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        letterSpacing: 6,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1454A7),
                      ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 8),
          decoration: const InputDecoration(
            labelText: '6-digit code',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => appState.clearAuthError(),
          onSubmitted: (_) {
            if (!loading) {
              onVerify();
            }
          },
        ),
        if (authError != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(authError, style: const TextStyle(color: Color(0xFFC62828))),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: loading ? null : onVerify,
          child: loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify & sign in'),
        ),
        TextButton(
          onPressed: loading ? null : onBack,
          child: const Text('Use a different email'),
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
          roomLabel != null ? 'Your bets in $roomLabel\'s room' : 'Your bets',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (roomLabel == null)
          Text(
            'Select a room to see bets for that room.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
          )
        else if (bets.isEmpty)
          Text(
            'No bets in this room yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
          )
        else
          ...bets.take(20).map((UserBet bet) {
            final String payoutLabel = bet.marketStatus == 'resolved'
                ? (bet.payoutAmount != null && bet.payoutAmount! > 0
                    ? 'Won ${bet.payoutAmount!.toStringAsFixed(0)} pts'
                    : 'Lost')
                : 'Open';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(bet.marketQuestion, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${bet.side.toUpperCase()} · ${bet.amount.toStringAsFixed(0)} pts'),
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
  const _LoggedInSection({
    required this.user,
    required this.onLogout,
  });

  final UserProfile user;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final String label = user.displayName?.isNotEmpty == true ? user.displayName! : user.email;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              backgroundColor: const Color(0xFF165AB0),
              child: Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF607182)),
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
