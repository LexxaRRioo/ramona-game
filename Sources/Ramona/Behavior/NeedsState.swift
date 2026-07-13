import Foundation

/// The cat's core drives, each on a 0...1 scale where 1 is fully satisfied.
/// Floored above zero so the worst outcome mood can ever reach is grumpy -
/// there is no "sick"/"neglected" state (see Mood). In this phase nothing
/// restores a need yet (that's feeding/petting/play in later phases), so
/// needs are expected to settle at the floor over time until then.
struct NeedsState: Codable {
    static let floor: Double = 0.2
    static let full = NeedsState(hunger: 1, energy: 1, play: 1, social: 1)

    var hunger: Double
    var energy: Double
    var play: Double
    /// How recently she's had attention (petting). Decays like the others;
    /// nothing but petting restores it yet (Phase 4). Drives CatAction.seekAttention.
    var social: Double

    mutating func decay(over elapsed: TimeInterval, traits: SpeciesDefinition.TraitWeights) {
        let hours = elapsed / 3600
        hunger = Self.apply(rate: Self.hourlyRate(base: 0.1333, trait: traits.foodMotivation), hours: hours, to: hunger)
        energy = Self.apply(rate: Self.hourlyRate(base: 0.16, trait: traits.laziness), hours: hours, to: energy)
        play = Self.apply(rate: Self.hourlyRate(base: 0.2667, trait: traits.playfulness), hours: hours, to: play)
        social = Self.apply(rate: Self.hourlyRate(base: 0.2, trait: traits.sociability), hours: hours, to: social)
    }

    /// Called when the user pets her (Phase 4). Instant, unlike decay.
    mutating func restoreSocial(by amount: Double) {
        social = min(1, social + amount)
    }

    /// trait 0.5 is neutral (1x); trait 0/1 give 0.5x/1.5x - a higher trait
    /// makes that need drop faster, i.e. it needs attention more often.
    private static func hourlyRate(base: Double, trait: Double) -> Double {
        base * (0.5 + trait)
    }

    private static func apply(rate: Double, hours: Double, to value: Double) -> Double {
        max(floor, value - rate * hours)
    }
}
