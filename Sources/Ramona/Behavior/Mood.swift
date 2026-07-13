import Foundation

/// Derived purely from needs. Since NeedsState never drops below its floor,
/// this can never express anything worse than grumpy - matching the hard
/// requirement that the cat can never appear sick, neglected, or "dead".
enum Mood: Int, Comparable {
    case grumpy
    case content
    case happy

    static func < (lhs: Mood, rhs: Mood) -> Bool { lhs.rawValue < rhs.rawValue }

    init(needs: NeedsState) {
        let average = (needs.hunger + needs.energy + needs.play + needs.social) / 4
        switch average {
        case 0.7...:
            self = .happy
        case 0.4..<0.7:
            self = .content
        default:
            self = .grumpy
        }
    }
}
