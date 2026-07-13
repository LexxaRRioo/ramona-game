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

    private func tick() {
        let now = Date()
        needs.decay(over: now.timeIntervalSince(lastUpdate), traits: species.traits)
        lastUpdate = now
        mood = Mood(needs: needs)

        evaluateAction()
        saveNow()
    }

    private func evaluateAction() {
        let hour = Double(Calendar.current.component(.hour, from: Date()))
        let candidates: [CatAction] = [.walk, .idle, .sleep]
        let scored = candidates.map { action in
            (action, action.score(needs: needs, traits: species.traits, sleepWindows: species.schedule.sleepWindows, hour: hour))
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
