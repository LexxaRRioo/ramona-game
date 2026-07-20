import AppKit
import SpriteKit

/// Placeholder cat: a plain circle standing in for the real sprite (Phase 5).
/// Movement follows whatever action BehaviorEngine picks (Phase 3). She
/// lives on the screen floor by default; standing on a window's top edge
/// only happens via the trait-gated CatAction.climb, a manual drag-and-drop
/// landing there, or while already up there and that window itself moves -
/// see currentSurface.
final class CatScene: SKScene {
    private enum Surface {
        case floor
        case window(CGRect)
    }

    private let cat = SKSpriteNode()
    private let groundMargin: CGFloat = 20
    private let sideMargin: CGFloat = 40
    private let minPerchWidth: CGFloat = 80
    private let walkSpeed: CGFloat = 60 // points per second
    private let dropSpeed: CGFloat = 220 // points per second, used to scale settle/fall durations
    // "Р. грозно смотрит" / paws at a cursor that lingers nearby - cooldown
    // keeps it a rare flourish rather than firing every frame she's close.
    private let stalkRadius: CGFloat = 90
    private let stalkCooldown: TimeInterval = 4

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
    private var currentAction: CatAction = .walk
    private var lastStalkTime: TimeInterval = 0
    /// Set by land(on:) so the next apply() doesn't immediately override a
    /// manual drop's surface just because the freshly re-evaluated action
    /// happens to differ from .climb - see apply(action:mood:needs:).
    private var justLanded = false

    /// User clicked-and-released on the cat without dragging past the
    /// threshold ("приходит если её позвать и мурчит, когда начинаешь её
    /// гладить").
    var onPet: (() -> Void)?
    /// Fires once a mouseDragged on the cat exceeds the drag threshold.
    /// Return true to allow the pickup to proceed, false to reject it (the
    /// struggle cue plays instead and no drag begins).
    var onHoldRequested: (() -> Bool)?
    /// Fires on mouseUp after an accepted hold, with the drop point in
    /// screen coordinates - before onHoldEnded, so land(on:) has already
    /// updated the surface by the time the engine resumes and settles her.
    var onDropped: ((CGPoint) -> Void)?
    /// Fires on mouseUp after an accepted hold.
    var onHoldEnded: (() -> Void)?

    /// True between mouseDown and mouseUp on the cat - OverlayWindow's hover
    /// poll must not fight an in-progress drag by re-hit-testing against a
    /// cursor position that's now expected to be outside the hit radius.
    private(set) var isInteracting = false
    private var isDragging = false
    private var dragMoved = false
    private var dragRejected = false
    // Ordinary trackpad/mouse clicks jitter a few points between mouseDown
    // and mouseUp; too low a threshold here misreads nearly every pet as a
    // drag (that was the "clicking makes her jump" bug - it wasn't actually
    // jitter alone, see the comment in mouseDragged).
    private let dragThreshold: CGFloat = 14

    // Debug HUD (Phase 4): needs/mood/action, toggled from the menu bar via
    // DebugSettings - the only way to actually see the utility AI's numbers
    // instead of guessing from a plain circle's motion.
    private let debugBackground = SKShapeNode(rectOf: CGSize(width: 220, height: 140), cornerRadius: 8)
    private let debugLabel = SKLabelNode(fontNamed: "Menlo")

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill

        // The 64px cell has ~16px of empty space below her paws; anchoring at
        // footAnchorY plants her feet on the ground line instead of her center.
        cat.anchorPoint = CGPoint(x: 0.5, y: CatSprites.footAnchorY)
        cat.size = CGSize(width: 128, height: 128) // 2x the 64px source cell

