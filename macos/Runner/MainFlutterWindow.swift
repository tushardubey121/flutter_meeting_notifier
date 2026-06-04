import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var savedFrame: NSRect?
  private var savedStyleMask: NSWindow.StyleMask?
  private var savedLevel: NSWindow.Level?
  private var wasVisibleBeforeOverlay = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Flutter's render surface must itself be transparent, otherwise the
    // overlay shows as a black rectangle (the window background alone is
    // not enough — the Metal layer paints opaque black by default).
    flutterViewController.backgroundColor = .clear
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    setupOverlayChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func setupOverlayChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "meeting_notifier/overlay",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "NO_WINDOW", message: "Window gone", details: nil))
        return
      }

      switch call.method {
      case "enterOverlay":
        let args = call.arguments as? [String: Any]
        let height = CGFloat(args?["height"] as? Double ?? 240)
        self.enterOverlay(stripHeight: height)
        // Report the overlay width back so Flutter can size the animation
        result(Double(self.frame.width))

      case "exitOverlay":
        self.exitOverlay()
        result(nil)

      case "hideWindow":
        self.orderOut(nil)
        result(nil)

      case "showWindow":
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)
        result(nil)

      case "isWindowVisible":
        result(self.isVisible)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Transforms the window into a transparent, borderless, always-on-top strip
  /// across the top of the screen. Shown WITHOUT stealing focus from the
  /// frontmost app, and visible over full-screen apps and all Spaces.
  private func enterOverlay(stripHeight: CGFloat) {
    guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }

    wasVisibleBeforeOverlay = self.isVisible
    savedFrame = self.frame
    savedStyleMask = self.styleMask
    savedLevel = self.level

    self.styleMask = [.borderless, .fullSizeContentView]
    self.isOpaque = false
    self.backgroundColor = .clear
    (self.contentViewController as? FlutterViewController)?.backgroundColor = .clear
    self.hasShadow = false
    self.isMovable = false
    self.level = .screenSaver
    self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

    let sf = screen.frame
    let overlayFrame = NSRect(
      x: sf.minX,
      y: sf.maxY - stripHeight,
      width: sf.width,
      height: stripHeight
    )
    self.setFrame(overlayFrame, display: true)

    // Show on top of everything without activating the app / stealing focus
    self.orderFrontRegardless()
  }

  /// Restores the window to its normal chrome. If it was hidden in the
  /// background before the fly-over, it goes back to hidden.
  private func exitOverlay() {
    self.level = savedLevel ?? .normal
    self.styleMask = savedStyleMask ?? [.titled, .closable, .miniaturizable, .resizable]
    self.collectionBehavior = []
    self.isOpaque = true
    self.backgroundColor = .windowBackgroundColor
    self.hasShadow = true
    self.isMovable = true
    self.title = "Meeting Notifier"

    if let frame = savedFrame {
      self.setFrame(frame, display: true)
    }

    if wasVisibleBeforeOverlay {
      self.orderFront(nil)
    } else {
      self.orderOut(nil)
    }
  }
}
