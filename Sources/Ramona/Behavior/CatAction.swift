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

    /// Human-readable label for the debug "Force Action" menu.
    var debugName: String {
        switch self {
        case .walk: return "Walk"
        case .idle: return "Sit / Idle"
        case .sleep: return "Sleep"
        case .seekAttention: return "Seek Attention"
        case .climb: return "Climb"
        }
    }

    /// Utility AI: each candidate scores itself from needs/traits/time of
    /// day; BehaviorEngine runs the highest scorer. Nothing here rules an
    /// action out entirely - e.g. sleep outside a nap window still scores
    /// low-but-nonzero, so the cat can nap on demand if energy runs low
    /// enough, not just at scheduled hours. climb is the one exception: it's
    /// hard-gated to 0 with no window to climb onto, since "climb toward
    /// nothing" isn't a real option the way "nap outside nap hours" is.
    func score(needs: NeedsState, traits: SpeciesDefinition.TraitWeights, sleepWindows: [SleepWindow], hour: Double, windowAvailable: Bool) -> Double {
        switch self {
        case .sleep:
            var score = (1 - needs.energy) * (0.5 + traits.laziness)
            if sleepWindows.contains(where: { $0.contains(hour: hour) }) {
                score += 0.4
            }
            return score
        case .walk:
            return (1 - needs.play) * (0.5 + traits.playfulness) + traits.boldness * 0.2
        case .idle:
            // Always a modest contender, so it only wins when sleep and
            // walk both have little reason to.
            return 0.35
        case .seekAttention:
            return (1 - needs.social) * (0.5 + traits.sociability)
        case .climb:
            guard windowAvailable else { return 0 }
            return traits.boldness * 0.6 + traits.playfulness * 0.1
        }
    }
}