        cat.texture = CatSprites.sitIdle.textures.first
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
        frame.width >= minPerchWidth && frame.maxY < size.height && CGRect(origin: .zero, size: size).intersects(frame)
    }

    /// Called whenever the live-tracked frontmost window's frame changes, or
    /// with nil when there's none (closed, minimized, switched to an app
    /// without a window, or Accessibility not yet granted). Always updates
    /// the cache; only actually moves her if she's currently standing on
    /// that window - otherwise it's just kept ready for the next climb.
    func setTargetWindow(_ frame: CGRect?) {
        guard let frame, isValidPerch(frame) else {
            windowFrame = nil
            if case .window = currentSurface {
                currentSurface = .floor
                dropToGround()
            }
            return
        }

        windowFrame = frame
        if case .window = currentSurface {
            currentSurface = .window(frame)
            applyCurrentAction()
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
        if !justLanded {
            if action == .climb && currentAction != .climb {
                // Entering climb: head for whatever window is currently
                // trackable. CatAction.climb already scores 0 when none is
                // available, so this should always find one in practice.
                if let windowFrame, isValidPerch(windowFrame) {
                    currentSurface = .window(windowFrame)
                }
            } else if action != .climb && currentAction == .climb {
                currentSurface = .floor
            }
        }
        justLanded = false

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
        cat.setScale(1)
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

    override func mouseDown(with event: NSEvent) {
        isInteracting = true
        isDragging = false
        dragMoved = false
        dragRejected = false
    }

    override func mouseDragged(with event: NSEvent) {
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
        }

        setHeld(at: point)
    }

    override func mouseUp(with event: NSEvent) {
        defer { isInteracting = false }

        if isDragging {
            isDragging = false
            onDropped?(NSEvent.mouseLocation)
            onHoldEnded?()
        } else if !dragMoved && !dragRejected {
            onPet?()
            playPetPulse()
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
    }

    /// The active ground line - the current window's top edge while
    /// currentSurface is .window, the Dock's top edge if there's a bottom Dock,
    /// the bare screen floor otherwise.
    private func groundBounds() -> (y: CGFloat, minX: CGFloat, maxX: CGFloat) {
        if case .window(let frame) = currentSurface, isValidPerch(frame) {
            return (frame.maxY, frame.minX + sideMargin / 2, frame.maxX - sideMargin / 2)
        }
        if let dock = dockSurface {
            return (dock.maxY, dock.minX + sideMargin / 2, dock.maxX - sideMargin / 2)
        }
        return (groundMargin, sideMargin, size.width - sideMargin)
    }

    private func applyCurrentAction() {
        let (groundY, groundMinX, groundMaxX) = groundBounds()
        guard groundMinX < groundMaxX else { return }
        cat.removeAllActions()
        cat.setScale(1)
        cat.alpha = 1

        let clampedX = min(max(cat.position.x, groundMinX), groundMaxX)
        // A fixed short duration here made drop-landings and climbs look
        // like reversed gravity: covering a whole screen's height in 0.25s
        // reads as floating, not falling/hopping. Scaling with distance
        // fixes both directions - routine same-surface action switches stay
        // snappy (small distance, clamped to the 0.15s floor) while a big
        // climb-up or floor-drop takes proportionally longer, clamped so it
        // never feels sluggish either.
        let settleDistance = hypot(clampedX - cat.position.x, groundY - cat.position.y)
        let settleDuration = max(0.15, min(0.6, TimeInterval(settleDistance / dropSpeed)))
        let settle = SKAction.move(to: CGPoint(x: clampedX, y: groundY), duration: settleDuration)

        switch currentAction {
        case .walk, .climb:
            // Climbing (Phase 4) reuses the walk visual - only the surface
            // (floor vs. a window's top edge, chosen in apply(action:...))
            // differs; a distinct climbing animation is a later art thing.
            // Face the way she settles; walkLoop then re-picks per leg.
            playClip(clampedX >= cat.position.x ? CatSprites.walkRight : CatSprites.walkLeft)
            cat.run(.sequence([settle, walkLoop(from: clampedX)]))
        case .idle:
            // Not going anywhere - she sits down, then sits and breathes.
            playClip(CatSprites.sitDown, then: CatSprites.sitIdle)
            cat.run(settle)
        case .groom:
            // Sits and cleans herself - a content between-walks rest activity.
            playClip(CatSprites.groom)
            cat.run(settle)
        case .sleep:
            // Settles, lies down and curls up, then holds the curl. Breathing
            // is a gentle vertical scale on its own key (not a frame swap), so
            // she never appears to rotate while asleep.
            playClip(CatSprites.lieDown, then: CatSprites.sleep)
            cat.run(settle)
            cat.run(.repeatForever(.sequence([
                .scaleY(to: 0.96, duration: 1.8),
                .scaleY(to: 1.0, duration: 1.8)
            ])), withKey: "breath")
        case .seekAttention:
            // "Может в два раза быстрее обычного пробегать из одного угла
            // квартиры в другой" when long ignored - same pacing as .walk,
            // just faster and more visibly urgent.
            playClip(clampedX >= cat.position.x ? CatSprites.walkRight : CatSprites.walkLeft)
            cat.run(.sequence([settle, walkLoop(from: clampedX, speed: walkSpeed * 2)]))
        }
    }

    /// Plays a named clip's frames on the cat under the "anim" key, so it runs
    /// concurrently with whatever positional action (settle, walk legs) is
    /// moving her. `resize: false` keeps the node's fixed footprint as frames
    /// change. Pass `then:` to play a one-shot intro (e.g. sitting down) and
    /// hand off to a looping clip (e.g. the breathing sit) when it finishes.
    private func playClip(_ clip: CatClip, then next: CatClip? = nil) {
        cat.removeAction(forKey: "anim")
        guard let first = clip.textures.first else { return }
        guard !clip.isStatic else {
            cat.texture = first
            if let next { playClip(next) }
            return
        }
        let intro = SKAction.animate(with: clip.textures, timePerFrame: clip.timePerFrame, resize: false, restore: false)
        guard !clip.loops, let next, let nextFirst = next.textures.first else {
            cat.run(clip.loops ? .repeatForever(intro) : intro, withKey: "anim")
            return
        }
        let loop: SKAction = next.isStatic
            ? .setTexture(nextFirst)
            : {
                let a = SKAction.animate(with: next.textures, timePerFrame: next.timePerFrame, resize: false, restore: false)
                return next.loops ? .repeatForever(a) : a
            }()
        cat.run(.sequence([intro, loop]), withKey: "anim")
    }

    private func walkLoop(from startX: CGFloat, speed: CGFloat? = nil) -> SKAction {
        let speed = speed ?? walkSpeed
        let (_, groundMinX, groundMaxX) = groundBounds()
        // Each leg swaps to the matching directional walk cycle (native left
        // and right rows on the sheet, not a mirror) the instant it begins.
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
        let approach = leg(to: groundMaxX, from: startX, clip: CatSprites.walkRight)
        let cycle = SKAction.repeatForever(.sequence([
            leg(to: groundMinX, from: groundMaxX, clip: CatSprites.walkLeft),
            leg(to: groundMaxX, from: groundMinX, clip: CatSprites.walkRight)
        ]))
        return .sequence([approach, cycle])
    }

    private func dropToGround() {
        let (groundY, _, _) = groundBounds()
        cat.removeAllActions()
        cat.setScale(1)
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
        cat.color = .gray
        switch mood {
        case .happy: cat.colorBlendFactor = 0
        case .content: cat.colorBlendFactor = 0.08
        case .grumpy: cat.colorBlendFactor = 0.2
        }
    }
}
