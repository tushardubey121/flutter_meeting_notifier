import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'config.dart';
import 'services/calendar_service.dart';
import 'services/overlay_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();

  // Closing the window should hide it, not quit — the app keeps watching
  // the calendar from the menu bar.
  await windowManager.setPreventClose(true);

  // Auto-start at login so it's always running in the background.
  await _setupLaunchAtStartup();

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

Future<void> _setupLaunchAtStartup() async {
  try {
    launchAtStartup.setup(
      appName: 'Meeting Notifier',
      appPath: Platform.resolvedExecutable,
    );
    await launchAtStartup.enable();
  } catch (e) {
    // Fails for unbundled debug runs — harmless.
    debugPrint('Launch-at-startup setup failed: $e');
  }
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

class _AppShellState extends State<AppShell>
    with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    _initTray();

    // Give silent sign-in a moment; if the user still isn't signed in,
    // bring the window up so they can sign in once.
    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;
      final service = context.read<CalendarService>();
      if (!service.isSignedIn) {
        await OverlayService.showWindow();
      }
    });
  }

  Future<void> _initTray() async {
    // Plane glyph in the menu bar — no icon asset needed.
    await trayManager.setTitle('✈');
    await trayManager.setToolTip('Meeting Notifier');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'open',
            label: 'Open Meeting Notifier',
          ),
          MenuItem(
            key: 'test',
            label: 'Test fly-over (meeting in $kAlertLeadMinutes min)',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'quit',
            label: 'Quit',
          ),
        ],
      ),
    );
  }

  @override
  void onTrayIconMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        OverlayService.showWindow();
        break;
      case 'test':
        context.read<CalendarService>().triggerTestAlert();
        break;
      case 'quit':
        windowManager.destroy().then((_) => exit(0));
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
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
