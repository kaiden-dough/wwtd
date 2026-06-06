import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wwtd/providers/app_state.dart';
import 'package:wwtd/screens/account_screen.dart';
import 'package:wwtd/screens/betting_screen.dart';
import 'package:wwtd/screens/login_screen.dart';
import 'package:wwtd/utils/room_url.dart';
import 'package:wwtd/widgets/join_room_sheet.dart';

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

    if (!appState.sessionReady ||
        (appState.authLoading && !appState.isLoggedIn)) {
      return const _LoadingScreen();
    }

    if (!appState.isLoggedIn) {
      return const LoginScreen();
    }

    return const AppShell();
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.network(
                  'icons/Icon-192.png',
                  width: 132,
                  height: 132,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (
                        BuildContext context,
                        Object error,
                        StackTrace? stackTrace,
                      ) {
                        return Container(
                          alignment: Alignment.center,
                          width: 132,
                          height: 132,
                          color: const Color(0xFF2F4D7E),
                          child: const Text(
                            'WWTD',
                            style: TextStyle(
                              color: Color(0xFFF4F0E4),
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        );
                      },
                ),
              ),
              const SizedBox(height: 24),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.18, end: 0.86),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeInOut,
                builder: (BuildContext context, double value, Widget? child) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(999),
                    backgroundColor: const Color(0xFFE2E8F0),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _handledSharedRoomId;
  bool _handlingSharedRoom = false;

  @override
  Widget build(BuildContext context) {
    final AppState appState = context.watch<AppState>();
    _handleSharedRoomLink(context, appState);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          appState.selectedRoom != null
              ? 'What would ${appState.selectedPerson} do?'
              : 'What Would They Do?',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        centerTitle: false,
        actions: <Widget>[
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

  void _handleSharedRoomLink(BuildContext context, AppState appState) {
    final String? roomId = Uri.base.queryParameters['room']?.trim();
    if (roomId == null ||
        roomId.isEmpty ||
        roomId == _handledSharedRoomId ||
        _handlingSharedRoom ||
        !appState.sessionReady ||
        !appState.isLoggedIn) {
      return;
    }
    _handlingSharedRoom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !context.mounted) {
        return;
      }
      final joinedRoom = appState.roomById(roomId);
      if (joinedRoom != null) {
        await appState.selectRoom(roomId);
        replaceRoomInUrl(roomId);
        _handledSharedRoomId = roomId;
        _handlingSharedRoom = false;
        return;
      }
      final preview = await appState.fetchRoomPreview(roomId);
      if (!mounted || !context.mounted) {
        return;
      }
      _handledSharedRoomId = roomId;
      _handlingSharedRoom = false;
      if (preview != null) {
        await showJoinRoomSheet(context, initialRoom: preview);
      }
    });
  }
}
