import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Keep running in the background when the window is closed —
  // the app lives in the menu bar and watches the calendar.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
