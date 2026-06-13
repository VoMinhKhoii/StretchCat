//! Pure, platform-agnostic StretchCat logic: the exercise prompts and the
//! reminder schedule math.
//!
//! This is the Windows counterpart to `Sources/StretchCatCore/` in the macOS
//! app. The values and behavior here are asserted by the tests below AND by the
//! Swift `StretchCatCoreTests` — keep the two in lockstep so the two ports can't
//! drift apart silently.

use std::time::Duration;

/// A short stretch prompt: a title + a follow-along cue.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Exercise {
    pub name: &'static str,
    pub cue: &'static str,
}

/// The five stretch prompts. Must match `Exercise.all` in the macOS app.
pub const EXERCISES: [Exercise; 5] = [
    Exercise {
        name: "Big stretch",
        cue: "Reach up tall and lengthen your spine.",
    },
    Exercise {
        name: "Loosen up",
        cue: "Sway side to side and roll your shoulders.",
    },
    Exercise {
        name: "Hip hinge",
        cue: "Soft knees — hinge from the hips, then rise.",
    },
    Exercise {
        name: "Side bend",
        cue: "Lean gently left, then right, and breathe.",
    },
    Exercise {
        name: "Stand & stretch",
        cue: "Up on your feet — follow along with the cat!",
    },
];

/// Reminder interval chosen on first launch.
pub const DEFAULT_INTERVAL_HOURS: u32 = 2;
/// Selectable reminder intervals, in hours.
pub const ALLOWED_INTERVAL_HOURS: [u32; 3] = [1, 2, 3];
/// How long "Snooze" defers the next stretch, in minutes.
pub const SNOOZE_MINUTES: u64 = 10;
/// The stretch card auto-dismisses after this many seconds.
pub const AUTO_CLOSE_SECONDS: u64 = 30;

/// Time from now until the next regular reminder, `interval_hours` out.
pub fn interval_duration(interval_hours: u32) -> Duration {
    Duration::from_secs(interval_hours as u64 * 3600)
}

/// Time from now until a snoozed reminder fires.
pub fn snooze_duration() -> Duration {
    Duration::from_secs(SNOOZE_MINUTES * 60)
}

/// Pick an exercise, avoiding `previous` when possible. `rng_unit` is a caller-
/// supplied random number in `[0, 1)` so this stays pure and testable.
pub fn pick_exercise(previous: Option<&Exercise>, rng_unit: f64) -> &'static Exercise {
    let pool: Vec<&'static Exercise> = EXERCISES
        .iter()
        .filter(|e| previous.is_none_or(|p| p.name != e.name))
        .collect();
    let pool = if pool.is_empty() {
        EXERCISES.iter().collect()
    } else {
        pool
    };
    let idx = ((rng_unit.clamp(0.0, 0.999_999) * pool.len() as f64) as usize).min(pool.len() - 1);
    pool[idx]
}

/// Tracks when the next reminder is due.
///
/// Times are absolute "seconds since the unix epoch" (wall clock), not a
/// monotonic countdown, so the schedule survives the machine sleeping: on every
/// tick we compare `now` against `next_fire` and fire the moment it has passed —
/// mirroring the macOS app's wake-aware deadline check.
#[derive(Debug, Clone)]
pub struct Schedule {
    pub interval_hours: u32,
    pub enabled: bool,
    /// Absolute time (secs since epoch) the next reminder fires; `None` while paused.
    pub next_fire: Option<u64>,
}

impl Schedule {
    /// A schedule with no reminder armed yet — call [`Schedule::arm`] to start it.
    pub fn new(interval_hours: u32, enabled: bool) -> Self {
        Self {
            interval_hours,
            enabled,
            next_fire: None,
        }
    }

    /// Arm the next regular fire relative to `now`. Clears the deadline while paused.
    pub fn arm(&mut self, now: u64) {
        self.next_fire = if self.enabled {
            Some(now + self.interval_hours as u64 * 3600)
        } else {
            None
        };
    }

    /// Arm a snoozed fire (`SNOOZE_MINUTES` out) relative to `now`.
    pub fn snooze(&mut self, now: u64) {
        self.next_fire = Some(now + SNOOZE_MINUTES * 60);
    }

    /// Whether a reminder is due at `now` (false while paused or unscheduled).
    pub fn is_due(&self, now: u64) -> bool {
        self.enabled && self.next_fire.is_some_and(|t| now >= t)
    }

    /// Seconds remaining until the next fire at `now` (`None` while paused).
    pub fn seconds_remaining(&self, now: u64) -> Option<u64> {
        self.next_fire.map(|t| t.saturating_sub(now))
    }

