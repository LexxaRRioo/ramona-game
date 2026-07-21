import AppKit
import SpriteKit

/// Placeholder cat: a plain circle standing in for the real sprite (Phase 5).
/// Movement follows whatever action BehaviorEngine picks (Phase 3). She
/// lives on the screen floor by default; standing on a window's top edge
/// only happens via the trait-gated CatAction.climb, a manual drag-and-drop
/// landing there, or - while already up there - the live-tracked frontmost
/// window updating, whether that's the same window moving or a different
/// one taking focus (she jumps over to it) - see setTargetWindow/Surface.
final class CatScene: SKScene {
    private let cat = SKSpriteNode()
    /// The actual rendered sprite, a child of `cat`. `cat.position` is owned
    /// exclusively by settle/walkLoop/land; `catVisual.position` (local, so
    /// always relative to whatever `cat` is doing) carries only the small
    /// per-frame ground-contact correction (see applyGroundOffset) - fully
    /// decoupled from cat's position so the correction can never fight or
    /// compound with it, no matter how often a clip replays.
    private let catVisual = SKSpriteNode()
    private let groundMargin: CGFloat = 20
    private let sideMargin: CGFloat = 40
    private let minPerchWidth: CGFloat = 80
    private let walkSpeed: CGFloat = 60 // points per second
    private let dropSpeed: CGFloat = 220 // points per second, used to scale settle/fall durations
    /// 2x the 64px source cell - the sprite's on-screen width, and the unit
    /// playJumpToCurrentSurface's leap distance is expressed in.
    private let catBodyWidth: CGFloat = 128
    /// How high (points) playJumpToCurrentSurface arcs above the higher of
    /// her start/end surface - enough to read as an actual hop rather than
    /// a glide, without turning a same-screen jump into a huge leap.
    private let jumpHopHeight: CGFloat = 36
    /// How far (points), in the direction she's facing, playJumpToCurrentSurface
    /// reaches for when a different window becomes frontmost - a real leap
    /// covers ground, not just the minimal distance to land in bounds. Still
    /// clamped to the target window's own width, so a narrow window catches
    /// her at its edge instead of overshooting off it.
    private var jumpLeapDistance: CGFloat { catBodyWidth * 3.5 }
    /// Speed (points/sec) playJumpToCurrentSurface paces its leap at - the
    /// same pace as .seekAttention's run cycle (4x walkSpeed). A deliberate
    /// multi-body-length leap needs its own pacing rather than reusing
    /// settleDuration's cap (tuned for small position corrections, not a
    /// sustained leap - at that cap a jumpLeapDistance-sized move would
    /// blur past rather than read as a leap).
    private var jumpSpeed: CGFloat { walkSpeed * 4 }
    // "Р. грозно смотрит" / paws at a cursor that lingers nearby - cooldown
    // keeps it a rare flourish rather than firing every frame she's close.
    private let stalkRadius: CGFloat = 90
    private let stalkCooldown: TimeInterval = 4
    /// Odds that entering .groom plays the scratch variant instead of the
    /// regular wash - a rare alternative, not a fixed routine.
    private let scratchChance: Double = 0.05
    /// Odds that entering .seekAttention plays the "sits in a far corner and
    /// meows" variant instead of the usual run/leap across the screen.
    private let meowChance: Double = 0.2

    /// Cache of the live-tracked frontmost window's frame (Phase 2), kept
    /// up to date regardless of whether she's currently on it - it's what
    /// CatAction.climb targets when it wins, and what setTargetWindow
    /// re-applies live if she happens to already be standing on it.
    private var windowFrame: CGRect?
    /// The Dock's top edge, when there's a bottom Dock on screen. It's the
    /// surface Ramona stands on while "on the floor" - she paces along the top
    /// of the Dock rather than the bare screen edge. nil (auto-hidden Dock, or
    /// none) falls back to the screen-bottom ground line. Refreshed by
    /// OverlayWindow's poll and kept here so groundBounds can read it live.
    private var dockSurface: CGRect?
    private var currentSurface: Surface = .floor
    /// The on-screen toy (cable tie, to start), if one's been offered -
    /// nil means none is out. See spawnToy/despawnToy, updateToyGroundClamp.
    private var toy: ToyNode?
    private var currentAction: CatAction = .walk
    /// currentAction from just before the most recent apply() call - lets a
    /// case pick a different clip depending on what she was doing right
    /// before (e.g. groom vs. groomLying depending on whether she just woke
    /// up), without needing BehaviorEngine to know about clip-level detail.
    private var previousAction: CatAction = .walk
    /// Facing direction from the last walk/climb/seekAttention leg, used to
    /// pick a directional sit when she stops instead of always snapping to
    /// the front-facing idle pose.
    private var lastFacingRight = true
    private var lastStalkTime: TimeInterval = 0
    /// Set by land(on:) so the next apply() doesn't immediately override a
    /// manual drop's surface just because the freshly re-evaluated action
    /// happens to differ from .climb - see apply(action:mood:needs:).
    private var justLanded = false

