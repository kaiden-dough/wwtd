import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/providers/app_state.dart';
import 'package:wwtd/screens/account_screen.dart';
import 'package:wwtd/screens/betting_screen.dart';
import 'package:wwtd/screens/login_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF165AB0),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'What Would They Do?',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          shadowColor: Colors.black12,
        ),
      ),
      home: const AppGate(),
    );
  }
}

/// Shows login until authenticated; restores saved session on launch.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();

    if (!appState.sessionReady || (appState.authLoading && !appState.isLoggedIn)) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!appState.isLoggedIn) {
      return const LoginScreen();
    }

    return const AppShell();
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          appState.selectedRoom != null
              ? 'What would ${appState.selectedPerson} do?'
              : 'What Would They Do?',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF165AB0).withValues(alpha: 0.25)),
                ),
                child: Text(
                  '${appState.userBalance.toStringAsFixed(0)} pts',
                  style: const TextStyle(
                    color: Color(0xFF1454A7),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Account',
            onPressed: () => showAccountSheet(context),
            icon: const Icon(Icons.person_rounded, color: Color(0xFF1454A7)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: const BettingScreen(),
    );
  }
}