    /// Pause / resume, re-arming relative to `now`.
    pub fn set_enabled(&mut self, enabled: bool, now: u64) {
        self.enabled = enabled;
        self.arm(now);
    }

    /// Change the interval, re-arming relative to `now`.
    pub fn set_interval(&mut self, interval_hours: u32, now: u64) {
        self.interval_hours = interval_hours;
        self.arm(now);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // --- Exercises (mirrors StretchCatCoreTests exercise cases) ---

    #[test]
    fn exercise_list_has_five_entries() {
        assert_eq!(EXERCISES.len(), 5);
    }

    #[test]
    fn every_exercise_has_title_and_cue() {
        for e in EXERCISES {
            assert!(!e.name.is_empty(), "name should not be empty");
            assert!(!e.cue.is_empty(), "cue should not be empty");
        }
    }

    #[test]
    fn pick_returns_a_valid_exercise() {
        for i in 0..50 {
            let r = i as f64 / 50.0;
            let picked = pick_exercise(None, r);
            assert!(EXERCISES.iter().any(|e| e == picked));
        }
    }

    #[test]
    fn pick_avoids_previous_when_possible() {
        let previous = &EXERCISES[0];
        for i in 0..50 {
            let r = i as f64 / 50.0;
            assert_ne!(pick_exercise(Some(previous), r), previous);
        }
    }

    // --- Schedule constants (mirrors StretchCatCoreTests constant cases) ---

    #[test]
    fn default_interval_is_two_hours() {
        assert_eq!(DEFAULT_INTERVAL_HOURS, 2);
    }

    #[test]
    fn allowed_intervals() {
        assert_eq!(ALLOWED_INTERVAL_HOURS, [1, 2, 3]);
    }

    #[test]
    fn snooze_is_ten_minutes() {
        assert_eq!(SNOOZE_MINUTES, 10);
    }

    #[test]
    fn auto_close_is_thirty_seconds() {
        assert_eq!(AUTO_CLOSE_SECONDS, 30);
    }

    // --- Schedule math ---

    #[test]
    fn interval_duration_matches_hours() {
        for h in ALLOWED_INTERVAL_HOURS {
            assert_eq!(interval_duration(h), Duration::from_secs(h as u64 * 3600));
        }
    }

    #[test]
    fn snooze_duration_is_ten_minutes() {
        assert_eq!(snooze_duration(), Duration::from_secs(600));
    }

    // --- Schedule state machine ---

    #[test]
    fn arm_sets_deadline_an_interval_out() {
        let mut s = Schedule::new(2, true);
        s.arm(1_000);
        assert_eq!(s.next_fire, Some(1_000 + 2 * 3600));
    }

    #[test]
    fn not_due_before_deadline_due_after() {
        let mut s = Schedule::new(1, true);
        s.arm(1_000);
        assert!(!s.is_due(1_000));
        assert!(!s.is_due(1_000 + 3599));
        assert!(s.is_due(1_000 + 3600));
        assert!(s.is_due(1_000 + 9999)); // stays due (e.g. fires right after wake)
    }

    #[test]
    fn paused_clears_deadline_and_never_fires() {
        let mut s = Schedule::new(2, true);
        s.arm(1_000);
        s.set_enabled(false, 2_000);
        assert_eq!(s.next_fire, None);
        assert!(!s.is_due(9_999_999));
    }

    #[test]
    fn resume_re_arms() {
        let mut s = Schedule::new(2, false);
        s.set_enabled(true, 5_000);
        assert_eq!(s.next_fire, Some(5_000 + 2 * 3600));
    }

    #[test]
    fn snooze_arms_ten_minutes_out() {
        let mut s = Schedule::new(2, true);
        s.snooze(1_000);
        assert_eq!(s.next_fire, Some(1_000 + 600));
        assert!(s.is_due(1_600));
    }

    #[test]
    fn set_interval_re_arms_with_new_interval() {
        let mut s = Schedule::new(2, true);
        s.set_interval(3, 1_000);
        assert_eq!(s.interval_hours, 3);
        assert_eq!(s.next_fire, Some(1_000 + 3 * 3600));
    }

    #[test]
    fn seconds_remaining_counts_down() {
        let mut s = Schedule::new(1, true);
        s.arm(1_000);
        assert_eq!(s.seconds_remaining(1_000), Some(3600));
        assert_eq!(s.seconds_remaining(1_600), Some(3000));
        assert_eq!(s.seconds_remaining(99_999), Some(0)); // saturates, never underflows
    }
}
