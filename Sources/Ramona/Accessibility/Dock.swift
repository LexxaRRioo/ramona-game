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
    /// The Dock's AXList frame consistently reports ~5pt more height than the
    /// strip's actual rendered top edge (measured via screenshot pixel-
    /// sampling against the live frame - the reported box's top few points
    /// sit in empty space above the visible glass, not on it, so she looked
    /// like she was standing in front of the Dock instead of on it). Likely
    /// headroom AX reserves for the icon hover/bounce animation. Subtracted
    /// from the reported height so groundBounds' ground line lands on the
    /// strip's real top pixel.
    private static let topPaddingCorrection: CGFloat = 5

    /// The Dock strip's frame in Cocoa (bottom-left origin) coordinates, or nil
    /// when the Dock is auto-hidden, on a side edge, or Accessibility isn't
    /// granted yet - callers then fall back to the screen-bottom floor.
    static func bottomFrame() -> CGRect? {
        guard let screenHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height,
              let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return nil
        }

        let dock = AXUIElementCreateApplication(dockApp.processIdentifier)
        var childrenValue: AnyObject?
        guard AXUIElementCopyAttributeValue(dock, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else {
            return nil
        }

        // The app-icon list is the Dock's AXList child; its frame is the strip.
        for child in children {
            var roleValue: AnyObject?
            guard AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleValue) == .success,
                  roleValue as? String == kAXListRole as String,
                  let frame = cocoaFrame(of: child, screenHeight: screenHeight) else { continue }

            // A bottom Dock is a short, wide strip hugging the screen's bottom
            // edge; anything tall (side Dock) or slid off-screen (auto-hidden)
            // isn't something she can walk on.
            guard frame.width > frame.height, frame.minY >= 0, frame.maxY < screenHeight * 0.5 else { continue }
            return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height - topPaddingCorrection)
        }
        return nil
    }

    /// AX positions are top-left-origin; flip to Cocoa's bottom-left to match
    /// NSScreen/SKView, the same conversion FrontmostWindowTracker uses.
    private static func cocoaFrame(of element: AXUIElement, screenHeight: CGFloat) -> CGRect? {
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
        return CGRect(x: position.x, y: screenHeight - position.y - size.height, width: size.width, height: size.height)
    }
}
