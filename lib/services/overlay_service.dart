import 'package:flutter/services.dart';

/// Talks to the native macOS side (MainFlutterWindow.swift) to turn the
/// window into a transparent always-on-top overlay strip — shown over every
/// app (IntelliJ, full-screen apps, all Spaces) without stealing focus.
class OverlayService {
  static const _channel = MethodChannel('meeting_notifier/overlay');

  /// Height of the transparent strip at the top of the screen that hosts
  /// the plane fly-over.
  static const double overlayHeight = 240;

  /// Enters overlay mode. Returns the overlay width (= screen width) so the
  /// animation knows how far the plane must travel.
  static Future<double> enterOverlay() async {
    final width = await _channel.invokeMethod<double>(
      'enterOverlay',
      {'height': overlayHeight},
    );
    return width ?? 1920;
  }

  /// Restores the window to normal chrome. If it was hidden in the
  /// background before the fly-over, it stays hidden.
  static Future<void> exitOverlay() => _channel.invokeMethod('exitOverlay');

  /// Hides the main window (app keeps running in the menu bar).
  static Future<void> hideWindow() => _channel.invokeMethod('hideWindow');

  /// Shows and focuses the main window.
  static Future<void> showWindow() => _channel.invokeMethod('showWindow');

  static Future<bool> isWindowVisible() async =>
      await _channel.invokeMethod<bool>('isWindowVisible') ?? false;

  /// Creates the native menu bar (status) item with its menu, and registers
  /// [onMenuClick] for menu selections ('open' | 'test' | 'quit').
  static Future<void> initTray({
    required String testLabel,
    required void Function(String key) onMenuClick,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'trayMenuClick') {
        onMenuClick(call.arguments as String);
      }
      return null;
    });
    await _channel.invokeMethod('initTray', {'testLabel': testLabel});
  }
}
