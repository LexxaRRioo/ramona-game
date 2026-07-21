import Testing
import Foundation
@testable import Ramona

/// Lets a test advance "now" explicitly between calls instead of depending on
/// real wall-clock time - see BehaviorEngine's now/randomDouble/persist seams.
private final class MutableClock {
    var current: Date
    init(_ date: Date) { current = date }
    func now() -> Date { current }
}

@Suite struct BehaviorEngineTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSpecies(traits: SpeciesDefinition.TraitWeights, sleepHours: [String] = []) -> SpeciesDefinition {
        SpeciesDefinition(id: "test", displayName: "Test", spriteSet: "test", traits: traits,
                          schedule: .init(sleepHours: sleepHours), itemPreferences: [], memeBehaviors: [])
    }

    @Test func tickDecaysNeedsUsingInjectedElapsedTime() {
        let clock = MutableClock(base)
        let traits = SpeciesDefinition.TraitWeights(playfulness: 0.5, laziness: 0.5, foodMotivation: 0.5, boldness: 0.5, sociability: 0.5)
        let engine = BehaviorEngine(species: makeSpecies(traits: traits), saveState: nil,
                                    now: clock.now, randomDouble: { 1 }, persist: { _ in })
        clock.current = base.addingTimeInterval(3600)
        engine.start()
        #expect(engine.needs.play < 1)
    }

    // idle is a constant 0.45; groom/walk/sleep/seekAttention are tuned to
    // 0 or clearly subdominant via needs (play=0, energy=1, social=1), so
    // climb (gated open via setWindowAvailable) is the only real contender.
    private func marginTestSetup(clock: MutableClock, boldness: Double) -> BehaviorEngine {
        let traits = SpeciesDefinition.TraitWeights(playfulness: 0, laziness: 0.5, foodMotivation: 0.5, boldness: boldness, sociability: 0)
        let needs = NeedsState(hunger: 1, energy: 1, play: 0, social: 1)
        let saveState = CatSaveState(needs: needs, lastUpdate: clock.current)
        let engine = BehaviorEngine(species: makeSpecies(traits: traits), saveState: saveState,
                                    now: clock.now, randomDouble: { 1 }, persist: { _ in })
        engine.setWindowAvailable(true)
        return engine
    }

    @Test func evaluateActionDoesNotSwitchWhenBestBarelyBeatsCurrentWithinMargin() {
        // climb = boldness * 0.6 = 0.5, only 0.05 above idle's 0.45 - inside actionSwitchMargin.
        let engine = marginTestSetup(clock: MutableClock(base), boldness: 0.8333)
        engine.start()
        #expect(engine.currentAction == .idle)
    }

    @Test func evaluateActionSwitchesWhenBestBeatsCurrentByMoreThanMargin() {
        // climb = boldness * 0.6 = 0.6, 0.15 above idle's 0.45 - past actionSwitchMargin.
        let engine = marginTestSetup(clock: MutableClock(base), boldness: 1.0)
        engine.start()
        #expect(engine.currentAction == .climb)
    }

    private func steadyIdleEngine(randomDouble: @escaping () -> Double) -> (BehaviorEngine, Box) {
        let traits = SpeciesDefinition.TraitWeights(playfulness: 0, laziness: 0.5, foodMotivation: 0.5, boldness: 0, sociability: 0)
        let needs = NeedsState(hunger: 1, energy: 1, play: 0, social: 1)
        let saveState = CatSaveState(needs: needs, lastUpdate: base)
        let box = Box()
        let engine = BehaviorEngine(species: makeSpecies(traits: traits), saveState: saveState,
                                    now: { self.base }, randomDouble: randomDouble, persist: { _ in })
        engine.onStateChange = { _, _ in box.called = true }
        return (engine, box)
    }

    private final class Box { var called = false }

    @Test func sameActionReconfirmationFiresOnStateChangeOnFlourishRoll() {
        let (engine, box) = steadyIdleEngine(randomDouble: { 0 })
        engine.start()
        #expect(engine.currentAction == .idle)
        #expect(box.called)
    }

    @Test func sameActionReconfirmationSkipsOnStateChangeWithoutFlourishRoll() {
        let (engine, box) = steadyIdleEngine(randomDouble: { 1 })
        engine.start()
        #expect(engine.currentAction == .idle)
        #expect(!box.called)
    }

    @Test func resumeAfterHoldAlwaysFiresOnStateChangeRegardlessOfFlourishRoll() {
        let (engine, box) = steadyIdleEngine(randomDouble: { 1 })
        engine.resumeAfterHold()
        #expect(box.called)
    }

    @Test func setForcedActionPinsActionRegardlessOfScoring() {
        // Full needs would naturally favor idle/groom, not sleep.
        let traits = SpeciesDefinition.TraitWeights(playfulness: 0.5, laziness: 0.5, foodMotivation: 0.5, boldness: 0.5, sociability: 0.5)
        let saveState = CatSaveState(needs: .full, lastUpdate: base)
        let engine = BehaviorEngine(species: makeSpecies(traits: traits), saveState: saveState,
                                    now: { self.base }, randomDouble: { 1 }, persist: { _ in })
        var reported: CatAction?
        engine.onStateChange = { action, _ in reported = action }
        engine.setForcedAction(.sleep)
        #expect(engine.currentAction == .sleep)
        #expect(reported == .sleep)
    }

    @Test func petRestoresSocialNeedAndReevaluatesAction() {
        let traits = SpeciesDefinition.TraitWeights(playfulness: 0.5, laziness: 0.5, foodMotivation: 0.5, boldness: 0.5, sociability: 0.5)
        let needs = NeedsState(hunger: 1, energy: 1, play: 1, social: NeedsState.floor)
        let saveState = CatSaveState(needs: needs, lastUpdate: base)
        let engine = BehaviorEngine(species: makeSpecies(traits: traits), saveState: saveState,
                                    now: { self.base }, randomDouble: { 1 }, persist: { _ in })
        engine.pet()
        #expect(engine.needs.social > NeedsState.floor)
    }
}
