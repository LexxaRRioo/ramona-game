import SpriteKit

/// Placeholder cat: a plain circle pacing the bottom edge of the screen.
/// Stands in for the real sprite until Phase 5 (content production).
final class CatScene: SKScene {
    private let cat = SKShapeNode(circleOfRadius: 16)
    private let bottomMargin: CGFloat = 20
    private let sideMargin: CGFloat = 40
    private let walkSpeed: CGFloat = 60 // points per second

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill

        cat.fillColor = .systemOrange
        cat.strokeColor = .clear
        cat.position = CGPoint(x: size.width / 2, y: bottomMargin)
        addChild(cat)

        walk()
    }

    private func walk() {
        guard size.width > sideMargin * 2 else { return }

        let leftEdge = sideMargin
        let rightEdge = size.width - sideMargin

        func leg(to x: CGFloat, from: CGFloat) -> SKAction {
            .moveTo(x: x, duration: TimeInterval(abs(x - from) / walkSpeed))
        }

        let toRight = leg(to: rightEdge, from: leftEdge)
        let toLeft = leg(to: leftEdge, from: rightEdge)

        cat.run(.repeatForever(.sequence([toRight, toLeft])))
    }
}
