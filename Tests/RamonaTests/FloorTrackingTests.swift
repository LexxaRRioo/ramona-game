import CoreGraphics
import Testing
@testable import Ramona

/// Locks down the window/Dock surface-selection rules - see BACKLOG.md's
/// "Window/Dock floor tracking is fragile" entry. In particular,
/// nextSurface's isSameWindow-independent "follow any valid frame, jump
/// animation aside" behavior guards against the earlier bug where a
/// different window becoming frontmost (not the one she was standing on)
/// could otherwise be mishandled.
@Suite struct FloorTrackingTests {
    private let sceneSize = CGSize(width: 1200, height: 800)
    private let minPerchWidth: CGFloat = 80

    // MARK: - isValidPerch

    @Test func perchTooNarrowIsInvalid() {
        let frame = CGRect(x: 0, y: 0, width: 79, height: 40)
        #expect(!FloorTracking.isValidPerch(frame, sceneSize: sceneSize, minPerchWidth: minPerchWidth))
    }

    @Test func perchAtMinimumWidthIsValid() {
        let frame = CGRect(x: 0, y: 0, width: 80, height: 40)
        #expect(FloorTracking.isValidPerch(frame, sceneSize: sceneSize, minPerchWidth: minPerchWidth))
    }

    @Test func perchOffTheTopOfTheScreenIsInvalid() {
        let frame = CGRect(x: 0, y: sceneSize.height, width: 200, height: 40)
        #expect(!FloorTracking.isValidPerch(frame, sceneSize: sceneSize, minPerchWidth: minPerchWidth))
    }

    @Test func perchEntirelyOutsideTheSceneIsInvalid() {
        let frame = CGRect(x: sceneSize.width + 100, y: 0, width: 200, height: 40)
        #expect(!FloorTracking.isValidPerch(frame, sceneSize: sceneSize, minPerchWidth: minPerchWidth))
    }

    // MARK: - groundBounds priority: window > Dock > floor

    @Test func groundBoundsUsesTheWindowWhenStandingOnAValidOne() {
        let window = CGRect(x: 100, y: 300, width: 400, height: 200)
        let bounds = FloorTracking.groundBounds(
            currentSurface: .window(window), dockSurface: CGRect(x: 0, y: 0, width: 1200, height: 60),
            sceneSize: sceneSize, groundMargin: 20, sideMargin: 40, minPerchWidth: minPerchWidth
        )
        #expect(bounds.y == window.maxY)
    }

    @Test func groundBoundsFallsBackToDockWhenNotOnAWindow() {
        let dock = CGRect(x: 0, y: 0, width: 1200, height: 60)
        let bounds = FloorTracking.groundBounds(
            currentSurface: .floor, dockSurface: dock,
            sceneSize: sceneSize, groundMargin: 20, sideMargin: 40, minPerchWidth: minPerchWidth
        )
        #expect(bounds.y == dock.maxY)
    }

    @Test func groundBoundsFallsBackToTheScreenFloorWithNoWindowOrDock() {
        let bounds = FloorTracking.groundBounds(
            currentSurface: .floor, dockSurface: nil,
            sceneSize: sceneSize, groundMargin: 20, sideMargin: 40, minPerchWidth: minPerchWidth
        )
        #expect(bounds.y == 20)
        #expect(bounds.minX == 40)
        #expect(bounds.maxX == sceneSize.width - 40)
    }

    @Test func groundBoundsIgnoresAWindowThatShrankBelowLandableWidth() {
        let tooNarrow = CGRect(x: 100, y: 300, width: 40, height: 200)
        let dock = CGRect(x: 0, y: 0, width: 1200, height: 60)
        let bounds = FloorTracking.groundBounds(
            currentSurface: .window(tooNarrow), dockSurface: dock,
            sceneSize: sceneSize, groundMargin: 20, sideMargin: 40, minPerchWidth: minPerchWidth
        )
        #expect(bounds.y == dock.maxY)
    }

    // MARK: - nextSurface: the actual window-tracking bug fix

    @Test func noChangeWhenNotStandingOnAWindow() {
        let next = FloorTracking.nextSurface(
            afterWindowUpdate: CGRect(x: 0, y: 0, width: 400, height: 200),
            currentSurface: .floor, sceneSize: sceneSize, minPerchWidth: minPerchWidth
        )
        #expect(next == nil)
    }

    @Test func followsTheSameWindowAsItMoves() {
        let original = CGRect(x: 100, y: 300, width: 400, height: 200)
        let moved = CGRect(x: 250, y: 500, width: 400, height: 200)
        let next = FloorTracking.nextSurface(
            afterWindowUpdate: moved, currentSurface: .window(original), sceneSize: sceneSize, minPerchWidth: minPerchWidth
        )
        #expect(next == .window(moved))
    }

    @Test func jumpsToADifferentWindowThatBecameFrontmost() {
        // The core fix: this used to be indistinguishable from "my window
        // moved" at the CatScene layer - now nextSurface just says "follow
        // any valid frame" and CatScene picks the jump animation based on
        // isSameWindow (see CatScene.setTargetWindow), so a focus switch to
        // an unrelated window is still followed, not ignored or teleported.
        let original = CGRect(x: 100, y: 300, width: 400, height: 200)
        let differentWindow = CGRect(x: 700, y: 50, width: 300, height: 150)
        let next = FloorTracking.nextSurface(
            afterWindowUpdate: differentWindow, currentSurface: .window(original), sceneSize: sceneSize, minPerchWidth: minPerchWidth
        )
        #expect(next == .window(differentWindow))
    }

    @Test func fallsToTheFloorWhenTheWindowIsGone() {
        let original = CGRect(x: 100, y: 300, width: 400, height: 200)
        let next = FloorTracking.nextSurface(
            afterWindowUpdate: nil, currentSurface: .window(original), sceneSize: sceneSize, minPerchWidth: minPerchWidth
        )
        #expect(next == .floor)
    }

    @Test func fallsToTheFloorWhenHerOwnWindowShrinksTooSmall() {
        let original = CGRect(x: 100, y: 300, width: 400, height: 200)
        let shrunk = CGRect(x: 100, y: 300, width: 40, height: 200)
        let next = FloorTracking.nextSurface(
            afterWindowUpdate: shrunk, currentSurface: .window(original), sceneSize: sceneSize, minPerchWidth: minPerchWidth
        )
        #expect(next == .floor)
    }

    @Test func fallsToTheFloorWhenANewFrontmostWindowIsOffTheTopOfTheScreen() {
        let original = CGRect(x: 100, y: 300, width: 400, height: 200)
        let offscreen = CGRect(x: 100, y: sceneSize.height + 10, width: 400, height: 200)
        let next = FloorTracking.nextSurface(
            afterWindowUpdate: offscreen, currentSurface: .window(original), sceneSize: sceneSize, minPerchWidth: minPerchWidth
        )
        #expect(next == .floor)
    }
}
