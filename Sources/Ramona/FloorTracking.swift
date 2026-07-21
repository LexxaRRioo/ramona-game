import CoreGraphics

/// Where Ramona is currently standing. Pulled out of CatScene as plain,
/// AppKit/SpriteKit-free state so the surface-selection rules below are
/// unit-testable without a live SKScene.
enum Surface: Equatable {
    case floor
    case window(CGRect)
}

/// Pure decision logic for which surface Ramona should be on and where its
/// ground line sits - no AX/SpriteKit dependency, so this is the seam that
/// actually gets test coverage for the window/Dock interaction bugs (see
/// BACKLOG.md's "Window/Dock floor tracking is fragile" entry).
enum FloorTracking {
    /// A window is landable only if she can physically fit and stand on it -
    /// too narrow, off the top of the screen, or entirely outside the
    /// visible scene doesn't count.
    static func isValidPerch(_ frame: CGRect, sceneSize: CGSize, minPerchWidth: CGFloat) -> Bool {
        frame.width >= minPerchWidth && frame.maxY < sceneSize.height
            && CGRect(origin: .zero, size: sceneSize).intersects(frame)
    }

    /// The active ground line, in priority order: the window she's standing
    /// on, then the Dock strip, then the bare screen floor.
    static func groundBounds(
        currentSurface: Surface,
        dockSurface: CGRect?,
        sceneSize: CGSize,
        groundMargin: CGFloat,
        sideMargin: CGFloat,
        minPerchWidth: CGFloat
    ) -> (y: CGFloat, minX: CGFloat, maxX: CGFloat) {
        if case .window(let frame) = currentSurface, isValidPerch(frame, sceneSize: sceneSize, minPerchWidth: minPerchWidth) {
            return (frame.maxY, frame.minX + sideMargin / 2, frame.maxX - sideMargin / 2)
        }
        if let dock = dockSurface {
            return (dock.maxY, dock.minX + sideMargin / 2, dock.maxX - sideMargin / 2)
        }
        return (groundMargin, sideMargin, sceneSize.width - sideMargin)
    }

    /// Whether a candidate window sits meaningfully higher than wherever
    /// she's currently standing - the basis for CatAction.climb's "prefer
    /// the nearest highest point" bias (BACKLOG: climb targeting), rather
    /// than climb only ever winning by luck of the trait-weighted scoring.
    /// False once she's already standing on that same window, since her own
    /// ground line then equals its top edge (not strictly higher than
    /// itself) - so this doesn't keep nudging her to "reclimb" where she is.
    static func offersHigherPerch(
        windowFrame: CGRect?,
        currentGroundY: CGFloat,
        sceneSize: CGSize,
        minPerchWidth: CGFloat
    ) -> Bool {
        guard let windowFrame, isValidPerch(windowFrame, sceneSize: sceneSize, minPerchWidth: minPerchWidth) else { return false }
        return windowFrame.maxY > currentGroundY
    }

    /// Whether a standing/sitting pose at this ground line would poke up
    /// into the menu bar's own rendering band and get visually clipped -
    /// Ramona's overlay window intentionally renders below the menu bar and
    /// its status items (see OverlayWindow's level comment), so a perch
    /// close enough to the very top of the screen (a maximized window, or
    /// the menu bar strip itself) leaves no room for a standing/sitting
    /// pose before it's covered. requiredClearance is a flat worst-case
    /// estimate (tallest pose's visible height above its ground line, plus
    /// the tallest menu bar) rather than querying individual status item
    /// frames - see CatScene.occlusionClearance.
    static func perchLeavesHerOccluded(groundY: CGFloat, sceneHeight: CGFloat, requiredClearance: CGFloat) -> Bool {
        sceneHeight - groundY < requiredClearance
    }

    /// Decides what her surface should become when the live window tracker
    /// reports an update, while she's standing on a window. Any valid new
    /// frame is followed - whether it's the same window continuing to move,
    /// or a different window that just became frontmost (she jumps over to
    /// it instead of falling off just because focus moved elsewhere - see
    /// CatScene.setTargetWindow, which uses the separate `isSameWindow` flag
    /// to pick a walk-style jump animation for the latter case, regardless
    /// of the height difference between the two windows). Only a nil or
    /// too-small/off-screen frame sends her back to the floor.
    ///
    /// Returns nil when nothing needs to change (e.g. she isn't on a window
    /// in the first place, so a frontmost-window update doesn't concern
    /// her).
    static func nextSurface(
        afterWindowUpdate frame: CGRect?,
        currentSurface: Surface,
        sceneSize: CGSize,
        minPerchWidth: CGFloat
    ) -> Surface? {
        guard case .window = currentSurface else { return nil }
        if let frame, isValidPerch(frame, sceneSize: sceneSize, minPerchWidth: minPerchWidth) {
            return .window(frame)
        }
        return .floor
    }
}
