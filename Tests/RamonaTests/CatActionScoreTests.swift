import Testing
@testable import Ramona

@Suite struct CatActionScoreTests {
    private let neutralTraits = SpeciesDefinition.TraitWeights(
        playfulness: 0.5, laziness: 0.5, foodMotivation: 0.5, boldness: 0.5, sociability: 0.5
    )
    private let napWindow = [SleepWindow("01:00-08:00")!]

    @Test func climbScoresZeroWithoutAnAvailableWindow() {
        let score = CatAction.climb.score(needs: .full, traits: neutralTraits, sleepWindows: [], hour: 12, windowAvailable: false)
        #expect(score == 0)
    }

    @Test func climbScoresAboveZeroWithAWindowAvailable() {
        let score = CatAction.climb.score(needs: .full, traits: neutralTraits, sleepWindows: [], hour: 12, windowAvailable: true)
        #expect(score > 0)
    }

    @Test func sleepScoresHigherInsideItsNapWindowThanOutside() {
        let needs = NeedsState(hunger: 1, energy: 0.5, play: 1, social: 1)
        let inWindow = CatAction.sleep.score(needs: needs, traits: neutralTraits, sleepWindows: napWindow, hour: 3, windowAvailable: false)
        let outsideWindow = CatAction.sleep.score(needs: needs, traits: neutralTraits, sleepWindows: napWindow, hour: 15, windowAvailable: false)
        #expect(inWindow > outsideWindow)
    }

    @Test func sleepStillScoresNonzeroOutsideItsNapWindowWhenExhausted() {
        // "she can nap on demand if energy runs low enough, not just at
        // scheduled hours" - see CatAction.score's doc comment.
        let exhausted = NeedsState(hunger: 1, energy: NeedsState.floor, play: 1, social: 1)
        let score = CatAction.sleep.score(needs: exhausted, traits: neutralTraits, sleepWindows: napWindow, hour: 15, windowAvailable: false)
        #expect(score > 0)
    }

    @Test func walkScoreRisesAsPlayNeedDrops() {
        let satisfied = NeedsState(hunger: 1, energy: 1, play: 1, social: 1)
        let neglected = NeedsState(hunger: 1, energy: 1, play: NeedsState.floor, social: 1)
        let satisfiedScore = CatAction.walk.score(needs: satisfied, traits: neutralTraits, sleepWindows: [], hour: 12, windowAvailable: false)
        let neglectedScore = CatAction.walk.score(needs: neglected, traits: neutralTraits, sleepWindows: [], hour: 12, windowAvailable: false)
        #expect(neglectedScore > satisfiedScore)
    }

    @Test func seekAttentionScoreRisesAsSocialNeedDrops() {
        let satisfied = NeedsState(hunger: 1, energy: 1, play: 1, social: 1)
        let neglected = NeedsState(hunger: 1, energy: 1, play: 1, social: NeedsState.floor)
        let satisfiedScore = CatAction.seekAttention.score(needs: satisfied, traits: neutralTraits, sleepWindows: [], hour: 12, windowAvailable: false)
        let neglectedScore = CatAction.seekAttention.score(needs: neglected, traits: neutralTraits, sleepWindows: [], hour: 12, windowAvailable: false)
        #expect(neglectedScore > satisfiedScore)
    }

    @Test func idleScoreIsAConstantBaseline() {
        let score = CatAction.idle.score(needs: .full, traits: neutralTraits, sleepWindows: [], hour: 12, windowAvailable: false)
        #expect(abs(score - 0.45) < 0.0001)
    }
}
