import AppKit
import SpriteKit

final class OverlayWindowController: NSWindowController {
    convenience init(screen: NSScreen) {
        self.init(window: OverlayWindow(screen: screen))
    }

    var catScene: CatScene {
        (window as! OverlayWindow).catScene
    }

    /// Stops (or resumes) the SpriteKit render/update loop entirely, e.g.
    /// around screen lock, for near-zero idle CPU.
    func setPaused(_ paused: Bool) {
        (window as! OverlayWindow).skView.isPaused = paused
    }
}

/// Full-screen, click-through, always-on-top window that hosts the cat.
/// Skeleton phase: the whole window ignores mouse events since the cat
/// isn't interactive yet (see Phase 4 for pixel-level hit-testing).
final class OverlayWindow: NSWindow {
    let catScene: CatScene
    let skView: SKView

    init(screen: NSScreen) {
        catScene = CatScene(size: screen.frame.size)
        skView = SKView(frame: CGRect(origin: .zero, size: screen.frame.size))

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isReleasedWhenClosed = false

        skView.allowsTransparency = true
        skView.preferredFramesPerSecond = 30
        skView.presentScene(catScene)
        contentView = skView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
