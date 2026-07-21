import Foundation
import Testing
@testable import Ramona

@Suite struct NeedsStateTests {
    private let neutralTraits = SpeciesDefinition.TraitWeights(
        playfulness: 0.5, laziness: 0.5, foodMotivation: 0.5, boldness: 0.5, sociability: 0.5
    )

    @Test func hungerNeverDropsBelowItsOwnHigherFloor() {
        var needs = NeedsState.full
        needs.decay(over: 1_000 * 3600, traits: neutralTraits, isSleeping: false, isActive: false, isPlaying: false, isToyBeingDragged: false)
        #expect(abs(needs.hunger - NeedsState.hungerFloor) < 0.0001)
    }

    @Test func energyPlaySocialNeverDropBelowTheSharedFloor() {
        var needs = NeedsState.full
        needs.decay(over: 1_000 * 3600, traits: neutralTraits, isSleeping: false, isActive: false, isPlaying: false, isToyBeingDragged: false)
        #expect(abs(needs.energy - NeedsState.floor) < 0.0001)
        #expect(abs(needs.play - NeedsState.floor) < 0.0001)
        #expect(abs(needs.social - NeedsState.floor) < 0.0001)
    }

    @Test func sleepingRestoresEnergyInsteadOfDraining() {
        var needs = NeedsState(hunger: 1, energy: 0.2, play: 1, social: 1)
        needs.decay(over: 3600, traits: neutralTraits, isSleeping: true, isActive: false, isPlaying: false, isToyBeingDragged: false)
        #expect(needs.energy > 0.2)
    }

    @Test func beingActiveFillsPlayInsteadOfDrainingIt() {
        var needs = NeedsState(hunger: 1, energy: 1, play: 0.2, social: 1)
        needs.decay(over: 3600, traits: neutralTraits, isSleeping: false, isActive: true, isPlaying: false, isToyBeingDragged: false)
        #expect(needs.play > 0.2)
    }

    @Test func idlePlayDecaysInsteadOfRising() {
        var needs = NeedsState.full
        needs.decay(over: 3600, traits: neutralTraits, isSleeping: false, isActive: false, isPlaying: false, isToyBeingDragged: false)
        #expect(needs.play < 1)
    }

    @Test func higherLazinessTraitDrainsEnergyFasterWhileAwake() {
        let lazy = SpeciesDefinition.TraitWeights(playfulness: 0.5, laziness: 1, foodMotivation: 0.5, boldness: 0.5, sociability: 0.5)
        let energetic = SpeciesDefinition.TraitWeights(playfulness: 0.5, laziness: 0, foodMotivation: 0.5, boldness: 0.5, sociability: 0.5)
        var lazyNeeds = NeedsState.full
        var energeticNeeds = NeedsState.full
        lazyNeeds.decay(over: 3600, traits: lazy, isSleeping: false, isActive: false, isPlaying: false, isToyBeingDragged: false)
        energeticNeeds.decay(over: 3600, traits: energetic, isSleeping: false, isActive: false, isPlaying: false, isToyBeingDragged: false)
        #expect(lazyNeeds.energy < energeticNeeds.energy)
    }

    @Test func playingFillsPlayFasterThanGenericActivity() {
        var playing = NeedsState(hunger: 1, energy: 1, play: 0.2, social: 1)
        var active = NeedsState(hunger: 1, energy: 1, play: 0.2, social: 1)
        playing.decay(over: 3600, traits: neutralTraits, isSleeping: false, isActive: false, isPlaying: true, isToyBeingDragged: false)
        active.decay(over: 3600, traits: neutralTraits, isSleeping: false, isActive: true, isPlaying: false, isToyBeingDragged: false)
        #expect(playing.play > active.play)
    }

    @Test func draggingTheToyFillsPlayFasterThanNotDraggingItWhilePlaying() {
        var dragged = NeedsState(hunger: 1, energy: 1, play: 0.2, social: 1)
        var notDragged = NeedsState(hunger: 1, energy: 1, play: 0.2, social: 1)
        dragged.decay(over: 3600, traits: neutralTraits, isSleeping: false, isActive: false, isPlaying: true, isToyBeingDragged: true)
        notDragged.decay(over: 3600, traits: neutralTraits, isSleeping: false, isActive: false, isPlaying: true, isToyBeingDragged: false)
        #expect(dragged.play > notDragged.play)
    }

    @Test func playDriveDecaysOverTimeAndNeverBelowTheSharedFloor() {
        var needs = NeedsState.full
        needs.decay(over: 3600, traits: neutralTraits, isSleeping: false, isActive: false, isPlaying: false, isToyBeingDragged: false)
        #expect(needs.playDrive < 1)
        needs.decay(over: 1_000 * 3600, traits: neutralTraits, isSleeping: false, isActive: false, isPlaying: false, isToyBeingDragged: false)
        #expect(abs(needs.playDrive - NeedsState.floor) < 0.0001)
    }

    @Test func decodingAnOlderSaveFileWithoutPlayDriveDefaultsToFull() throws {
        let json = """
        {"hunger": 0.5, "energy": 0.5, "play": 0.5, "social": 0.5}
        """
        let needs = try JSONDecoder().decode(NeedsState.self, from: Data(json.utf8))
        #expect(abs(needs.playDrive - 1) < 0.0001)
    }

    @Test func restoreClampsAtOne() {
        var needs = NeedsState.full
        needs.restore("hunger", by: 0.5)
        #expect(abs(needs.hunger - 1) < 0.0001)
    }

    @Test func restoreOfUnknownNeedNameIsIgnoredRatherThanCrashing() {
        var needs = NeedsState(hunger: 0.5, energy: 0.5, play: 0.5, social: 0.5)
        needs.restore("zzz-not-a-need", by: 0.5)
        #expect(needs.hunger == 0.5 && needs.energy == 0.5 && needs.play == 0.5 && needs.social == 0.5)
    }
}
