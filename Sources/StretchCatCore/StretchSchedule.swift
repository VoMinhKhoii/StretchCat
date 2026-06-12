import Foundation

/// Timing constants and pure scheduling math shared by the app and its tests.
///
/// These values define StretchCat's behavior and MUST stay in lockstep with the
/// Windows (Tauri) port in `windows/src-tauri/src/reminder.rs`. The matching unit
/// tests on both sides assert the same numbers, so changing one without the other
/// turns a test red.
public enum StretchSchedule {
    /// Reminder interval chosen on first launch.
    public static let defaultIntervalHours = 2

    /// Selectable reminder intervals, in hours.
    public static let allowedIntervalHours = [1, 2, 3]

    /// How long "Snooze" defers the next stretch, in minutes.
    public static let snoozeMinutes = 10

    /// The stretch card auto-dismisses after this many seconds.
    public static let autoCloseSeconds = 30

    /// The next regular fire date, `intervalHours` after `date`.
    public static func nextFireDate(from date: Date, intervalHours: Int) -> Date {
        date.addingTimeInterval(TimeInterval(intervalHours * 3600))
    }

    /// The deferred fire date after a snooze.
    public static func snoozeFireDate(from date: Date) -> Date {
        date.addingTimeInterval(TimeInterval(snoozeMinutes * 60))
    }
}
