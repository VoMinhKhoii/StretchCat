import SwiftUI
import AppKit
import UserNotifications

@main
struct StretchCatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // The menu bar item is managed directly via NSStatusItem in AppDelegate so
    // we can detect when the icon is hidden behind the notch (occlusionState).
    // This empty scene just keeps the SwiftUI App alive; LSUIElement keeps it
    // out of the Dock.
    var body: some Scene {
        Settings { EmptyView() }
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

    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    /// Debounce token so a brief, transient occlusion doesn't trigger the warning.
    private var notchCheck: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()

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

    // MARK: Menu bar status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = MenuBarIcon.image
        item.button?.action = #selector(togglePanel(_:))
        item.button?.target = self
        statusItem = item

        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuPanel(manager: manager, dismiss: { [weak self] in
                self?.popover.performClose(nil)
            })
        )

        // The status item's window isn't attached synchronously — observe its
        // occlusion on the next runloop tick so we can tell when the icon gets
        // hidden behind the notch (the only signal macOS offers; isVisible
        // stays true even when hidden). See Tailscale's same workaround.
        DispatchQueue.main.async { [weak self] in
            guard let self, let win = self.statusItem.button?.window else { return }
            NotificationCenter.default.addObserver(
                self, selector: #selector(self.occlusionChanged(_:)),
                name: NSWindow.didChangeOcclusionStateNotification, object: win)
        }
    }

    @objc private func togglePanel(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    @objc private func occlusionChanged(_ note: Notification) {
        guard let win = note.object as? NSWindow else { return }
        notchCheck?.cancel()
        guard !win.occlusionState.contains(.visible) else { return }

        // Only warn if still hidden ~3s later, so opening a menu (which briefly
        // occludes the bar) doesn't trip it.
        let work = DispatchWorkItem { [weak self, weak win] in
            guard let win, !win.occlusionState.contains(.visible) else { return }
            self?.warnHiddenBehindNotchOnce()
        }
        notchCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }

    /// Posts a single lifetime notification guiding the user when the cat icon
    /// is buried behind the notch. Reminders keep firing regardless.
    private func warnHiddenBehindNotchOnce() {
        let key = "didWarnNotchHidden"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let content = UNMutableNotificationContent()
        content.title = "Stretch Cat is hidden behind the notch 🐾"
        content.body = "Your menu bar is full. ⌘-drag the cat icon left, or remove an item, to open its controls. Reminders still work."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
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
