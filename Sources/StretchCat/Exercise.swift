import Foundation

/// A short stretch prompt: a title + a follow-along cue. The cat video shows a
/// full routine, so these just add friendly variety to the notification/card.
struct Exercise: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let cue: String

    static let all: [Exercise] = [
        Exercise(name: "Big stretch", cue: "Reach up tall and lengthen your spine."),
        Exercise(name: "Loosen up", cue: "Sway side to side and roll your shoulders."),
        Exercise(name: "Hip hinge", cue: "Soft knees — hinge from the hips, then rise."),
        Exercise(name: "Side bend", cue: "Lean gently left, then right, and breathe."),
        Exercise(name: "Stand & stretch", cue: "Up on your feet — follow along with the cat!"),
    ]

    /// Pick a different prompt than `previous` when possible.
    static func random(excluding previous: Exercise?) -> Exercise {
        let pool = all.filter { $0.id != previous?.id }
        return (pool.isEmpty ? all : pool).randomElement()!
    }
}
