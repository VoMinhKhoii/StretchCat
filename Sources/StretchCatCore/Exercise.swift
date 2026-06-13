import Foundation

/// A short stretch prompt: a title + a follow-along cue. The cat video shows a
/// full routine, so these just add friendly variety to the notification/card.
///
/// Pure, platform-agnostic logic lives here so it can be unit-tested and kept
/// in lockstep with the Windows (Tauri) port — see `windows/reminder-core/src/lib.rs`.
public struct Exercise: Identifiable, Hashable {
    public let id = UUID()
    public let name: String
    public let cue: String

    public init(name: String, cue: String) {
        self.name = name
        self.cue = cue
    }

    public static let all: [Exercise] = [
        Exercise(name: "Big stretch", cue: "Reach up tall and lengthen your spine."),
        Exercise(name: "Loosen up", cue: "Sway side to side and roll your shoulders."),
        Exercise(name: "Hip hinge", cue: "Soft knees — hinge from the hips, then rise."),
        Exercise(name: "Side bend", cue: "Lean gently left, then right, and breathe."),
        Exercise(name: "Stand & stretch", cue: "Up on your feet — follow along with the cat!"),
    ]

    /// Pick a different prompt than `previous` when possible.
    public static func random(excluding previous: Exercise?) -> Exercise {
        let pool = all.filter { $0.id != previous?.id }
        return (pool.isEmpty ? all : pool).randomElement()!
    }
}