    /// Left button, click-and-release ("приходит если её позвать и мурчит,
    /// когда начинаешь её гладить") or held-and-moved ("cursor-petting") -
    /// see mouseDown/mouseDragged/mouseUp.
    var onPet: (() -> Void)?
    /// Fires once a rightMouseDragged on the cat exceeds the drag threshold.
    /// Return true to allow the pickup to proceed, false to reject it (the
    /// struggle cue plays instead and no drag begins).
    var onHoldRequested: (() -> Bool)?
    /// Fires on rightMouseUp after an accepted hold, with the drop point in
    /// screen coordinates - before onHoldEnded, so land(on:) has already
    /// updated the surface by the time the engine resumes and settles her.
    var onDropped: ((CGPoint) -> Void)?
    /// Fires on rightMouseUp after an accepted hold.
    var onHoldEnded: (() -> Void)?

    /// True between mouseDown/mouseUp or rightMouseDown/rightMouseUp on the
    /// cat - OverlayWindow's hover poll must not fight an in-progress
    /// interaction by re-hit-testing against a cursor position that's now
    /// expected to be outside the hit radius.
    private(set) var isInteracting = false
    /// Set once onPet has fired during the current left-button gesture (a
    /// cursor-petting drag), so mouseUp doesn't also fire the plain-click pet.
    private var pettedThisGesture = false
    /// event.timestamp of the last petPulse fired from mouseDragged - throttles
    /// cursor-petting to petPulse's own cadence instead of once per mouse-moved
    /// event, which would spam BehaviorEngine.pet()'s instant social-need
    /// restore many times a second.
    private var lastPetPulseTime: TimeInterval = 0
    private let petPulseCooldown: TimeInterval = 0.3
    private var isDragging = false
    private var dragMoved = false
    private var dragRejected = false
    // Ordinary trackpad/mouse clicks jitter a few points between mouseDown
    // and mouseUp; too low a threshold here misreads nearly every right-click
    // as a drag-pickup (that was the "clicking makes her jump" bug - it
    // wasn't actually jitter alone, see the comment in rightMouseDragged).
    private let dragThreshold: CGFloat = 14

    // Debug HUD (Phase 4): needs/mood/action, toggled from the menu bar via
    // DebugSettings - the only way to actually see the utility AI's numbers
    // instead of guessing from a plain circle's motion.
    private let debugBackground = SKShapeNode(rectOf: CGSize(width: 220, height: 140), cornerRadius: 8)
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        // Much stronger than SpriteKit's real-world default (-9.8) - at
        // that scale a thrown toy would take ~20s to fall a screen's
        // height, reading as floating rather than falling. Tuned so a
        // dropped toy reaches roughly the cat's own dropSpeed (220pt/s)
        // within a fraction of a second instead - a snappy, light-plastic
        // fall, not real-world physics. Retune after live playtesting.
        physicsWorld.gravity = CGVector(dx: 0, dy: -900)

        // cat is a positional carrier only, kept invisible (no texture) -
        // its size/anchor just keep hitTest's bounding box consistent.
        // The 64px cell has ~16px of empty space below her paws; anchoring
        // catVisual at footAnchorY plants her feet on the ground line
        // instead of her center.
        cat.anchorPoint = CGPoint(x: 0.5, y: CatSprites.footAnchorY)
        cat.size = CGSize(width: catBodyWidth, height: catBodyWidth)

        catVisual.anchorPoint = CGPoint(x: 0.5, y: CatSprites.footAnchorY)
        catVisual.size = cat.size
        catVisual.texture = CatSprites.sitIdle.textures.first
        cat.addChild(catVisual)

        cat.position = CGPoint(x: size.width / 2, y: groundMargin)
        addChild(cat)

