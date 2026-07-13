import AppKit
import SpriteKit

/// Placeholder cat: a plain circle standing in for the real sprite (Phase 5).
/// Movement follows whatever action BehaviorEngine picks (Phase 3), using
/// the frontmost tracked window's top edge when one is available (Phase 2),
/// or the screen's bottom edge otherwise.
final class CatScene: SKScene {
    private let cat = SKShapeNode(circleOfRadius: 16)
    private let hitRadius: CGFloat = 22
    private let groundMargin: CGFloat = 20
    private let sideMargin: CGFloat = 40
    private let minPerchWidth: CGFloat = 80
    private let walkSpeed: CGFloat = 60 // points per second
    private let dropSpeed: CGFloat = 220 // points per second, falling off a window
    // "Р. грозно смотрит" / paws at a cursor that lingers nearby - cooldown
    // keeps it a rare flourish rather than firing every frame she's close.
    private let stalkRadius: CGFloat = 90
    private let stalkCooldown: TimeInterval = 4

    private var windowFrame: CGRect?
    private var groundY: CGFloat = 0
    private var groundMinX: CGFloat = 0
    private var groundMaxX: CGFloat = 0
    private var currentAction: CatAction = .walk
    private var lastStalkTime: TimeInterval = 0

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
    /// updated ground bounds by the time the engine resumes and settles her.
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

        cat.fillColor = .systemOrange
        cat.strokeColor = .clear
        groundY = groundMargin
        groundMinX = sideMargin
        groundMaxX = size.width - sideMargin
        cat.position = CGPoint(x: size.width / 2, y: groundY)
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
        debugLabel.text = String(
            format: "action: %@\nmood: %@\nhunger: %.2f\nenergy: %.2f\nplay: %.2f\nsocial: %.2f",
            String(describing: action), String(describing: mood),
            needs.hunger, needs.energy, needs.play, needs.social
        )
    }

    private func isValidPerch(_ frame: CGRect) -> Bool {
        frame.width >= minPerchWidth && frame.maxY < size.height && CGRect(origin: .zero, size: size).intersects(frame)
    }

    /// Called whenever the tracked window's frame changes, or with nil when
    /// there's no trackable window (closed, minimized, app switched to one
    /// without a window, or Accessibility not yet granted).
    func setTargetWindow(_ frame: CGRect?) {
        guard let frame, isValidPerch(frame) else {
            guard windowFrame != nil else { return }
            windowFrame = nil
            groundY = groundMargin
            groundMinX = sideMargin
            groundMaxX = size.width - sideMargin
            dropToGround()
            return
        }

        windowFrame = frame
        groundY = frame.maxY
        groundMinX = frame.minX + sideMargin / 2
        groundMaxX = frame.maxX - sideMargin / 2
        applyCurrentAction()
    }

    /// Called after a completed drag (Phase 4), with whichever window (if
    /// any) AppDelegate found under the drop point - "хочу чтобы кошка
    /// приземлялась на окно, если её туда перетащили". Unlike
    /// setTargetWindow (driven by live AX change notifications, which skips
    /// redundant no-op transitions), this always updates ground bounds: the
    /// cat's raw position right after a drag is wherever the user released
    /// her, not necessarily anywhere near a ground line yet. No animation of
    /// its own - onHoldEnded's engine.start() runs an immediate catch-up
    /// tick right after this, which settles her via applyCurrentAction()
    /// using whatever ground bounds are current by then.
    func land(on frame: CGRect?) {
        if let frame, isValidPerch(frame) {
            windowFrame = frame
            groundY = frame.maxY
            groundMinX = frame.minX + sideMargin / 2
            groundMaxX = frame.maxX - sideMargin / 2
        } else {
            windowFrame = nil
            groundY = groundMargin
            groundMinX = sideMargin
            groundMaxX = size.width - sideMargin
        }
    }

    /// Called by BehaviorEngine whenever its utility AI picks a new action
    /// or mood changes. Mood only tints the placeholder for now - real
    /// per-mood animations arrive with Phase 5 art.
    func apply(action: CatAction, mood: Mood, needs: NeedsState) {
        currentAction = action
        updateMoodTint(mood)
        applyCurrentAction()
        updateDebugText(action: action, mood: mood, needs: needs)
    }

    /// Scene-local hit test (Phase 4). Bounding-circle only, matching the
    /// placeholder shape - real per-pixel alpha hit-testing arrives with
    /// Phase 5 art.
    func hitTest(_ point: CGPoint) -> Bool {
        hypot(point.x - cat.position.x, point.y - cat.position.y) <= hitRadius
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

    private func applyCurrentAction() {
        guard groundMinX < groundMaxX else { return }
        cat.removeAllActions()
        cat.setScale(1)
        cat.alpha = 1

        let clampedX = min(max(cat.position.x, groundMinX), groundMaxX)
        let settle = SKAction.move(to: CGPoint(x: clampedX, y: groundY), duration: 0.25)

        switch currentAction {
        case .walk:
            cat.run(.sequence([settle, walkLoop(from: clampedX)]))
        case .idle:
            cat.run(settle)
            cat.run(.repeatForever(.sequence([
                .scale(to: 1.05, duration: 1.2),
                .scale(to: 1.0, duration: 1.2)
            ])))
        case .sleep:
            cat.run(.sequence([settle, .scaleX(to: 1.2, y: 0.7, duration: 0.3)]))
            cat.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.7, duration: 1.5),
                .fadeAlpha(to: 1.0, duration: 1.5)
            ])))
        case .seekAttention:
            // "Может в два раза быстрее обычного пробегать из одного угла
            // квартиры в другой" when long ignored - same pacing as .walk,
            // just faster and more visibly urgent.
            cat.run(.sequence([settle, walkLoop(from: clampedX, speed: walkSpeed * 2)]))
        }
    }

    private func walkLoop(from startX: CGFloat, speed: CGFloat? = nil) -> SKAction {
        let speed = speed ?? walkSpeed
        func leg(to x: CGFloat, from x0: CGFloat) -> SKAction {
            .moveTo(x: x, duration: TimeInterval(abs(x - x0) / speed))
        }
        return .repeatForever(.sequence([
            leg(to: groundMaxX, from: startX),
            leg(to: groundMinX, from: groundMaxX)
        ]))
    }

    private func dropToGround() {
        cat.removeAllActions()
        cat.setScale(1)
        cat.alpha = 1
        let fallDuration = TimeInterval((cat.position.y - groundY) / dropSpeed)
        let fall = SKAction.move(to: CGPoint(x: cat.position.x, y: groundY), duration: max(0.1, fallDuration))
        cat.run(fall) { [weak self] in
            self?.applyCurrentAction()
        }
    }

    private func updateMoodTint(_ mood: Mood) {
        switch mood {
        case .happy:
            cat.fillColor = .systemOrange
        case .content:
            cat.fillColor = .systemOrange.blended(withFraction: 0.25, of: .systemGray) ?? .systemOrange
        case .grumpy:
            cat.fillColor = .systemOrange.blended(withFraction: 0.65, of: .systemGray) ?? .systemGray
        }
    }
}
