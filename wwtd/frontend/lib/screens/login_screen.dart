import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/providers/app_state.dart';
import 'package:wwtd/screens/account_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool choosingName = appState.isLoggedIn && appState.needsDisplayName;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'What Would They Do?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1454A7),
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    choosingName
                        ? 'Pick a name for the leaderboard.'
                        : 'Sign in to bet on predictions with friends.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF607182)),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: choosingName
                          ? LoginDisplayNameStep(
                              nameController: _displayNameController,
                              onContinue: () =>
                                  appState.completeDisplayName(_displayNameController.text),
                            )
                          : appState.codeSent
                              ? LoginCodeStep(
                                  email: appState.pendingEmail,
                                  codeController: _codeController,
                                  onVerify: () => appState.verifyLoginCode(_codeController.text),
                                  onBack: appState.resetLoginFlow,
                                )
                              : LoginEmailStep(
                                  emailController: _emailController,
                                  onSendCode: () => appState.sendLoginCode(_emailController.text),
                                ),
                    ),
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
