import Foundation

/// The cat's core drives, each on a 0...1 scale where 1 is fully satisfied.
/// Floored above zero so the worst outcome mood can ever reach is grumpy -
/// there is no "sick"/"neglected" state (see Mood).
struct NeedsState: Codable {
    static let floor: Double = 0.2
    /// Higher than the shared floor - "cat is autonomous: self-feeds
    /// off-screen if unattended" (plan.md). Unlike energy/play/social, which
    /// depend on the owner's attention, hunger has a self-sufficient
    /// baseline she settles at on her own even if never manually fed.
    static let hungerFloor: Double = 0.5
    static let full = NeedsState(hunger: 1, energy: 1, play: 1, social: 1)

    var hunger: Double
    var energy: Double
    var play: Double
    /// How recently she's had attention (petting/feeding/play). Decays like
    /// the others; restored by BehaviorEngine.pet()/use(_:). Drives
    /// CatAction.seekAttention.
    var social: Double

    mutating func decay(over elapsed: TimeInterval, traits: SpeciesDefinition.TraitWeights, isSleeping: Bool, isActive: Bool) {
        let hours = elapsed / 3600
        hunger = Self.apply(floor: Self.hungerFloor, rate: Self.hourlyRate(base: 0.1333, trait: traits.foodMotivation), hours: hours, to: hunger)
        if isSleeping {
            // Sleeping restores energy rather than draining it - matches
            // CatAction.sleep actually meaning something, not just a pose.
            // Same trait direction as the awake-drain rate below: laziness
            // already means "tires fast", so it's consistent for it to also
            // mean "recovers fast" rather than inverting it.
            energy = min(1, energy + Self.hourlyRate(base: 0.3, trait: traits.laziness) * hours)
        } else {
            energy = Self.apply(floor: Self.floor, rate: Self.hourlyRate(base: 0.16, trait: traits.laziness), hours: hours, to: energy)
        }
        if isActive {
            // Being active (walking/climbing/seeking) *satisfies* the play
            // drive rather than draining it, so a burst of movement fills play,
            // drops walk's score, and she settles into rest instead of pacing
            // forever - the whole point of the walk/rest cycle. Faster than the
            // idle decay below so bursts stay short.
            play = min(1, play + Self.hourlyRate(base: 12, trait: traits.playfulness) * hours)
        } else {
            play = Self.apply(floor: Self.floor, rate: Self.hourlyRate(base: 0.2667, trait: traits.playfulness), hours: hours, to: play)
        }
        social = Self.apply(floor: Self.floor, rate: Self.hourlyRate(base: 0.2, trait: traits.sociability), hours: hours, to: social)
    }

    /// Called by BehaviorEngine.pet()/use(_:) (petting, feeding, toys) -
    /// instant, unlike decay. Unrecognized need names are ignored rather
    /// than crashing, since the set of need names is defined by whatever
    /// ItemDefinition.restores keys happen to be authored in Items/*.json.
    mutating func restore(_ need: String, by amount: Double) {
        switch need {
        case "hunger": hunger = min(1, hunger + amount)
        case "energy": energy = min(1, energy + amount)
        case "play": play = min(1, play + amount)
        case "social": social = min(1, social + amount)
        default: break
        }
    }

    /// trait 0.5 is neutral (1x); trait 0/1 give 0.5x/1.5x - a higher trait
    /// makes that need drop (or, for sleep's energy regen, rise) faster.
    private static func hourlyRate(base: Double, trait: Double) -> Double {
        base * (0.5 + trait)
    }

    private static func apply(floor: Double, rate: Double, hours: Double, to value: Double) -> Double {
        max(floor, value - rate * hours)
    }
}
