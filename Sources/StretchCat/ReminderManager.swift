import Foundation
import SwiftUI
import UserNotifications
import ServiceManagement

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
        scheduleNext()
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

        let t = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.fire()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        DispatchQueue.main.async { self.nextFireDate = fireDate }
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
