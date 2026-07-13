import SpriteKit

/// Placeholder cat: a plain circle standing in for the real sprite (Phase 5).
/// Movement follows whatever action BehaviorEngine picks (Phase 3), using
/// the frontmost tracked window's top edge when one is available (Phase 2),
/// or the screen's bottom edge otherwise.
final class CatScene: SKScene {
    private let cat = SKShapeNode(circleOfRadius: 16)
    private let groundMargin: CGFloat = 20
    private let sideMargin: CGFloat = 40
    private let minPerchWidth: CGFloat = 80
    private let walkSpeed: CGFloat = 60 // points per second
    private let dropSpeed: CGFloat = 220 // points per second, falling off a window

    private var windowFrame: CGRect?
    private var groundY: CGFloat = 0
    private var groundMinX: CGFloat = 0
    private var groundMaxX: CGFloat = 0
    private var currentAction: CatAction = .walk

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

        applyCurrentAction()
    }

    /// Called whenever the tracked window's frame changes, or with nil when
    /// there's no trackable window (closed, minimized, app switched to one
    /// without a window, or Accessibility not yet granted).
    func setTargetWindow(_ frame: CGRect?) {
        let screenBounds = CGRect(origin: .zero, size: size)
        guard let frame,
              frame.width >= minPerchWidth,
              frame.maxY < size.height,
              screenBounds.intersects(frame) else {
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

    /// Called by BehaviorEngine whenever its utility AI picks a new action
    /// or mood changes. Mood only tints the placeholder for now - real
    /// per-mood animations arrive with Phase 5 art.
    func apply(action: CatAction, mood: Mood) {
        currentAction = action
        updateMoodTint(mood)
        applyCurrentAction()
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
        }
    }

    private func walkLoop(from startX: CGFloat) -> SKAction {
        func leg(to x: CGFloat, from x0: CGFloat) -> SKAction {
            .moveTo(x: x, duration: TimeInterval(abs(x - x0) / walkSpeed))
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
