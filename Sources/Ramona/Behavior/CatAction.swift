import Foundation

/// The placeholder-era state machine's states. Real content (feeding, toys,
/// meme behaviors) arrives in later phases as more cases / richer scoring.
enum CatAction: Equatable {
    case walk
    case idle
    case sleep
    /// "Приходит туда куда внимание обращено" / "грозно смотрит когда на
    /// неё долго не обращают внимание" - when neglected long enough she
    /// goes looking for attention instead of just pacing. Sated instantly
    /// by BehaviorEngine.pet(), unlike the other needs (nothing restores
    /// them yet - that's feeding/toys in Phase 5).
    case seekAttention

    /// Utility AI: each candidate scores itself from needs/traits/time of
    /// day; BehaviorEngine runs the highest scorer. Nothing here rules an
    /// action out entirely - e.g. sleep outside a nap window still scores
    /// low-but-nonzero, so the cat can nap on demand if energy runs low
    /// enough, not just at scheduled hours.
    func score(needs: NeedsState, traits: SpeciesDefinition.TraitWeights, sleepWindows: [SleepWindow], hour: Double) -> Double {
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
        }
    }
}
