import XCTest
@testable import StretchCatCore

/// Behavior guard for the macOS app. These assertions intentionally mirror the
/// Rust tests in `windows/src-tauri/src/reminder.rs` — if the two ports drift,
/// one side goes red.
final class StretchCatCoreTests: XCTestCase {

    // MARK: Exercises

    func testExerciseListHasFiveEntries() {
        XCTAssertEqual(Exercise.all.count, 5)
    }

    func testEveryExerciseHasTitleAndCue() {
        for exercise in Exercise.all {
            XCTAssertFalse(exercise.name.isEmpty, "exercise name should not be empty")
            XCTAssertFalse(exercise.cue.isEmpty, "exercise cue should not be empty")
        }
    }

    func testRandomReturnsAValidExercise() {
        for _ in 0..<50 {
            let picked = Exercise.random(excluding: nil)
            XCTAssertTrue(Exercise.all.contains(picked))
        }
    }

    func testRandomAvoidsPreviousWhenPossible() {
        let previous = Exercise.all[0]
        // With 5 distinct exercises, excluding one must never return it.
        for _ in 0..<50 {
            XCTAssertNotEqual(Exercise.random(excluding: previous), previous)
        }
    }

    // MARK: Schedule constants

    func testDefaultIntervalIsTwoHours() {
        XCTAssertEqual(StretchSchedule.defaultIntervalHours, 2)
    }

    func testAllowedIntervals() {
        XCTAssertEqual(StretchSchedule.allowedIntervalHours, [1, 2, 3])
    }

    func testSnoozeIsTenMinutes() {
        XCTAssertEqual(StretchSchedule.snoozeMinutes, 10)
    }

    func testAutoCloseIsThirtySeconds() {
        XCTAssertEqual(StretchSchedule.autoCloseSeconds, 30)
    }

    // MARK: Schedule math

    func testNextFireDateAddsTheInterval() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        for hours in StretchSchedule.allowedIntervalHours {
            let fire = StretchSchedule.nextFireDate(from: base, intervalHours: hours)
            XCTAssertEqual(fire.timeIntervalSince(base), Double(hours * 3600), accuracy: 0.001)
        }
    }

    func testSnoozeFireDateAddsTenMinutes() {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let fire = StretchSchedule.snoozeFireDate(from: base)
        XCTAssertEqual(fire.timeIntervalSince(base), 600, accuracy: 0.001)
    }
}
