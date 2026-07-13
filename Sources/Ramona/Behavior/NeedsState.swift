import Foundation

/// The cat's core drives, each on a 0...1 scale where 1 is fully satisfied.
/// Floored above zero so the worst outcome mood can ever reach is grumpy -
/// there is no "sick"/"neglected" state (see Mood). In this phase nothing
/// restores a need yet (that's feeding/petting/play in later phases), so
/// needs are expected to settle at the floor over time until then.
struct NeedsState: Codable {
    static let floor: Double = 0.2
    static let full = NeedsState(hunger: 1, energy: 1, play: 1)

    var hunger: Double
    var energy: Double
    var play: Double

    mutating func decay(over elapsed: TimeInterval, traits: SpeciesDefinition.TraitWeights) {
        let hours = elapsed / 3600
        hunger = Self.apply(rate: Self.hourlyRate(base: 0.1333, trait: traits.foodMotivation), hours: hours, to: hunger)
        energy = Self.apply(rate: Self.hourlyRate(base: 0.16, trait: traits.laziness), hours: hours, to: energy)
        play = Self.apply(rate: Self.hourlyRate(base: 0.2667, trait: traits.playfulness), hours: hours, to: play)
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
