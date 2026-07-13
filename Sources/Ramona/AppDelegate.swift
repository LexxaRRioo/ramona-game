import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindowController: OverlayWindowController?
    private var windowTracker: FrontmostWindowTracker?
    private var permissionPollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let screen = NSScreen.main else { return }
        let controller = OverlayWindowController(screen: screen)
        controller.showWindow(nil)
        overlayWindowController = controller

        startAccessibilityFlow()
    }

    private func startAccessibilityFlow() {
        if AccessibilityPermission.isGranted {
            startWindowTracking()
            return
        }

        AccessibilityPermission.requestIfNeeded()

        // macOS only shows its own consent dialog once; a returning user who
        // previously denied it gets no dialog at all, so fall back to an
        // explicit alert if we're still untrusted a moment later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, !AccessibilityPermission.isGranted else { return }
            self.showAccessibilityInstructionsAlert()
        }

        permissionPollTimer = AccessibilityPermission.waitForGrant { [weak self] in
            self?.startWindowTracking()
        }
    }

    private func showAccessibilityInstructionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Ramona needs Accessibility access"
        alert.informativeText = "To walk on your windows, open System Settings > Privacy & Security > Accessibility and enable Ramona. She'll start tracking windows automatically once you do."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startWindowTracking() {
        let tracker = FrontmostWindowTracker()
        tracker.onFrameChange = { [weak self] frame in
            self?.overlayWindowController?.catScene.setTargetWindow(frame)
        }
        windowTracker = tracker
    }
}
