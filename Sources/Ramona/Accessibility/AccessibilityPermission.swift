import ApplicationServices
import Foundation

/// Wraps the Accessibility trust check/prompt flow (AXIsProcessTrusted).
/// Ramona needs this granted to read other apps' window frames via AXUIElement.
enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Triggers macOS's native "add Ramona to Accessibility" system prompt,
    /// if it hasn't already been shown and dismissed once before. Safe to
    /// call repeatedly.
    static func requestIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// System Settings changes aren't observable via notification, so this
    /// polls until permission is granted, then fires `onGranted` once on
    /// the main queue and stops.
    @discardableResult
    static func waitForGrant(pollInterval: TimeInterval = 1.0, onGranted: @escaping () -> Void) -> Timer {
        Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { timer in
            guard isGranted else { return }
            timer.invalidate()
            DispatchQueue.main.async(execute: onGranted)
        }
    }
}
