import ApplicationServices
import CoreGraphics
import Testing
@testable import Ramona

/// AXUIElement can't be constructed in a test (it's an opaque handle to a
/// live accessibility object), so this fakes the AXElementReading seam
/// Dock.bottomFrame(dockRoot:screenHeight:) actually consumes - letting the
/// tests below drive the real production function end to end instead of
/// only its hand-extracted pure helpers.
private struct FakeAXElement: AXElementReading {
    var role: String?
    var children: [AXElementReading] = []
    var frame: CGRect?

    func cocoaFrame(screenHeight: CGFloat) -> CGRect? { frame }
}

/// Exercises the pure geometry Dock.bottomFrame() is built from - the parts
/// that don't need a live AX connection. See BACKLOG.md's "Window/Dock
/// floor tracking is fragile" entry: this replaces a guessed fixed-pixel
/// correction with a measurement of the Dock's own icon frames, so these
/// tests are what actually pins the new behavior down instead of another
/// unverified constant.
@Suite struct DockGeometryTests {
    private let screenHeight: CGFloat = 1000

    // MARK: - isBottomDockStrip

    @Test func aWideShortStripAtTheBottomIsRecognized() {
        let frame = CGRect(x: 200, y: 0, width: 600, height: 70)
        #expect(Dock.isBottomDockStrip(frame, screenHeight: screenHeight))
    }

    @Test func aTallNarrowSideDockIsRejected() {
        let frame = CGRect(x: 0, y: 100, width: 70, height: 600)
        #expect(!Dock.isBottomDockStrip(frame, screenHeight: screenHeight))
    }

    @Test func anAutoHiddenDockSlidOffscreenIsRejected() {
        let frame = CGRect(x: 200, y: -60, width: 600, height: 70)
        #expect(!Dock.isBottomDockStrip(frame, screenHeight: screenHeight))
    }

    @Test func aStripReportedNearTheTopOfTheScreenIsRejected() {
        // Sanity guard against misreading some other tall/wide element as
        // the Dock - a real bottom Dock never sits in the upper half.
        let frame = CGRect(x: 200, y: 900, width: 600, height: 70)
        #expect(!Dock.isBottomDockStrip(frame, screenHeight: screenHeight))
    }

    // MARK: - median

    @Test func medianOfAnOddCountIsTheMiddleValue() {
        #expect(Dock.median([3, 1, 2]) == 2)
    }

    @Test func medianOfAnEvenCountAveragesTheMiddleTwo() {
        #expect(Dock.median([1, 2, 3, 4]) == 2.5)
    }

    @Test func medianOfEmptyIsNil() {
        #expect(Dock.median([]) == nil)
    }

    @Test func medianIgnoresASingleMagnifiedOutlier() {
        // Dock magnification can transiently inflate whichever icon's under
        // the cursor at poll time - the median should stay near the resting
        // size of the other icons, not get dragged up toward the outlier.
        let restingTops: [CGFloat] = Array(repeating: 940, count: 9)
        let magnifiedOutlier: CGFloat = 980
        #expect(Dock.median(restingTops + [magnifiedOutlier]) == 940)
    }

    // MARK: - strip

    @Test func stripUsesTheMedianItemTopAsTheGroundLine() {
        let listFrame = CGRect(x: 100, y: 0, width: 800, height: 75)
        let itemFrames = [
            CGRect(x: 120, y: 5, width: 50, height: 50),
            CGRect(x: 180, y: 5, width: 50, height: 50),
            CGRect(x: 240, y: 5, width: 50, height: 50),
        ]
        let strip = Dock.strip(listFrame: listFrame, itemFrames: itemFrames)
        #expect(strip.maxY == 55)
    }

    @Test func stripKeepsTheListsHorizontalExtentAndBottomEdge() {
        let listFrame = CGRect(x: 100, y: 0, width: 800, height: 75)
        let itemFrames = [CGRect(x: 120, y: 5, width: 50, height: 50)]
        let strip = Dock.strip(listFrame: listFrame, itemFrames: itemFrames)
        #expect(strip.minX == listFrame.minX)
        #expect(strip.width == listFrame.width)
        #expect(strip.minY == listFrame.minY)
    }

