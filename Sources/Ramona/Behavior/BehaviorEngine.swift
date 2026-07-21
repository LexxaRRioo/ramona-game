import Foundation

/// Ticks needs forward in real time, scores candidate actions with simple
/// utility AI, and reports whichever wins. Owns persistence, so the cat
/// resumes where she left off (decay included) across launches, and can be
/// paused/resumed around screen lock for near-zero idle CPU.
final class BehaviorEngine {
    private(set) var needs: NeedsState
    private(set) var mood: Mood
    private(set) var currentAction: CatAction = .idle

    var onStateChange: ((CatAction, Mood) -> Void)?

    private let species: SpeciesDefinition
    private var lastUpdate: Date
    private var timer: Timer?
    private let tickInterval: TimeInterval = 20
    // Avoids flickering between two similarly-scored actions every tick.
    private let actionSwitchMargin: Double = 0.1
    /// Odds per tick that re-confirming the SAME action (no real transition)
    /// still replays its settle/enter animation - "she stirred, but settled
    /// back down" rather than a hard never-repeat. A real transition (e.g.
    /// walk -> sleep) always plays regardless of this - see evaluateAction.
    private let flourishChance: Double = 0.05
    /// Whether there's currently a window she could climb onto - gates
    /// CatAction.climb's score. Kept up to date by AppDelegate from the
    /// same live tracking CatScene uses (see FrontmostWindowTracker).
    private var isWindowAvailable = false
    /// Debug override (menu bar "Force Action"). When set, scoring is bypassed
    /// and this action is pinned every tick; nil restores autonomous behavior.
    private var forcedAction: CatAction?

    init(species: SpeciesDefinition, saveState: CatSaveState?) {
        self.species = species
        if let saveState {
            needs = saveState.needs
            lastUpdate = saveState.lastUpdate
        } else {
            needs = .full
            lastUpdate = Date()
        }
        mood = Mood(needs: needs)
    }

    /// Runs an immediate catch-up tick (covers time passed since the last
    /// launch, or since `pause()`), then starts the recurring timer.
    func start() {
        tick()
        startTimer()
    }

    /// Like start(), but guarantees the view resyncs even if the utility AI
    /// re-picks the same action as before pausing. Use this specifically
    /// after a hold ends: setHeld() wipes the view's running SKActions for
    /// the whole drag, so it must always resume - start()'s normal
    /// same-action throttling (see flourishChance) is meant for the passive
    /// ambient tick, not for genuinely interrupted state.
    func resumeAfterHold() {
        tick(forceNotify: true)
        startTimer()
    }

    func pause() {
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func saveNow() {
        CatSaveState(needs: needs, lastUpdate: lastUpdate).persist()
    }

    /// User pet her (Phase 4). Instant social-need refill.
    func pet() {
        needs.restore("social", by: 0.5)
        mood = Mood(needs: needs)
        evaluateAction()
    }

    /// Feed/offer-toy (Phase 5) - applies whatever an ItemDefinition
    /// declares it restores. Generic over need name so a future item type
    /// (a bed restoring energy, say) needs no engine change, just a new
    /// Items/*.json.
    func use(_ item: ItemDefinition) {
        for (need, amount) in item.restores {
            needs.restore(need, by: amount)
        }
        mood = Mood(needs: needs)
        evaluateAction()
    }

    /// Whether she'd currently tolerate being picked up. "Если взять Р. на
    /// руки специально против её воли, она попытается вырваться и убежать" -
    /// modeled as mood-gated: a grumpy (neglected) cat refuses, matching
    /// "against her will" meaning against her *current* mood, not a coin flip.
    var toleratesHold: Bool { mood != .grumpy }

    func setWindowAvailable(_ available: Bool) {
        isWindowAvailable = available
    }

    /// Menu bar "Force Action" debug control. Pass an action to pin it, or nil
    /// to hand control back to the utility AI. Re-evaluates immediately so the
    /// cat reacts without waiting for the next tick.
    func setForcedAction(_ action: CatAction?) {
        forcedAction = action
        evaluateAction()
    }

    private func tick(forceNotify: Bool = false) {
        let now = Date()
        let isActive = currentAction == .walk || currentAction == .seekAttention || currentAction == .climb
        needs.decay(over: now.timeIntervalSince(lastUpdate), traits: species.traits, isSleeping: currentAction == .sleep, isActive: isActive)
        lastUpdate = now
        mood = Mood(needs: needs)

        evaluateAction(forceNotify: forceNotify)
        saveNow()
    }

    private func evaluateAction(forceNotify: Bool = false) {
        if let forcedAction {
            currentAction = forcedAction
            onStateChange?(currentAction, mood)
            return
        }

        let hour = Double(Calendar.current.component(.hour, from: Date()))
        let candidates: [CatAction] = [.walk, .idle, .sleep, .seekAttention, .climb, .groom]
        let scored = candidates.map { action in
            (action, action.score(needs: needs, traits: species.traits, sleepWindows: species.schedule.sleepWindows, hour: hour, windowAvailable: isWindowAvailable))
        }

        let previousAction = currentAction
        if let best = scored.max(by: { $0.1 < $1.1 }) {
            let currentScore = scored.first(where: { $0.0 == currentAction })?.1 ?? -.infinity
            if best.0 != currentAction, best.1 > currentScore + actionSwitchMargin {
                currentAction = best.0
            }
        }

        // A real transition always fires (she has to actually walk over,
        // lie down, etc.). Re-confirming the same action every 20s tick
        // used to fire unconditionally too, replaying the settle animation
        // even mid-sleep - kept now as a rare randomized flourish instead.
        let isRealTransition = currentAction != previousAction
        if forceNotify || isRealTransition || Double.random(in: 0..<1) < flourishChance {
            onStateChange?(currentAction, mood)
        }
    }
}
