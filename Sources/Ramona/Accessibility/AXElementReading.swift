import CoreGraphics

/// Abstraction over "an AX element's role, children, and frame" - the three
/// things Dock.bottomFrame() actually reads. AXUIElement itself is an opaque
/// handle to a live accessibility object with no supported way to construct
/// a fake one, so this seam is what lets Dock's real decision logic (which
/// child is the icon strip, is it a bottom dock, what's the median icon
/// top) run against synthetic data in a test - exercising the actual
/// production function, not just hand-extracted pure helpers around it.
protocol AXElementReading {
    var role: String? { get }
    var children: [AXElementReading] { get }
    func cocoaFrame(screenHeight: CGFloat) -> CGRect?
}
