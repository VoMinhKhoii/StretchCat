import SwiftUI
import AppKit

@main
struct StretchCatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuPanel(manager: appDelegate.manager, dismiss: {})
        } label: {
            Image(nsImage: MenuBarIcon.image)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The custom cat-face menu-bar icon (a black template image macOS recolors
/// for light/dark menu bars). Works on every macOS version, unlike the
/// `cat.fill` SF Symbol which needs macOS 14+.
enum MenuBarIcon {
    static let image: NSImage = {
        let url = Bundle.main.url(forResource: "MenuBarCat@2x", withExtension: "png")
            ?? Bundle.main.url(forResource: "MenuBarCat", withExtension: "png")
        let img = url.flatMap { NSImage(contentsOf: $0) } ?? NSImage()
        img.size = NSSize(width: 18, height: 15)
        img.isTemplate = true
        return img
    }()
}

/// Wires the reminder manager to the floating cat window and handles app launch.
final class AppDelegate: NSObject, NSApplicationDelegate {
    let manager = ReminderManager()
    private let popup = PopupController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        manager.onStretch = { [weak self] exercise in
            self?.popup.show(exercise, onSnooze: { [weak self] in
                self?.snooze()
            })
        }
        manager.start()

        // Verification hook: STRETCHCAT_DEMO=1 shows the cat popup on launch.
        if ProcessInfo.processInfo.environment["STRETCHCAT_DEMO"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.popup.show(Exercise.all.randomElement()!, onSnooze: {})
            }
        }

        // Layout snapshot hook: STRETCHCAT_SNAPSHOT=/path STRETCHCAT_VIEW=card|panel
        if let path = ProcessInfo.processInfo.environment["STRETCHCAT_SNAPSHOT"] {
            renderSnapshot(to: path)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { NSApp.terminate(nil) }
        }
    }

    private func renderSnapshot(to path: String) {
        let which = ProcessInfo.processInfo.environment["STRETCHCAT_VIEW"] ?? "card"
        let root: AnyView = which == "panel"
            ? AnyView(MenuPanel(manager: manager, dismiss: {}).background(Color(white: 0.12)))
            : AnyView(StretchView(exercise: Exercise.all[0], onDone: {}, onSnooze: {})
                .padding(20).background(Color(white: 0.12)))
        let hosting = NSHostingView(rootView: root)
        hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = hosting
        window.layoutIfNeeded()
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    /// Snooze: re-show a break in 10 minutes without disturbing the cadence.
    private func snooze() {
        let snoozeTimer = Timer(timeInterval: 10 * 60, repeats: false) { [weak self] _ in
            self?.manager.stretchNow()
        }
        RunLoop.main.add(snoozeTimer, forMode: .common)
    }
}

/// Manages a single floating, borderless card window for the cat.
final class PopupController {
    private var window: NSWindow?

    func show(_ exercise: Exercise, onSnooze: @escaping () -> Void) {
        close()

        let view = StretchView(
            exercise: exercise,
            onDone: { [weak self] in self?.close() },
            onSnooze: { [weak self] in
                self?.close()
                onSnooze()
            }
        )

        let hosting = NSHostingController(rootView: view)
        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.titled, .fullSizeContentView, .closable]
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.standardWindowButton(.closeButton)?.isHidden = true
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false   // the SwiftUI card draws its own shadow
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.center()

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        self.window = win
    }

    func close() {
        window?.orderOut(nil)
        window = nil
    }
}
