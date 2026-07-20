import AppKit
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindowController: OverlayWindowController?
    private var windowTracker: FrontmostWindowTracker?
    private var permissionPollTimer: Timer?
    private var behaviorEngine: BehaviorEngine?
    private var species: SpeciesDefinition?
    private var items: [ItemDefinition] = []
    /// Reads SUFeedURL/SUPublicEDKey/SUEnableAutomaticChecks from Info.plist
    /// (set by the build scripts from the repo-root VERSION-adjacent appcast
    /// URL) - startingUpdater: true begins the automatic-check schedule
    /// immediately rather than waiting for the first manual check.
    private var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let screen = NSScreen.main else { return }
        let controller = OverlayWindowController(screen: screen)
        controller.showWindow(nil)
        overlayWindowController = controller

        startBehaviorEngine()
        observeScreenLock()
        startAccessibilityFlow()
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        DebugSettings.shared.onChange = { [weak self] visible in
            self?.overlayWindowController?.catScene.setDebugVisible(visible)
        }
    }

    /// Menu bar "Check for Updates…" (RamonaApp).
    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        behaviorEngine?.saveNow()
    }

    /// Menu bar "Feed" (RamonaApp) - V1 scope is just canned chicken, so
    /// there's nothing to choose between yet.
    func feed() {
        guard let item = items.first(where: { $0.kind == .food }) else { return }
        behaviorEngine?.use(item)
        overlayWindowController?.catScene.playEatPulse()
    }

    /// Menu bar "Offer Toy" (RamonaApp) - picks randomly among her
    /// preferred toys (SpeciesDefinition.itemPreferences) rather than any
    /// toy that happens to exist, so a future non-favorite item added to
    /// Items/ doesn't show up here uninvited.
    func offerToy() {
        guard let species else { return }
        let preferredToys = species.itemPreferences.compactMap { id in
            items.first(where: { $0.id == id && $0.kind == .toy })
        }
        guard let item = preferredToys.randomElement() else { return }
        behaviorEngine?.use(item)
        overlayWindowController?.catScene.playToyPulse()
    }

    /// Debug menu "Force Action" - pins the cat to a chosen action for
    /// previewing animations, or nil to resume autonomous behavior.
    func forceAction(_ action: CatAction?) {
        behaviorEngine?.setForcedAction(action)
    }

    /// Menu bar "Quiet Mode" - user-toggled hide, e.g. during screen
    /// sharing. Pauses the same engine as screen-lock (see
    /// observeScreenLock) rather than letting her keep deciding/decaying
    /// unseen, then resumes with a catch-up tick on exit.
    func setQuietMode(_ enabled: Bool) {
        if enabled {
            behaviorEngine?.pause()
            windowTracker?.pause()
        } else {
            behaviorEngine?.start()
            windowTracker?.resume()
        }
        overlayWindowController?.setQuietMode(enabled)
    }

    /// Runs independently of Accessibility/window-tracking - the cat has
    /// needs, mood, and a resting/walking/sleeping state machine whether or
    /// not she can see other apps' windows yet.
    private func startBehaviorEngine() {
        let species = SpeciesDefinition.loadRamona()
        self.species = species
        items = ItemDefinition.loadAll()
        let engine = BehaviorEngine(species: species, saveState: CatSaveState.load())
        engine.onStateChange = { [weak self, weak engine] action, mood in
            guard let engine else { return }
            self?.overlayWindowController?.catScene.apply(action: action, mood: mood, needs: engine.needs)
        }
        engine.start()
        behaviorEngine = engine

        wireCatInteraction(to: engine)
    }

    /// Phase 4: petting and mood-gated pickup, wired through to the same
    /// engine that owns needs/mood - see BehaviorEngine.pet/toleratesHold.
    private func wireCatInteraction(to engine: BehaviorEngine) {
        let scene = overlayWindowController?.catScene
        scene?.onPet = { [weak engine] in
            engine?.pet()
        }
        scene?.onHoldRequested = { [weak engine] in
            guard let engine, engine.toleratesHold else { return false }
            engine.pause()
            return true
        }
        scene?.onDropped = { [weak scene] point in
            scene?.land(on: FrontmostWindowTracker.surfaceBelow(point))
        }
        scene?.onHoldEnded = { [weak engine] in
            engine?.start()
        }
    }

    /// TCC/window-focus notifications don't cover the lock screen; these
    /// are the standard (no-entitlement-needed) distributed notifications
    /// apps use to detect it, so the sim and renderer can both pause for
    /// near-zero idle CPU while locked.
    private func observeScreenLock() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            self?.behaviorEngine?.pause()
            self?.overlayWindowController?.setPaused(true)
            self?.windowTracker?.pause()
        }
        center.addObserver(forName: Notification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.overlayWindowController?.setPaused(false)
            self?.behaviorEngine?.start()
            self?.windowTracker?.resume()
        }
    }

    private func startAccessibilityFlow() {
        if AccessibilityPermission.isGranted {
            AccessibilityPermission.hasBeenGrantedBefore = true
            startWindowTracking()
            return
        }

        AccessibilityPermission.requestIfNeeded()

        // A rebuilt dev binary (see Scripts/build-dev-app.sh) gets ad-hoc
        // re-signed, which changes its code identity, so an *already*
        // granted-looking toggle in System Settings may actually be for a
        // stale build - the freshly relaunched process itself is still
        // untrusted. If we already know the user has done this dance
        // before, don't interrupt them with the same modal every launch;
        // just keep polling quietly and pick it up once they re-toggle it.
        // Only first-time users get the explicit instructional alert.
        if !AccessibilityPermission.hasBeenGrantedBefore {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, !AccessibilityPermission.isGranted else { return }
                self.showAccessibilityInstructionsAlert()
            }
        }

        permissionPollTimer = AccessibilityPermission.waitForGrant { [weak self] in
            AccessibilityPermission.hasBeenGrantedBefore = true
            self?.startWindowTracking()
        }
    }

    private func showAccessibilityInstructionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Ramona needs Accessibility access"
        alert.informativeText = "To walk on your windows, open System Settings > Privacy & Security > Accessibility and enable Ramona. She'll start tracking windows automatically once you do."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startWindowTracking() {
        let tracker = FrontmostWindowTracker()
        tracker.onFrameChange = { [weak self] frame in
            self?.overlayWindowController?.catScene.setTargetWindow(frame)
            self?.behaviorEngine?.setWindowAvailable(frame != nil)
        }
        windowTracker = tracker
    }
}
