import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/models/user_profile.dart';
import 'package:wwtd/providers/app_state.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: appState.authLoading && !appState.isLoggedIn && !appState.codeSent
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Account',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 16),
                        _BalanceCard(balance: appState.userBalance),
                        const SizedBox(height: 24),
                        if (appState.isLoggedIn)
                          _LoggedInSection(user: appState.user!, onLogout: appState.logout)
                        else if (appState.codeSent)
                          _CodeStep(
                            email: appState.pendingEmail,
                            codeController: _codeController,
                            onVerify: () => appState.verifyLoginCode(_codeController.text),
                            onBack: appState.resetLoginFlow,
                          )
                        else
                          _EmailStep(
                            emailController: _emailController,
                            onSendCode: () => appState.sendLoginCode(_emailController.text),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Current Balance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF41556A),
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${balance.toStringAsFixed(0)} points',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF1454A7),
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  _EmailStep({
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
              Text(
                authError,
                style: const TextStyle(color: Color(0xFFC62828)),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: loading ? null : onSendCode,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeStep extends StatelessWidget {
  _CodeStep({
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                    const SizedBox(height: 4),
                    Text(
                      'Configure SMTP in backend .env to send real email.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF607182)),
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
              Text(
                authError,
                style: const TextStyle(color: Color(0xFFC62828)),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: loading ? null : onVerify,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify & sign in'),
            ),
            TextButton(
              onPressed: loading ? null : onBack,
              child: const Text('Use a different email'),
            ),
          ],
        ),
      ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
              onPressed: onLogout,
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }
}
