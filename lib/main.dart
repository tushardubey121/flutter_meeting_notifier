import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'config.dart';
import 'services/calendar_service.dart';
import 'services/overlay_service.dart';
import 'services/watchdog_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  // Closing the window should hide it, not quit — the app keeps watching
  // the calendar from the menu bar.
  await windowManager.setPreventClose(true);

  // Keep-alive watchdog: starts the app at login AND relaunches it within
  // ~30s if it crashes or is killed.
  await WatchdogService.install();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(420, 620),
    minimumSize: Size(380, 500),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'Meeting Notifier',
  );

  // Note: we intentionally do NOT show the window here. The app starts
  // silently in the background (menu bar). If the user isn't signed in yet,
  // the shell below pops the window so they can sign in once.
  await windowManager.waitUntilReadyToShow(windowOptions, () async {});

  runApp(
    ChangeNotifierProvider(
      create: (_) => CalendarService(),
      child: const MeetingNotifierApp(),
    ),
  );
}

class MeetingNotifierApp extends StatelessWidget {
  const MeetingNotifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meeting Notifier',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display', // falls back to system font
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const AppShell(),
    );
  }
}

/// Hosts the menu-bar (tray) icon, window lifecycle handling, and the
/// "show window if not signed in yet" first-run behavior.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initTray();
    _maybeShowFirstRunWindow();
  }

  /// Pops the window ONLY on the very first launch after install, so the
  /// user can sign in once. Every later start (login, watchdog relaunch,
  /// reboot) is fully silent — the app is reachable from the ✈ menu bar icon.
  Future<void> _maybeShowFirstRunWindow() async {
    try {
      final home = Platform.environment['HOME'] ?? '';
      final marker = File(
          '$home/Library/Application Support/meeting_notifier/first_run_done');
      if (await marker.exists()) return;
      await marker.create(recursive: true);

      // Give silent sign-in a moment before deciding.
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return;
      final service = context.read<CalendarService>();
      if (!service.isSignedIn) {
        await OverlayService.showWindow();
      }
    } catch (e) {
      debugPrint('First-run check failed: $e');
    }
  }

  Future<void> _initTray() async {
    // Native NSStatusItem (created in MainFlutterWindow.swift) — shows an
    // airplane SF Symbol next to the wifi/battery icons.
    await OverlayService.initTray(
      testLabel: 'Test fly-over (meeting in $kAlertLeadMinutes min)',
      onMenuClick: _onTrayMenuClick,
    );
  }

  void _onTrayMenuClick(String key) {
    switch (key) {
      case 'open':
        OverlayService.showWindow();
        break;
      case 'test':
        context.read<CalendarService>().triggerTestAlert();
        break;
      case 'quit':
        // Remove the watchdog first so the quit isn't undone 30s later.
        WatchdogService.uninstall()
            .then((_) => windowManager.destroy())
            .then((_) => exit(0));
        break;
    }
  }

  // Close button hides the window; the app keeps running in the menu bar.
  @override
  void onWindowClose() async {
    final prevented = await windowManager.isPreventClose();
    if (prevented) {
      await OverlayService.hideWindow();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
