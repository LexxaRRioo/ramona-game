import SpriteKit

/// Placeholder cat: a plain circle that paces the screen's bottom edge by
/// default, or the top edge of the frontmost tracked window when one is
/// available (see FrontmostWindowTracker). Stands in for the real sprite
/// and utility-AI behavior engine until Phases 3 and 5.
final class CatScene: SKScene {
    private let cat = SKShapeNode(circleOfRadius: 16)
    private let groundMargin: CGFloat = 20
    private let sideMargin: CGFloat = 40
    private let minPerchWidth: CGFloat = 80
    private let walkSpeed: CGFloat = 60 // points per second
    private let dropSpeed: CGFloat = 220 // points per second, falling off a window

    private var windowFrame: CGRect?

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill

        cat.fillColor = .systemOrange
        cat.strokeColor = .clear
        cat.position = CGPoint(x: size.width / 2, y: groundMargin)
        addChild(cat)

        pace(minX: sideMargin, maxX: size.width - sideMargin, y: groundMargin)
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
            if windowFrame != nil {
                windowFrame = nil
                dropToGround()
            }
            return
        }

        windowFrame = frame
        let minX = frame.minX + sideMargin / 2
        let maxX = frame.maxX - sideMargin / 2
        guard minX < maxX else { return }
        pace(minX: minX, maxX: maxX, y: frame.maxY)
    }

    private func pace(minX: CGFloat, maxX: CGFloat, y: CGFloat) {
        cat.removeAllActions()

        let clampedX = min(max(cat.position.x, minX), maxX)
        let settle = SKAction.move(to: CGPoint(x: clampedX, y: y), duration: 0.25)

        func leg(to x: CGFloat, from x0: CGFloat) -> SKAction {
            .moveTo(x: x, duration: TimeInterval(abs(x - x0) / walkSpeed))
        }

        cat.run(.sequence([
            settle,
            .repeatForever(.sequence([leg(to: maxX, from: minX), leg(to: minX, from: maxX)]))
        ]))
    }

    private func dropToGround() {
        cat.removeAllActions()
        let fallDuration = TimeInterval((cat.position.y - groundMargin) / dropSpeed)
        let fall = SKAction.move(to: CGPoint(x: cat.position.x, y: groundMargin), duration: max(0.1, fallDuration))
        cat.run(fall) { [weak self] in
            guard let self else { return }
            self.pace(minX: self.sideMargin, maxX: self.size.width - self.sideMargin, y: self.groundMargin)
        }
    }
}
