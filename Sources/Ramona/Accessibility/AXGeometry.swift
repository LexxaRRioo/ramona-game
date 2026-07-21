import CoreGraphics

/// Shared coordinate math for the Accessibility API - used by both `Dock`
/// and `FrontmostWindowTracker`, which each read window/element geometry
/// from AX and need it in the same terms as NSScreen/SKView.
enum AXGeometry {
    /// AX reports position/size in a top-left-origin space; NSScreen/SKView
    /// (and everything CatScene works in) use Cocoa's bottom-left origin.
    /// Pure conversion, no AX calls - shared by every call site that reads
    /// an AXPosition/AXSize pair so the flip is only written once.
    static func cocoaFrame(position: CGPoint, size: CGSize, screenHeight: CGFloat) -> CGRect {
        CGRect(x: position.x, y: screenHeight - position.y - size.height, width: size.width, height: size.height)
    }
}
