import AppKit
import SpriteKit

final class OverlayWindowController: NSWindowController {
    convenience init(screen: NSScreen) {
        self.init(window: OverlayWindow(screen: screen))
    }

    var catScene: CatScene {
        (window as! OverlayWindow).catScene
    }
}

/// Full-screen, click-through, always-on-top window that hosts the cat.
/// Skeleton phase: the whole window ignores mouse events since the cat
/// isn't interactive yet (see Phase 4 for pixel-level hit-testing).
final class OverlayWindow: NSWindow {
    let catScene: CatScene

    init(screen: NSScreen) {
        catScene = CatScene(size: screen.frame.size)

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

        let skView = SKView(frame: CGRect(origin: .zero, size: screen.frame.size))
        skView.allowsTransparency = true
        skView.presentScene(catScene)
        contentView = skView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
