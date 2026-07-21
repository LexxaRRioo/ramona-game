import AppKit
import ApplicationServices

/// The macOS Dock's visible strip, read from the Dock process via the
/// Accessibility API - the same permission window tracking already needs. Used
/// as Ramona's default floor so she stands on top of the Dock instead of the
/// bare screen edge (the overlay is also raised above the Dock's window level
/// so she's in front of it, not hidden behind - see OverlayWindow).
///
/// It has to be AX, not CGWindowListCopyWindowInfo: on modern macOS the Dock
/// draws into a single full-screen backing window, so the window list never
/// exposes the strip's real bounds - only the Dock's AXList child does.
enum Dock {
    /// The Dock's AXList frame reports the icon strip's full interactive hit
    /// area, which includes headroom above the icons for the hover/bounce/
    /// magnify animation - not the visible glass's actual top edge. That
    /// headroom scales with the user's Dock icon size (System Settings >
    /// Desktop & Dock > Size), so a single fixed correction measured on one
    /// machine doesn't hold on another with a different tile size (this bit
    /// a 0.2.0 fix that hardcoded -5pt - see BACKLOG.md's "Window/Dock floor
    /// tracking is fragile" entry). Instead, the ground line is measured
    /// directly from the individual icon elements' own frames (AXChildren of
    /// the list), which already match their resting rendered size and so
    /// self-adapt to any tile size with no guessed constant.
    ///
    /// The median (not max) of the icons' top edges is used deliberately:
    /// with Dock magnification on, an icon under the cursor at poll time can
    /// transiently report an inflated frame, and a max would chase that
    /// single outlier every time the mouse happens to be over the Dock. The
    /// median stays put unless most icons actually change size together.
    static func bottomFrame() -> CGRect? {
        guard let screenHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height,
              let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return nil
        }

        let root = RealAXElement(element: AXUIElementCreateApplication(dockApp.processIdentifier))
        return bottomFrame(dockRoot: root, screenHeight: screenHeight)
    }

    /// The actual decision logic, taking an abstract AX root instead of
    /// calling into ApplicationServices directly - see AXElementReading.
    /// This is what DockGeometryTests drives against synthetic data, so the
    /// real production function is under test, not just the pure helpers
    /// (isBottomDockStrip/strip/median) it's built from.
    static func bottomFrame(dockRoot: AXElementReading, screenHeight: CGFloat) -> CGRect? {
        guard let list = dockList(in: dockRoot, screenHeight: screenHeight),
              isBottomDockStrip(list.frame, screenHeight: screenHeight) else {
            return nil
        }

        let itemFrames = list.element.children.compactMap { $0.cocoaFrame(screenHeight: screenHeight) }
        return strip(listFrame: list.frame, itemFrames: itemFrames)
    }

    /// A bottom Dock is a short, wide strip hugging the screen's bottom
    /// edge; anything tall (side Dock) or slid off-screen (auto-hidden)
    /// isn't something she can walk on.
    static func isBottomDockStrip(_ frame: CGRect, screenHeight: CGFloat) -> Bool {
        frame.width > frame.height && frame.minY >= 0 && frame.maxY < screenHeight * 0.5
    }

    /// The strip's real ground line: the median top edge of its icons, with
    /// the list's own bottom edge and horizontal extent kept as-is (icons
    /// can start a few points in from the strip's padded/rounded sides, but
    /// the list's own width is what groundBounds paces her within). Falls
    /// back to the raw list frame if AX ever reports zero icons (defensive -
    /// in practice the Dock always has at least Finder + Trash).
    static func strip(listFrame: CGRect, itemFrames: [CGRect]) -> CGRect {
        guard let top = median(itemFrames.map(\.maxY)) else { return listFrame }
        return CGRect(x: listFrame.minX, y: listFrame.minY, width: listFrame.width, height: top - listFrame.minY)
    }

    static func median(_ values: [CGFloat]) -> CGFloat? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    /// The app-icon list is the Dock's AXList child; its frame is the strip.
    private static func dockList(in root: AXElementReading, screenHeight: CGFloat) -> (element: AXElementReading, frame: CGRect)? {
        for child in root.children {
            guard child.role == kAXListRole as String,
                  let frame = child.cocoaFrame(screenHeight: screenHeight) else { continue }
            return (child, frame)
        }
        return nil
    }
}

/// Thin AXUIElement-backed conformance - the only part of Dock's pipeline
/// that actually calls into ApplicationServices, kept intentionally small so
/// there's as little unverifiable code as possible outside the tested
/// bottomFrame(dockRoot:screenHeight:) above.
private struct RealAXElement: AXElementReading {
    let element: AXUIElement

    var role: String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    var children: [AXElementReading] {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let elements = value as? [AXUIElement] else {
            return []
        }
        return elements.map(RealAXElement.init)
    }

    /// AX positions are top-left-origin; flip to Cocoa's bottom-left to match
    /// NSScreen/SKView, the same conversion FrontmostWindowTracker uses.
    func cocoaFrame(screenHeight: CGFloat) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else {
            return nil
        }
        return AXGeometry.cocoaFrame(position: position, size: size, screenHeight: screenHeight)
    }
}
