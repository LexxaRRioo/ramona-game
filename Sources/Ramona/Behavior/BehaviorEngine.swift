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
    /// Whether there's currently a window she could climb onto - gates
    /// CatAction.climb's score. Kept up to date by AppDelegate from the
    /// same live tracking CatScene uses (see FrontmostWindowTracker).
    private var isWindowAvailable = false

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
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func pause() {
        timer?.invalidate()
        timer = nil
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

    private func tick() {
        let now = Date()
        needs.decay(over: now.timeIntervalSince(lastUpdate), traits: species.traits, isSleeping: currentAction == .sleep)
        lastUpdate = now
        mood = Mood(needs: needs)

        evaluateAction()
        saveNow()
    }

    private func evaluateAction() {
        let hour = Double(Calendar.current.component(.hour, from: Date()))
        let candidates: [CatAction] = [.walk, .idle, .sleep, .seekAttention, .climb]
        let scored = candidates.map { action in
            (action, action.score(needs: needs, traits: species.traits, sleepWindows: species.schedule.sleepWindows, hour: hour, windowAvailable: isWindowAvailable))
        }

        if let best = scored.max(by: { $0.1 < $1.1 }) {
            let currentScore = scored.first(where: { $0.0 == currentAction })?.1 ?? -.infinity
            if best.0 != currentAction, best.1 > currentScore + actionSwitchMargin {
                currentAction = best.0
            }
        }

        onStateChange?(currentAction, mood)
    }
}
