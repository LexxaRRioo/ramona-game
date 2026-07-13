import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindowController: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let screen = NSScreen.main else { return }
        let controller = OverlayWindowController(screen: screen)
        controller.showWindow(nil)
        overlayWindowController = controller
    }
}
