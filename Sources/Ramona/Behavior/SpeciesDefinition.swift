import Foundation

/// Decoded from Resources/Species/ramona.json - a cat's static definition:
/// trait weights, nap schedule, and (later phases) item preferences and
/// meme-behavior list. Adding a second cat is a new JSON + sprite folder,
/// not a code change.
struct SpeciesDefinition: Codable {
    let id: String
    let displayName: String
    let spriteSet: String
    let traits: TraitWeights
    let schedule: Schedule
    let itemPreferences: [String]
    let memeBehaviors: [String]

    /// Each weight is 0...1. These modulate need decay rates and action
    /// scoring - see NeedsState.decay and CatAction.score.
    struct TraitWeights: Codable {
        let playfulness: Double
        let laziness: Double
        let foodMotivation: Double
        let boldness: Double
        let sociability: Double
    }

    struct Schedule: Codable {
        /// "HH:MM-HH:MM" ranges, e.g. "01:00-08:00".
        let sleepHours: [String]

        var sleepWindows: [SleepWindow] {
            sleepHours.compactMap(SleepWindow.init)
        }
    }
}

extension SpeciesDefinition {
    static func loadRamona() -> SpeciesDefinition {
        guard let url = Bundle.module.url(forResource: "ramona", withExtension: "json", subdirectory: "Species"),
              let data = try? Data(contentsOf: url),
              let species = try? JSONDecoder().decode(SpeciesDefinition.self, from: data) else {
            fatalError("Missing or invalid bundled resource Species/ramona.json")
        }
        return species
    }
}
