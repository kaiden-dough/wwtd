import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/providers/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  Timer? _usernameDebounce;
  bool _checkingUsername = false;
  bool? _usernameAvailable;
  String? _usernameCheckMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          if (_tabController.index != 1) {
            _usernameAvailable = null;
            _usernameCheckMessage = null;
            _checkingUsername = false;
          }
        });
      }
    });
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _tabController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    if (_tabController.index != 1) {
      return;
    }
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(
      const Duration(milliseconds: 400),
      _checkUsernameAvailability,
    );
  }

  Future<void> _checkUsernameAvailability() async {
    final String raw = _usernameController.text.trim();
    if (raw.length < 3) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = null;
        _usernameCheckMessage = raw.isEmpty
            ? null
            : 'Username must be at least 3 characters';
      });
      return;
    }

    setState(() {
      _checkingUsername = true;
      _usernameCheckMessage = null;
    });

    try {
      final AppState appState = context.read<AppState>();
      final ({bool available, String? message}) result = await appState
          .checkUsername(raw);
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = result.available;
        _usernameCheckMessage = result.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = null;
        _usernameCheckMessage = null;
      });
    }
  }

  bool _canSubmitRegister(AppState appState) {
    if (_passwordController.text.length < 8) {
      return false;
    }
    if (_checkingUsername) {
      return false;
    }
    return _usernameAvailable == true;
  }

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    final bool isRegister = _tabController.index == 1;
    final bool canRegister = _canSubmitRegister(appState);

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
                        : 'Sign in to make picks with friends.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF607182),
                    ),
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
                              if (_tabController.index == 1) {
                                _checkUsernameAvailability();
                              }
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
                            decoration: InputDecoration(
                              labelText: 'Username',
                              hintText: 'letters, numbers, underscore',
                              border: const OutlineInputBorder(),
                              suffixIcon: isRegister && _checkingUsername
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : isRegister && _usernameAvailable == true
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF2C9B67),
                                    )
                                  : isRegister && _usernameAvailable == false
                                  ? const Icon(
                                      Icons.cancel,
                                      color: Color(0xFFC62828),
                                    )
                                  : null,
                              errorText: isRegister
                                  ? _usernameCheckMessage
                                  : null,
                            ),
                            onChanged: (_) {
                              appState.clearAuthError();
                              if (isRegister) {
                                setState(() {
                                  _usernameAvailable = null;
                                  _usernameCheckMessage = null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: true,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: isRegister
                                  ? 'at least 8 characters'
                                  : 'enter password',
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) {
                              appState.clearAuthError();
                              if (isRegister) {
                                setState(() {});
                              }
                            },
                            onSubmitted: (_) {
                              if (!appState.authLoading) {
                                if (isRegister && canRegister) {
                                  _submitRegister(appState);
                                } else if (!isRegister) {
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
                            onPressed:
                                appState.authLoading ||
                                    (isRegister && !canRegister)
                                ? null
                                : () {
                                    if (isRegister) {
                                      _submitRegister(appState);
                                    } else {
                                      _submitLogin(appState);
                                    }
                                  },
                            child: appState.authLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isRegister ? 'Create account' : 'Log in',
                                  ),
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
