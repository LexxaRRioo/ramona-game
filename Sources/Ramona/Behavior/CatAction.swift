import Foundation

/// The placeholder-era state machine's states. Real content (feeding, toys,
/// meme behaviors) arrives in later phases as more cases / richer scoring.
enum CatAction: Hashable, CaseIterable {
    case walk
    case idle
    case sleep
    /// "Приходит туда куда внимание обращено" / "грозно смотрит когда на
    /// неё долго не обращают внимание" - when neglected long enough she
    /// goes looking for attention instead of just pacing. Sated instantly
    /// by BehaviorEngine.pet(), unlike the other needs (nothing restores
    /// them yet - that's feeding/toys in Phase 5).
    case seekAttention
    /// "Р. любит забираться на высокие предметы. И в принципе любит
    /// возвышенности" - an occasional, trait-gated urge to be up on a
    /// window's top edge, not the default place she lives (see CatScene's
    /// currentSurface, which is the floor unless she's actively climbing,
    /// was just dropped on a window, or that window itself moved under her).
    case climb
    /// "Cleans herself" - sits and grooms. A content, between-walks rest
    /// activity, so she isn't pacing whenever she's awake.
    case groom
    /// Actively playing with a toy (the cable tie, to start) - distinct
    /// from .walk's incidental play-fill (see NeedsState.decay's isPlaying
    /// branch), gated on a toy actually being out the same way .climb is
    /// gated on a window being trackable. Driven by `playDrive`, not `play`
    /// itself - a separate "wants a dedicated session" urge that resets
    /// once a session fills the play meter (BehaviorEngine.onPlaySessionComplete).
    case play

    /// Human-readable label for the debug "Force Action" menu.
    var debugName: String {
        switch self {
        case .walk: return "Walk"
        case .idle: return "Sit / Idle"
        case .sleep: return "Sleep"
        case .seekAttention: return "Seek Attention"
        case .climb: return "Climb"
        case .groom: return "Groom"
        case .play: return "Play"
        }
    }

    /// Relative-frequency tuning knobs (backlog: "3x less walking, 2x more
    /// sleeping, 1x more grooming"): scaling walk down and sleep up against
    /// each other already shifts groom's relative win-rate up too, without
    /// needing to touch groom's own formula directly.
    static let walkFrequencyMultiplier: Double = 1.0 / 3.0
    static let sleepFrequencyMultiplier: Double = 2.0

    /// Utility AI: each candidate scores itself from needs/traits/time of
    /// day; BehaviorEngine runs the highest scorer. Nothing here rules an
    /// action out entirely - e.g. sleep outside a nap window still scores
    /// low-but-nonzero, so the cat can nap on demand if energy runs low
    /// enough, not just at scheduled hours. climb is the one exception: it's
    /// hard-gated to 0 with no window to climb onto, since "climb toward
    /// nothing" isn't a real option the way "nap outside nap hours" is.
    /// Added to climb's score when `higherPerchAvailable` is true - "actively
    /// evaluate whether there's a reachable nearest highest point and prefer
    /// it" (BACKLOG), big enough to clear actionSwitchMargin against idle's
    /// constant 0.45 baseline for any trait combination, not just bold cats.
    static let climbPreferenceBoost: Double = 0.3

    func score(needs: NeedsState, traits: SpeciesDefinition.TraitWeights, sleepWindows: [SleepWindow], hour: Double, windowAvailable: Bool, higherPerchAvailable: Bool, toyAvailable: Bool) -> Double {
        switch self {
        case .sleep:
            var score = (1 - needs.energy) * (0.5 + traits.laziness)
            if sleepWindows.contains(where: { $0.contains(hour: hour) }) {
                score += 0.4
            }
            return score * Self.sleepFrequencyMultiplier
        case .walk:
            return ((1 - needs.play) * (0.5 + traits.playfulness) + traits.boldness * 0.2) * Self.walkFrequencyMultiplier
        case .idle:
            // A steady resting default, so she settles rather than paces
            // whenever nothing else has a strong reason to win.
            return 0.45
        case .groom:
            // Grooms when content and rested (play satisfied, still awake) -
            // the "cleans herself" lull right after a walk restores her play.
            return 0.3 + needs.play * 0.25 + needs.energy * 0.1
        case .seekAttention:
            return (1 - needs.social) * (0.5 + traits.sociability)
        case .climb:
            guard windowAvailable else { return 0 }
            let base = traits.boldness * 0.6 + traits.playfulness * 0.1
            return higherPerchAvailable ? base + Self.climbPreferenceBoost : base
        case .play:
            guard toyAvailable else { return 0 }
            return (1 - needs.playDrive) * (0.5 + traits.playfulness)
        }
    }
}
