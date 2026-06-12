import Foundation
import SwiftUI
import UserNotifications
import ServiceManagement
import AppKit

/// Owns the reminder schedule, notification posting, and persisted settings.
final class ReminderManager: ObservableObject {
    @Published var intervalHours: Int {
        didSet {
            defaults.set(intervalHours, forKey: Keys.interval)
            scheduleNext()
        }
    }

    @Published var isPaused: Bool {
        didSet {
            defaults.set(isPaused, forKey: Keys.paused)
            scheduleNext()
        }
    }

    @Published var launchAtLogin: Bool {
        didSet { updateLoginItem() }
    }

    /// When the next reminder will fire (nil while paused) — drives the
    /// live countdown in the dropdown panel.
    @Published var nextFireDate: Date? = nil

    /// Set by the app delegate — shows the animated cat window.
    var onStretch: ((Exercise) -> Void)?

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    private var lastExercise: Exercise?

    private enum Keys {
        static let interval = "intervalHours"
        static let paused = "isPaused"
    }

    init() {
        let savedInterval = defaults.object(forKey: Keys.interval) as? Int
        self.intervalHours = savedInterval ?? 2
        self.isPaused = defaults.bool(forKey: Keys.paused)
        self.launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    // MARK: Lifecycle

    func start() {
        requestNotificationAuthorization()
        // Catch up the instant the machine wakes, rather than waiting for the
        // next periodic tick. Sleep suspends timers, so a deadline that passed
        // mid-sleep would otherwise leave the countdown stuck until the tick.
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        scheduleNext()
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func systemDidWake() {
        checkDeadline()
    }

    /// Fire now if the scheduled deadline has already passed. Safe to call
    /// repeatedly — a no-op while paused, unscheduled, or still counting down.
    private func checkDeadline() {
        guard !isPaused, let due = nextFireDate, Date() >= due else { return }
        fire()
    }

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: Scheduling

    private func scheduleNext() {
        timer?.invalidate()
        timer = nil

        guard !isPaused else {
            DispatchQueue.main.async { self.nextFireDate = nil }
            return
        }

        let interval = TimeInterval(intervalHours * 3600)
        let fireDate = Date().addingTimeInterval(interval)
        DispatchQueue.main.async { self.nextFireDate = fireDate }

        // A repeating deadline check, not a single one-shot timer: a one-shot
        // Timer scheduled hours out can be dropped across system sleep / App Nap,
        // leaving the countdown stuck at "under a minute" with no reminder ever
        // firing. This ticks periodically and fires the moment it sees the
        // deadline has passed (e.g. right after the machine wakes).
        let t = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.checkDeadline()
        }
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func fire() {
        let exercise = Exercise.random(excluding: lastExercise)
        lastExercise = exercise
        postNotification(for: exercise)
        onStretch?(exercise)
        scheduleNext()
    }

    /// Menu action: stretch immediately and reset the countdown.
    func stretchNow() {
        let exercise = Exercise.random(excluding: lastExercise)
        lastExercise = exercise
        onStretch?(exercise)
        scheduleNext()
    }

    func togglePause() {
        isPaused.toggle()
    }

    // MARK: Notifications

    private func postNotification(for exercise: Exercise) {
        let content = UNMutableNotificationContent()
        content.title = "Time to stretch! 🐾"
        content.body = "\(exercise.name) — \(exercise.cue)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Launch at login

    private func updateLoginItem() {
        do {
            if launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Best-effort: non-fatal for dev/unsigned builds.
            NSLog("Launch-at-login update failed: \(error.localizedDescription)")
        }
    }
}