        setUpDebugOverlay()
        applyCurrentAction()
    }

    private func setUpDebugOverlay() {
        debugBackground.fillColor = NSColor.black.withAlphaComponent(0.6)
        debugBackground.strokeColor = .clear
        debugBackground.zPosition = 100
        debugBackground.isHidden = true
        debugBackground.position = CGPoint(x: 12 + 110, y: size.height - 12 - 70)
        addChild(debugBackground)

        debugLabel.fontSize = 12
        debugLabel.fontColor = .white
        debugLabel.numberOfLines = 0
        debugLabel.horizontalAlignmentMode = .left
        debugLabel.verticalAlignmentMode = .top
        debugLabel.zPosition = 101
        debugLabel.isHidden = true
        debugLabel.position = CGPoint(x: 20, y: size.height - 20)
        addChild(debugLabel)
    }

    func setDebugVisible(_ visible: Bool) {
        debugBackground.isHidden = !visible
        debugLabel.isHidden = !visible
    }

    private func updateDebugText(action: CatAction, mood: Mood, needs: NeedsState) {
        let surfaceText: String
        switch currentSurface {
        case .floor: surfaceText = "floor"
        case .window: surfaceText = "window"
        }
        debugLabel.text = String(
            format: "action: %@\nsurface: %@\nmood: %@\nhunger: %.2f\nenergy: %.2f\nplay: %.2f\nsocial: %.2f",
            String(describing: action), surfaceText, String(describing: mood),
            needs.hunger, needs.energy, needs.play, needs.social
        )
    }

    private func isValidPerch(_ frame: CGRect) -> Bool {
        FloorTracking.isValidPerch(frame, sceneSize: size, minPerchWidth: minPerchWidth)
    }

    /// Called whenever the live-tracked frontmost window's frame changes, or
    /// with nil when there's none (closed, minimized, switched to an app
    /// without a window, or Accessibility not yet granted). Any valid frame
    /// is followed while she's standing on a window - whether it's the same
    /// window continuing to move, or a different one that just became
    /// frontmost. `isSameWindow` only picks HOW that follow is animated: a
    /// different window becoming frontmost plays an explicit walk-style jump
    /// (playJumpToCurrentSurface) so it reads as an intentional hop instead
    /// of silently gliding across in whatever static pose she happened to be
    /// in (jarring mid-sleep/groom) - same-window moves just use the normal
    /// applyCurrentAction re-settle. The frontmost-window cache itself
    /// (`windowFrame`, what CatAction.climb targets) always updates
    /// regardless, since that's "whatever's currently trackable", not
    /// specifically what she's standing on.
    func setTargetWindow(_ frame: CGRect?, isSameWindow: Bool) {
        windowFrame = (frame.map(isValidPerch) == true) ? frame : nil

        guard let next = FloorTracking.nextSurface(
            afterWindowUpdate: frame, currentSurface: currentSurface, sceneSize: size, minPerchWidth: minPerchWidth
        ) else { return }

        // Only follow this transition for the toy if it was on the SAME
        // window she was (checked against the pre-transition currentSurface)
        // - the live tracker only ever reports the single frontmost window,
        // so there's no way to tell a toy resting on some other window
        // apart from one that should legitimately fall here.
        if let toy, toy.surface == currentSurface {
            toy.surface = next
            if case .floor = next {
                toy.isResting = false
                toy.node.physicsBody?.affectedByGravity = true
            }
        }

        let isJump = !isSameWindow && next != currentSurface
        currentSurface = next
        switch next {
        case .floor: dropToGround()
        case .window: isJump ? playJumpToCurrentSurface() : applyCurrentAction()
        }
    }

    /// Called after a completed drag (Phase 4), with whichever surface (if
    /// any) AppDelegate found directly below the drop point - "может кошка
    /// всегда падает вниз, а забирается наверх только отдельным действием".
    /// Unlike setTargetWindow (driven by live AX change notifications,
    /// which skip redundant no-op transitions), this always applies: the
    /// cat's raw position right after a drag is wherever the user released
    /// her, not necessarily anywhere near a surface yet. No animation of
    /// its own - onHoldEnded's engine.start() runs an immediate catch-up
    /// tick right after this, which settles her via applyCurrentAction()
    /// using whatever surface is current by then.
    func land(on frame: CGRect?) {
        if let frame, isValidPerch(frame) {
            currentSurface = .window(frame)
        } else {
            currentSurface = .floor
        }
        justLanded = true
    }

    /// Called by BehaviorEngine whenever its utility AI picks a new action
    /// or mood changes. Mood only tints the placeholder for now - real
    /// per-mood animations arrive with Phase 5 art.
    func apply(action: CatAction, mood: Mood, needs: NeedsState) {
        if !justLanded, action == .climb, currentAction != .climb {
            // Entering climb: head for whatever window is currently
            // trackable. CatAction.climb already scores 0 when none is
            // available, so this should always find one in practice.
            //
            // Leaving climb deliberately does NOT reset currentSurface back
            // to .floor - she stays wherever she climbed to (sleeping,
            // grooming, idling, walking up there are all fine) until
            // something actually displaces her: the window closing/moving
            // off-screen (setTargetWindow), or a manual drop. An earlier
            // version forced currentSurface = .floor here on every climb
            // exit, which raced with the next action's settle - e.g.
            // switching to .sleep read as curling up mid-fall, since the
            // lie-down animation started playing while she was still
            // mid-drop to the wrong (floor/Dock) ground line.
            if let windowFrame, isValidPerch(windowFrame) {
                currentSurface = .window(windowFrame)
            }
        }
        justLanded = false

        previousAction = currentAction
        currentAction = action
        updateMoodTint(mood)
        applyCurrentAction()
        updateDebugText(action: action, mood: mood, needs: needs)
    }

    /// Scene-local hit test (Phase 4). Bounding-box of the sprite's current
    /// frame, padded a little so the fluffy edges stay grabbable - true
    /// per-pixel alpha hit-testing is still a later refinement.
    func hitTest(_ point: CGPoint) -> Bool {
        cat.frame.insetBy(dx: -4, dy: -4).contains(point)
    }

    /// Pins the cat directly to `point` while the user is dragging her,
    /// bypassing the settle/walk/sleep action machinery entirely.
    func setHeld(at point: CGPoint) {
        cat.removeAllActions()
        catVisual.removeAllActions()
        cat.setScale(1)
        catVisual.setScale(1)
        cat.alpha = 1
        cat.position = point
    }

    /// Quick affectionate pulse on pet() - purely a placeholder cue (no
    /// audio, per the locked "memes as behavior/animation only" decision).
    func playPetPulse() {
        cat.run(.sequence([.scale(to: 1.3, duration: 0.15), .scale(to: 1.0, duration: 0.15)]))
    }

    /// Placeholder feed/toy cues (Phase 5) - a real eating/pouncing
    /// animation is Phase 5 art's job; this just gives the interaction
    /// visible feedback in the meantime, reusing petPulse's shape scaled up
    /// a little so the three don't read as identical.
    func playEatPulse() {
        cat.run(.sequence([.scale(to: 1.4, duration: 0.2), .scale(to: 1.0, duration: 0.2)]))
    }

    func playToyPulse() {
        cat.run(.sequence([
            .scale(to: 1.2, duration: 0.1), .scale(to: 0.95, duration: 0.1),
            .scale(to: 1.15, duration: 0.1), .scale(to: 1.0, duration: 0.1)
        ]))
    }

    /// Brings a physical toy on screen, replacing whatever toy (if any) was
    /// already out - one at a time for now, no reason yet to juggle several.
    /// Spawns at wherever she's currently standing/its ground line ("stay on
    /// the same level where Ramona stays"), already resting there.
    func spawnToy(_ item: ItemDefinition) {
        toy?.node.removeFromParent()
        let (groundY, groundMinX, groundMaxX) = groundBounds()
        let spawnX = min(max(cat.position.x, groundMinX), groundMaxX)
        let newToy = ToyNode(item: item, at: CGPoint(x: spawnX, y: groundY), surface: currentSurface)
        toy = newToy
        addChild(newToy.node)
    }

    func despawnToy() {
        toy?.node.removeFromParent()
        toy = nil
    }

    /// Per-frame toy physics resolution, called after SpriteKit's own
    /// physics step (didSimulatePhysics). Deliberately NOT rigid-body
    /// collision against synthesized level geometry - the window/Dock/floor
    /// ground line already moves independently of any physics body, so
    /// keeping a synced collision shape for it would be a lot of ongoing
    /// complexity for a purely cosmetic outcome. Instead: physics owns the
    /// toy's velocity/acceleration/damping while it's airborne, and this
    /// just checks its position against the same FloorTracking.groundBounds
    /// the cat uses (fed the toy's own, independent surface) every frame.
    private func updateToyGroundClamp() {
        guard let toy, !toy.isHeld else { return }
        let (groundY, minX, maxX) = FloorTracking.groundBounds(
            currentSurface: toy.surface, dockSurface: dockSurface, sceneSize: size,
            groundMargin: groundMargin, sideMargin: sideMargin, minPerchWidth: minPerchWidth
        )
        var position = toy.node.position
        if toy.isResting {
            // Stay glued to the ground line even as it moves (a dragged
            // window, the Dock appearing/hiding) - the same idea as the
            // cat's own re-settle keeping her from floating/sinking.
            position.y = groundY
        } else if position.y <= groundY {
            position.y = groundY
            toy.node.physicsBody?.velocity = .zero
            toy.node.physicsBody?.affectedByGravity = false
            toy.isResting = true
        }
        let clampedX = min(max(position.x, minX), maxX)
        if clampedX != position.x {
            toy.node.physicsBody?.velocity.dx = 0
            position.x = clampedX
        }
        toy.node.position = position
    }

    override func didSimulatePhysics() {
        updateToyGroundClamp()
    }

    /// "Если взять Р. на руки специально против её воли, она попытается
    /// вырваться и убежать" - a rejected pickup (BehaviorEngine.toleratesHold
    /// == false) plays this instead of entering a drag.
    func playStruggle() {
        let x = cat.position.x
        cat.removeAllActions()
        cat.run(.sequence([
            .moveTo(x: x + 6, duration: 0.05),
            .moveTo(x: x - 6, duration: 0.05),
            .moveTo(x: x + 4, duration: 0.05),
            .moveTo(x: x, duration: 0.05)
        ])) { [weak self] in
            self?.applyCurrentAction()
        }
    }

    /// Left button: petting only, never pickup - a plain click-release pets
    /// once, and holding the button down while moving over her ("cursor-
    /// petting") pets repeatedly instead of picking her up (see
    /// rightMouseDown for that).
    override func mouseDown(with event: NSEvent) {
        isInteracting = true
        pettedThisGesture = false
    }

    override func mouseDragged(with event: NSEvent) {
        // Throttled to petPulse's own cadence (0.3s) rather than firing once
        // per mouse-moved event, which would spam BehaviorEngine.pet()'s
        // instant social-need restore many times a second.
        guard event.timestamp - lastPetPulseTime >= petPulseCooldown else { return }
        lastPetPulseTime = event.timestamp
        pettedThisGesture = true
        onPet?()
        playPetPulse()
    }

    override func mouseUp(with event: NSEvent) {
        isInteracting = false
        guard !pettedThisGesture else { return }
        onPet?()
        playPetPulse()
    }

    /// Right button: pickup and carry, what the left button used to do -
    /// "Rework mouse interaction" in BACKLOG.md moved pickup off the left
    /// button (now petting-only) onto the right button instead.
    override func rightMouseDown(with event: NSEvent) {
        isInteracting = true
        isDragging = false
        dragMoved = false
        dragRejected = false
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard !dragRejected else { return }
        // NSEvent.location(in:) uses its own AppKit<->SpriteKit conversion,
        // separate from (and untested against) the NSEvent.mouseLocation
        // math OverlayWindow's hover poll already uses to correctly find
        // the cat under the cursor - reusing that same path here instead
        // keeps drag position consistent with what hit-tested us in.
        guard let point = localCursorPosition() else { return }

        if !isDragging {
            guard hypot(point.x - cat.position.x, point.y - cat.position.y) > dragThreshold else { return }
            guard onHoldRequested?() ?? false else {
                dragRejected = true
                playStruggle()
                return
            }
            isDragging = true
            dragMoved = true
            playClip(Bool.random() ? CatSprites.heldLeft : CatSprites.heldRight)
        }

        setHeld(at: point)
    }

    override func rightMouseUp(with event: NSEvent) {
        isInteracting = false

        if isDragging {
            isDragging = false
            onDropped?(NSEvent.mouseLocation)
            onHoldEnded?()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard currentAction == .walk || currentAction == .idle,
              currentTime - lastStalkTime > stalkCooldown,
              let cursor = localCursorPosition(),
              hypot(cursor.x - cat.position.x, cursor.y - cat.position.y) < stalkRadius else { return }
        lastStalkTime = currentTime
        cat.run(.sequence([.scale(to: 1.15, duration: 0.12), .scale(to: 1.0, duration: 0.12)]))
    }

    /// NSEvent.mouseLocation is in screen coordinates; the window fills the
    /// primary screen 1:1 with the scene, so subtracting its origin gives
    /// scene-local coordinates directly (see FrontmostWindowTracker for the
    /// same primary-screen-only assumption).
    private func localCursorPosition() -> CGPoint? {
        guard let window = view?.window else { return nil }
        let screenPoint = NSEvent.mouseLocation
        return CGPoint(x: screenPoint.x - window.frame.origin.x, y: screenPoint.y - window.frame.origin.y)
    }

    /// Called by OverlayWindow's poll with the current Dock frame (or nil when
    /// it auto-hides). If she's on the floor, re-settles her onto the new
    /// surface so she steps onto - or off of - the Dock as it appears/hides.
    func setDockSurface(_ frame: CGRect?) {
        let changed = frame != dockSurface
        dockSurface = frame
        if changed, case .floor = currentSurface, !isInteracting {
            applyCurrentAction()
        }
        // Un-rest a floor-resting toy so it falls (or re-settles) through
        // updateToyGroundClamp instead of teleporting straight to the new
        // ground line - matters most when the Dock disappears out from
        // under it.
        if changed, let toy, toy.isResting, case .floor = toy.surface {
            toy.isResting = false
            toy.node.physicsBody?.affectedByGravity = true
        }
    }

    /// The active ground line - the current window's top edge while
    /// currentSurface is .window, the Dock's top edge if there's a bottom Dock,
    /// the bare screen floor otherwise. See FloorTracking.groundBounds for the
    /// (unit-tested) decision logic.
    private func groundBounds() -> (y: CGFloat, minX: CGFloat, maxX: CGFloat) {
        FloorTracking.groundBounds(
            currentSurface: currentSurface, dockSurface: dockSurface, sceneSize: size,
            groundMargin: groundMargin, sideMargin: sideMargin, minPerchWidth: minPerchWidth
        )
    }

    /// Whether the currently-tracked frontmost window is a strictly higher
    /// perch than wherever she's standing right now - see
    /// FloorTracking.offersHigherPerch. AppDelegate feeds this into
    /// BehaviorEngine.setHigherPerchAvailable so CatAction.climb can prefer
    /// heading up onto it instead of only ever winning by trait-weighted luck.
    var higherPerchAvailable: Bool {
        FloorTracking.offersHigherPerch(
            windowFrame: windowFrame, currentGroundY: groundBounds().y, sceneSize: size, minPerchWidth: minPerchWidth
        )
    }

    /// Resets any in-flight actions/scale, ready for a new settle/jump move -
    /// shared by applyCurrentAction and playJumpToCurrentSurface, which each
    /// compute their own target X/duration from the returned ground line
    /// (a jump reaches further than a plain settle - see jumpLeapDistance).
    /// Returns nil if the ground line is degenerate (minX >= maxX, e.g. a
    /// perch too narrow to stand on at all).
    private func resetForSettle() -> (groundY: CGFloat, groundMinX: CGFloat, groundMaxX: CGFloat)? {
        let (groundY, groundMinX, groundMaxX) = groundBounds()
        guard groundMinX < groundMaxX else { return nil }
        cat.removeAllActions()
        catVisual.removeAllActions()
        cat.setScale(1)
        catVisual.setScale(1)
        cat.alpha = 1
        return (groundY, groundMinX, groundMaxX)
    }

    /// A fixed short duration here made drop-landings and climbs look like
    /// reversed gravity: covering a whole screen's height in 0.25s reads as
    /// floating, not falling/hopping. Scaling with distance fixes both
    /// directions - routine same-surface action switches stay snappy (small
    /// distance, clamped to the 0.15s floor) while a big climb-up, floor-
    /// drop, or window jump takes proportionally longer, clamped so it never
    /// feels sluggish either.
    private func settleDuration(distance: CGFloat) -> TimeInterval {
        max(0.15, min(0.6, TimeInterval(distance / dropSpeed)))
    }

    /// A different window became frontmost while she was standing on one -
    /// jumps directly over to it with the run/leap cycle (rows 10/11,
    /// already used for .seekAttention - it has a real airborne mid-leap
    /// frame, unlike the walk cycle) and a vertical hop arced over the
    /// horizontal move, instead of the plain straight-line settle
    /// applyCurrentAction would otherwise give her - a linear move between
    /// two surfaces at different heights reads as flying/gliding, not
    /// jumping. Reaches jumpLeapDistance in her facing direction rather than
    /// the minimal distance to land in bounds, so it reads as a real leap
    /// covering ground - clamped to the target window's own width, so a
    /// narrow window still catches her at its edge instead of overshooting
    /// off it. Resumes into whatever currentAction actually is once she
    /// lands.
    private func playJumpToCurrentSurface() {
        guard let (groundY, groundMinX, groundMaxX) = resetForSettle() else { return }
        let startX = cat.position.x
        let startY = cat.position.y
        let nearestX = min(max(startX, groundMinX), groundMaxX)
        lastFacingRight = nearestX >= startX
        let reachX = startX + (lastFacingRight ? jumpLeapDistance : -jumpLeapDistance)
        let clampedX = min(max(reachX, groundMinX), groundMaxX)

        // A held static pose, not the looping run clip - cycling its legs
        // while airborne read as sprinting in place rather than leaping.
        playClip(lastFacingRight ? CatSprites.leapRight : CatSprites.leapLeft)

        let duration = max(0.25, min(1.5, TimeInterval(hypot(clampedX - startX, groundY - startY) / jumpSpeed)))
        let horizontal = SKAction.moveTo(x: clampedX, duration: duration)
        let up = SKAction.moveTo(y: max(startY, groundY) + jumpHopHeight, duration: duration / 2)
        up.timingMode = .easeOut
        let down = SKAction.moveTo(y: groundY, duration: duration / 2)
        down.timingMode = .easeIn
        cat.run(.group([horizontal, .sequence([up, down])])) { [weak self] in
            self?.applyCurrentAction()
        }
    }

    /// Vertical distance a single climb hop covers - big enough that even a
    /// full-height climb only takes a handful of hops, not a wall of them.
    private let climbHopRise: CGFloat = 70
    /// Extra arc height per climb hop, on top of climbHopRise's net rise -
    /// same idea as jumpHopHeight, just sized for a smaller in-place hop
    /// rather than a full leap between two surfaces.
    private let climbHopArc: CGFloat = 16

    /// Climbs to a window in a short series of upward hops instead of one
    /// smooth diagonal glide - a straight-line move at climbing height read
    /// as floating/gliding up rather than an active climb. Falls back to a
    /// single settle when there's little or no actual rise (e.g. climbing
    /// to a window at roughly her own height).
    private func climbAscent(to target: CGPoint) -> SKAction {
        let start = cat.position
        let totalRise = target.y - start.y
        guard totalRise > climbHopRise / 2 else {
            return SKAction.move(to: target, duration: settleDuration(distance: hypot(target.x - start.x, target.y - start.y)))
        }

        let hopCount = max(1, min(4, Int((totalRise / climbHopRise).rounded(.up))))
        var hops: [SKAction] = []
        var previous = start
        for i in 1...hopCount {
            let progress = CGFloat(i) / CGFloat(hopCount)
            let hopTarget = CGPoint(x: start.x + (target.x - start.x) * progress, y: start.y + totalRise * progress)
            let duration = max(0.2, TimeInterval(hypot(hopTarget.x - previous.x, hopTarget.y - previous.y) / jumpSpeed))
            let across = SKAction.moveTo(x: hopTarget.x, duration: duration)
            let up = SKAction.moveTo(y: hopTarget.y + climbHopArc, duration: duration / 2)
            up.timingMode = .easeOut
            let down = SKAction.moveTo(y: hopTarget.y, duration: duration / 2)
            down.timingMode = .easeIn
            hops.append(.group([across, .sequence([up, down])]))
            previous = hopTarget
        }
        return .sequence(hops)
    }

    private func applyCurrentAction() {
        guard let (groundY, groundMinX, groundMaxX) = resetForSettle() else { return }
        let clampedX = min(max(cat.position.x, groundMinX), groundMaxX)
        let duration = settleDuration(distance: hypot(clampedX - cat.position.x, groundY - cat.position.y))
        let settle = SKAction.move(to: CGPoint(x: clampedX, y: groundY), duration: duration)

        switch currentAction {
        case .walk:
            lastFacingRight = clampedX >= cat.position.x
            playClip(lastFacingRight ? CatSprites.walkRight : CatSprites.walkLeft)
            cat.run(.sequence([settle, walkLoop(from: clampedX)]))
        case .climb:
            // Plays throughout the ascent (climbAscent carries her there
            // in a series of hops, not settle's straight glide) instead of
            // pacing afterward - climbing itself is a one-shot reach, not
            // something to keep doing once she's arrived.
            playClip(CatSprites.climb)
            cat.run(climbAscent(to: CGPoint(x: clampedX, y: groundY)))
        case .idle:
            if previousAction == .walk || previousAction == .climb || previousAction == .seekAttention {
                // She just stopped moving - settle facing the direction she
                // was headed instead of snapping to the front-facing pose.
                playClip(lastFacingRight ? CatSprites.sitRight : CatSprites.sitLeft)
            } else {
                // Wasn't moving beforehand - the ordinary front-facing settle.
                playClip(CatSprites.sitDown, then: CatSprites.sitIdle)
            }
            cat.run(settle)
        case .groom:
            if previousAction == .sleep {
                // Grooms lying down right after waking, rather than sitting
                // up first.
                playClip(CatSprites.groomLying)
            } else {
                // Sits and cleans herself - a content between-walks rest
                // activity. A rare chance she scratches instead of washing -
                // same idea as the sleep flourish, an occasional variant
                // rather than a fixed routine every time.
                playClip(Double.random(in: 0..<1) < scratchChance ? CatSprites.scratch : CatSprites.groom)
            }
            cat.run(settle)
        case .sleep:
            // Settles, lies down and curls up, then holds the curl. Row 6's
            // curl frames mix two directions (see CatSprites.lieDownRight/
            // lieDownLeft) - picking a side fresh each time she settles
            // (including the periodic re-settle flourish) keeps every
            // individual settle internally consistent without needing to
            // remember which side she picked last nap.
            let curlsRight = Bool.random()
            playClip(curlsRight ? CatSprites.lieDownRight : CatSprites.lieDownLeft, then: curlsRight ? CatSprites.sleepRight : CatSprites.sleepLeft)
            cat.run(settle)
            // Runs on catVisual, not cat: cat.position is the settle/walk
            // target, and scaling that node too would compound with
            // catVisual's own per-frame ground offset (see
            // applyGroundOffset) every breath cycle.
            catVisual.run(.repeatForever(.sequence([
                .scaleY(to: 0.96, duration: 1.8),
                .scaleY(to: 1.0, duration: 1.8)
            ])), withKey: "breath")
        case .seekAttention:
            if Double.random(in: 0..<1) < meowChance {
                // Rare variant: stays put and meows instead of pacing.
                playClip(CatSprites.meowSit)
                cat.run(settle)
            } else {
                // "Может в два раза быстрее обычного пробегать из одного угла
                // квартиры в другой" when long ignored - a real run/leap cycle
                // (row 10/11), not just a sped-up walk, so it reads as urgent
                // rather than a walk cycle glitching.
                lastFacingRight = clampedX >= cat.position.x
                playClip(lastFacingRight ? CatSprites.runRight : CatSprites.runLeft)
                cat.run(.sequence([settle, walkLoop(from: clampedX, speed: walkSpeed * 4, rightClip: CatSprites.runRight, leftClip: CatSprites.runLeft)]))
            }
        }
    }

    /// Plays a named clip's frames on the cat under the "anim" key, so it runs
    /// concurrently with whatever positional action (settle, walk legs) is
    /// moving her. `resize: false` keeps the node's fixed footprint as frames
    /// change. Pass `then:` to play a one-shot intro (e.g. sitting down) and
    /// hand off to a looping clip (e.g. the breathing sit) when it finishes.
    private func playClip(_ clip: CatClip, then next: CatClip? = nil) {
        catVisual.removeAction(forKey: "anim")
        guard let first = clip.textures.first else { return }
        applyGroundOffset(clip, frame: 0)
        guard !clip.isStatic else {
            catVisual.texture = first
            if let next { playClip(next) }
            return
        }
        let intro = animateAction(for: clip)
        guard !clip.loops, let next, let nextFirst = next.textures.first else {
            catVisual.run(clip.loops ? repeatingLoop(intro, pause: clip.loopPause) : intro, withKey: "anim")
            return
        }
        let loop: SKAction = next.isStatic
            ? .sequence([.setTexture(nextFirst), .run { [weak self] in self?.applyGroundOffset(next, frame: 0) }])
            : {
                let a = animateAction(for: next)
                return next.loops ? repeatingLoop(a, pause: next.loopPause) : a
            }()
        catVisual.run(.sequence([intro, loop]), withKey: "anim")
    }

    /// Wraps a clip's per-cycle animation in repeatForever, holding still for
    /// `pause` between cycles instead of an unbroken loop when set (see
    /// CatClip.loopPause).
    private func repeatingLoop(_ cycle: SKAction, pause: TimeInterval) -> SKAction {
        guard pause > 0 else { return .repeatForever(cycle) }
        return .repeatForever(.sequence([cycle, .wait(forDuration: pause)]))
    }

    /// Sets catVisual's local position.y for the given clip/frame - zero for
    /// the common case, or a small correction derived from that clip's own
    /// per-frame measurement (see CatClip.groundAnchors) for poses like
    /// lieDown/sleep whose visual "ground contact" sits elsewhere in the
    /// 64px cell than the walk/sit baseline. This moves the sprite itself
    /// (catVisual, a child of cat) rather than reinterpreting anchorPoint,
    /// and catVisual's anchorPoint never changes - so however often a clip
    /// replays, this always resolves to the same offset for the same frame,
    /// with nothing to accumulate.
    private func applyGroundOffset(_ clip: CatClip, frame: Int) {
        guard let anchors = clip.groundAnchors, let anchor = anchors[frame] else {
            catVisual.position.y = 0
            return
        }
        catVisual.position.y = (CatSprites.footAnchorY - anchor) * cat.size.height
    }

    /// Like SKAction.animate(with:timePerFrame:resize:restore:), plus a
    /// synchronized ground-offset update per frame for clips that need one.
    private func animateAction(for clip: CatClip) -> SKAction {
        guard clip.groundAnchors != nil else {
            return SKAction.animate(with: clip.textures, timePerFrame: clip.timePerFrame, resize: false, restore: false)
        }
        let steps = clip.textures.indices.map { i in
            SKAction.sequence([
                .run { [weak self] in
                    self?.catVisual.texture = clip.textures[i]
                    self?.applyGroundOffset(clip, frame: i)
                },
                .wait(forDuration: clip.timePerFrame)
            ])
        }
        return .sequence(steps)
    }

    /// rightClip/leftClip default to the walk cycle; .seekAttention passes
    /// the run cycle instead so the same approach/ping-pong logic drives
    /// both gaits.
    private func walkLoop(from startX: CGFloat, speed: CGFloat? = nil, rightClip: CatClip = CatSprites.walkRight, leftClip: CatClip = CatSprites.walkLeft) -> SKAction {
        let speed = speed ?? walkSpeed
        let (_, groundMinX, groundMaxX) = groundBounds()
        // Each leg swaps to the matching directional cycle (native left and
        // right rows on the sheet, not a mirror) the instant it begins.
        func leg(to x: CGFloat, from x0: CGFloat, clip: CatClip) -> SKAction {
            let face = SKAction.run { [weak self] in self?.playClip(clip) }
            let move = SKAction.moveTo(x: x, duration: TimeInterval(abs(x - x0) / speed))
            return .sequence([face, move])
        }
        // Initial approach from wherever she is to the right end, THEN a clean
        // min<->max ping-pong. Folding the arbitrary start into the repeating
        // cycle made each repeat reuse that stale origin, so a return leg's
        // duration was computed for the wrong distance and she'd cross the
        // whole width in a fraction of the time - the "teleport" on reaching
        // an end. The cycle legs below always measure from the true endpoints.
        let approach = leg(to: groundMaxX, from: startX, clip: rightClip)
        let cycle = SKAction.repeatForever(.sequence([
            leg(to: groundMinX, from: groundMaxX, clip: leftClip),
            leg(to: groundMaxX, from: groundMinX, clip: rightClip)
        ]))
        return .sequence([approach, cycle])
    }

    private func dropToGround() {
        let (groundY, _, _) = groundBounds()
        cat.removeAllActions()
        catVisual.removeAllActions()
        cat.setScale(1)
        catVisual.setScale(1)
        cat.alpha = 1
        let fallDuration = TimeInterval(abs(cat.position.y - groundY) / dropSpeed)
        let fall = SKAction.move(to: CGPoint(x: cat.position.x, y: groundY), duration: max(0.1, fallDuration))
        cat.run(fall) { [weak self] in
            self?.applyCurrentAction()
        }
    }

    private func updateMoodTint(_ mood: Mood) {
        // Ramona is already fully coloured, so mood only nudges a faint gray
        // wash over the sprite rather than repainting her - a real per-mood
        // pose set is future art. colorBlendFactor 0 leaves her untouched.
        catVisual.color = .gray
        switch mood {
        case .happy: catVisual.colorBlendFactor = 0
        case .content: catVisual.colorBlendFactor = 0.08
        case .grumpy: catVisual.colorBlendFactor = 0.2
        }
    }
}
