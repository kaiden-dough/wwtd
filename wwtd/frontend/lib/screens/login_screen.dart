import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/providers/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool isRegister = _tabController.index == 1;

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
                    isRegister
                        ? 'Pick a username — that\'s how you appear on leaderboards.'
                        : 'Sign in to bet on predictions with friends.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF607182)),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TabBar(
                            controller: _tabController,
                            onTap: (_) {
                              appState.clearAuthError();
                              setState(() {});
                            },
                            tabs: const <Tab>[
                              Tab(text: 'Log in'),
                              Tab(text: 'Sign up'),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: _usernameController,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                              hintText: 'letters, numbers, underscore',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => appState.clearAuthError(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              hintText: 'at least 8 characters',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => appState.clearAuthError(),
                            onSubmitted: (_) {
                              if (!appState.authLoading) {
                                if (isRegister) {
                                  _submitRegister(appState);
                                } else {
                                  _submitLogin(appState);
                                }
                              }
                            },
                          ),
                          if (appState.authError != null) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(
                              appState.authError!,
                              style: const TextStyle(color: Color(0xFFC62828)),
                            ),
                          ],
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: appState.authLoading
                                ? null
                                : () => isRegister ? _submitRegister(appState) : _submitLogin(appState),
                            child: appState.authLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(isRegister ? 'Create account' : 'Log in'),
                          ),
                        ],
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

  void _submitLogin(AppState appState) {
    appState.login(
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }

  void _submitRegister(AppState appState) {
    appState.register(
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }
}
