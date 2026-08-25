import 'dart:io';

import 'package:flutter/foundation.dart';

/// Installs a launchd LaunchAgent that keeps the app alive:
/// - starts the app at login (replaces the old login item), and
/// - relaunches it within ~30s if it crashes or gets killed.
///
/// Quitting from the tray menu calls [uninstall] first, so an intentional
/// quit stays quit.
class WatchdogService {
  static const _label = 'com.meetingnotifier.watchdog';
  static const _checkIntervalSeconds = 30;

  static String get _plistPath =>
      '${Platform.environment['HOME']}/Library/LaunchAgents/$_label.plist';

  /// Path of the .app bundle this process is running from.
  static String? get _appBundlePath {
    final exe = Platform.resolvedExecutable;
    final idx = exe.indexOf('.app/');
    if (idx == -1) return null;
    return exe.substring(0, idx + 4);
  }

  static Future<String?> _uid() async {
    final result = await Process.run('id', ['-u']);
    if (result.exitCode != 0) return null;
    return (result.stdout as String).trim();
  }

  /// Idempotent — writes the LaunchAgent and (re)loads it. Skipped for
  /// debug builds so dev runs don't get resurrected by the watchdog.
  static Future<void> install() async {
    if (!Platform.isMacOS || kDebugMode) return;

    final bundle = _appBundlePath;
    final uid = await _uid();
    if (bundle == null || uid == null) return;

    try {
      // The [m] bracket trick stops pgrep from matching the watchdog's own
      // shell command line.
      final marker = bundle.replaceFirst('m', '[m]');
      final script =
          'pgrep -f "$marker/Contents/MacOS/" >/dev/null || open -a "$bundle"';

      final plist = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$_label</string>
	<key>ProgramArguments</key>
	<array>
		<string>/bin/sh</string>
		<string>-c</string>
		<string>$script</string>
	</array>
	<key>RunAtLoad</key>
	<true/>
	<key>StartInterval</key>
	<integer>$_checkIntervalSeconds</integer>
</dict>
</plist>
''';

      final file = File(_plistPath);
      await file.parent.create(recursive: true);
      await file.writeAsString(plist);

      // Reload: bootout may fail if not loaded yet — that's fine.
      await Process.run('launchctl', ['bootout', 'gui/$uid/$_label']);
      await Process.run('launchctl', ['bootstrap', 'gui/$uid', _plistPath]);
      debugPrint('Watchdog installed ($_plistPath)');
    } catch (e) {
      debugPrint('Watchdog install failed: $e');
    }
  }

  /// Removes the watchdog so an intentional quit is not undone.
  static Future<void> uninstall() async {
    if (!Platform.isMacOS) return;
    try {
      final uid = await _uid();
      if (uid != null) {
        await Process.run('launchctl', ['bootout', 'gui/$uid/$_label']);
      }
      final file = File(_plistPath);
      if (await file.exists()) await file.delete();
      debugPrint('Watchdog removed');
    } catch (e) {
      debugPrint('Watchdog uninstall failed: $e');
    }
  }
}
