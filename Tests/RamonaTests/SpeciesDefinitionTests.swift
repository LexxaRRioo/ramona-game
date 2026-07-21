import Testing
@testable import Ramona

/// Loads the real bundled Resources/Species/ramona.json - catches JSON shape
/// mistakes (a renamed/missing field) that would otherwise only surface as a
/// launch-time fatalError in the shipped app.
@Suite struct SpeciesDefinitionTests {
    @Test func ramonaSpeciesLoadsAndParsesSleepWindows() {
        let species = SpeciesDefinition.loadRamona()

        #expect(species.id == "ramona")
        #expect(!species.schedule.sleepHours.isEmpty)
        // Every declared sleepHours string should parse - a malformed entry
        // silently drops out of sleepWindows via compactMap and would make
        // sleep scoring quietly wrong rather than failing loudly.
        #expect(species.schedule.sleepWindows.count == species.schedule.sleepHours.count)
    }

    @Test func traitWeightsAreWithinTheDocumented0To1Range() {
        let traits = SpeciesDefinition.loadRamona().traits
        for value in [traits.playfulness, traits.laziness, traits.foodMotivation, traits.boldness, traits.sociability] {
            #expect(value >= 0)
            #expect(value <= 1)
        }
    }
}
