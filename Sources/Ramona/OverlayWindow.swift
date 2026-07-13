import AppKit
import SpriteKit

final class OverlayWindowController: NSWindowController {
    convenience init(screen: NSScreen) {
        self.init(window: OverlayWindow(screen: screen))
    }

    var catScene: CatScene {
        (window as! OverlayWindow).catScene
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        (window as! OverlayWindow).startHoverTracking()
    }

    /// Stops (or resumes) the SpriteKit render/update loop and the Phase 4
    /// cursor-hover polling entirely, e.g. around screen lock, for
    /// near-zero idle CPU.
    func setPaused(_ paused: Bool) {
        let overlayWindow = window as! OverlayWindow
        overlayWindow.skView.isPaused = paused
        if paused {
            overlayWindow.stopHoverTracking()
        } else {
            overlayWindow.startHoverTracking()
        }
    }
}

/// Full-screen window that hosts the cat. Ignores mouse events (click-through
/// to whatever's underneath) everywhere except while the cursor is over the
/// cat herself (Phase 4) - see startHoverTracking.
///
/// NSPanel + .nonactivatingPanel, not plain NSWindow: without it, a click on
/// the cat (petting/dragging) makes our accessory app the active app, which
/// visually deactivates (greys out) whatever window was frontmost, even
/// though canBecomeKey/canBecomeMain already refuse key/main status.
/// .nonactivatingPanel is the documented way to receive clicks without that
/// side effect.
final class OverlayWindow: NSPanel {
    let catScene: CatScene
    let skView: SKView
    private var hoverPollTimer: Timer?

    init(screen: NSScreen) {
        catScene = CatScene(size: screen.frame.size)
        skView = SKView(frame: CGRect(origin: .zero, size: screen.frame.size))

        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
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

    /// Polls the cursor (rather than a global NSEvent monitor, to stay
    /// consistent with the rest of the app's Timer-driven design and avoid
    /// extra API surface) and toggles ignoresMouseEvents off only while it's
    /// within the cat's hit radius, so a click there reaches CatScene's
    /// mouseDown/mouseDragged/mouseUp instead of passing through to
    /// whatever's underneath. Suspended entirely mid-drag (isInteracting),
    /// since the cursor is expected to leave the original hit area then.
    func startHoverTracking() {
        guard hoverPollTimer == nil else { return }
        hoverPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            self?.pollHover()
        }
    }

    func stopHoverTracking() {
        hoverPollTimer?.invalidate()
        hoverPollTimer = nil
    }

    private func pollHover() {
        guard !catScene.isInteracting else { return }
        let screenPoint = NSEvent.mouseLocation
        let local = CGPoint(x: screenPoint.x - frame.origin.x, y: screenPoint.y - frame.origin.y)
        ignoresMouseEvents = !catScene.hitTest(local)
    }
}
