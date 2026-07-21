import Testing
@testable import Ramona

@Suite struct MoodTests {
    @Test func fullNeedsAreHappy() {
        #expect(Mood(needs: .full) == .happy)
    }

    @Test func averageAtHappyThresholdIsHappy() {
        let needs = NeedsState(hunger: 0.7, energy: 0.7, play: 0.7, social: 0.7)
        #expect(Mood(needs: needs) == .happy)
    }

    @Test func justBelowHappyThresholdIsContent() {
        let needs = NeedsState(hunger: 0.69, energy: 0.69, play: 0.69, social: 0.69)
        #expect(Mood(needs: needs) == .content)
    }

    @Test func averageAtContentThresholdIsContent() {
        let needs = NeedsState(hunger: 0.4, energy: 0.4, play: 0.4, social: 0.4)
        #expect(Mood(needs: needs) == .content)
    }

    @Test func justBelowContentThresholdIsGrumpy() {
        let needs = NeedsState(hunger: 0.39, energy: 0.39, play: 0.39, social: 0.39)
        #expect(Mood(needs: needs) == .grumpy)
    }

    @Test func floorNeedsAreNeverWorseThanGrumpy() {
        let needs = NeedsState(hunger: NeedsState.floor, energy: NeedsState.floor, play: NeedsState.floor, social: NeedsState.floor)
        #expect(Mood(needs: needs) == .grumpy)
    }

    @Test func moodOrderingForToleratesHoldLogic() {
        // BehaviorEngine.toleratesHold is `mood != .grumpy` - guard the
        // ordering these comparisons rely on doesn't silently invert.
        #expect(Mood.grumpy < Mood.content)
        #expect(Mood.content < Mood.happy)
    }
}