    @Test func stripFallsBackToTheListFrameWithNoItems() {
        let listFrame = CGRect(x: 100, y: 0, width: 800, height: 75)
        let strip = Dock.strip(listFrame: listFrame, itemFrames: [])
        #expect(strip == listFrame)
    }

    // MARK: - AXGeometry.cocoaFrame (shared by Dock and FrontmostWindowTracker)

    @Test func cocoaFrameFlipsAXsTopLeftOriginToBottomLeft() {
        // An element reported by AX as 10pt below the screen's top edge,
        // 40pt tall, should have its Cocoa bottom-left origin at
        // screenHeight - 10 - 40.
        let frame = AXGeometry.cocoaFrame(position: CGPoint(x: 5, y: 10), size: CGSize(width: 100, height: 40), screenHeight: screenHeight)
        #expect(frame.origin.x == 5)
        #expect(frame.origin.y == screenHeight - 10 - 40)
        #expect(frame.width == 100)
        #expect(frame.height == 40)
    }

    @Test func cocoaFrameOfAnElementFlushWithTheScreenTopHasMaxYAtScreenHeight() {
        let frame = AXGeometry.cocoaFrame(position: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 40), screenHeight: screenHeight)
        #expect(frame.maxY == screenHeight)
    }

    // MARK: - bottomFrame(dockRoot:screenHeight:) - the real production
    // function, driven end to end through a fake AX tree (see FakeAXElement)

    private func icon(x: CGFloat, topY: CGFloat) -> AXElementReading {
        FakeAXElement(role: "AXDockItem", frame: CGRect(x: x, y: topY - 50, width: 50, height: 50))
    }

    @Test func bottomFrameFindsTheListAndMeasuresItsIconsMedianTop() {
        let icons = [icon(x: 100, topY: 55), icon(x: 160, topY: 55), icon(x: 220, topY: 55)]
        let list = FakeAXElement(role: kAXListRole as String, children: icons, frame: CGRect(x: 90, y: 0, width: 800, height: 75))
        let root = FakeAXElement(role: "AXApplication", children: [list], frame: nil)

        let result = Dock.bottomFrame(dockRoot: root, screenHeight: screenHeight)
        #expect(result?.maxY == 55)
        #expect(result?.minX == 90)
        #expect(result?.width == 800)
    }

    @Test func bottomFrameSkipsNonListChildrenToFindTheStrip() {
        let decoy = FakeAXElement(role: "AXMenuBar", frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let icons = [icon(x: 100, topY: 55)]
        let list = FakeAXElement(role: kAXListRole as String, children: icons, frame: CGRect(x: 90, y: 0, width: 800, height: 75))
        let root = FakeAXElement(role: "AXApplication", children: [decoy, list], frame: nil)

        #expect(Dock.bottomFrame(dockRoot: root, screenHeight: screenHeight)?.maxY == 55)
    }

    @Test func bottomFrameReturnsNilWhenNoListChildExists() {
        let root = FakeAXElement(role: "AXApplication", children: [
            FakeAXElement(role: "AXMenuBar", frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        ], frame: nil)
        #expect(Dock.bottomFrame(dockRoot: root, screenHeight: screenHeight) == nil)
    }

    @Test func bottomFrameReturnsNilForASideDock() {
        let list = FakeAXElement(role: kAXListRole as String, children: [], frame: CGRect(x: 0, y: 100, width: 70, height: 600))
        let root = FakeAXElement(role: "AXApplication", children: [list], frame: nil)
        #expect(Dock.bottomFrame(dockRoot: root, screenHeight: screenHeight) == nil)
    }

    @Test func bottomFrameIgnoresASingleMagnifiedIconLiveOnTheRealPipeline() {
        var icons = (0..<9).map { icon(x: CGFloat($0) * 60, topY: 55) }
        icons.append(icon(x: 600, topY: 95)) // the icon under the cursor, magnified
        let list = FakeAXElement(role: kAXListRole as String, children: icons, frame: CGRect(x: 0, y: 0, width: 700, height: 100))
        let root = FakeAXElement(role: "AXApplication", children: [list], frame: nil)

        #expect(Dock.bottomFrame(dockRoot: root, screenHeight: screenHeight)?.maxY == 55)
    }
}
