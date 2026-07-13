import ApplicationServices
import Foundation

/// Wraps the Accessibility trust check/prompt flow (AXIsProcessTrusted).
/// Ramona needs this granted to read other apps' window frames via AXUIElement.
enum AccessibilityPermission {
    private static let grantedBeforeKey = "accessibilityGrantedBefore"

    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Persisted across launches (and across rebuilds, unlike the OS grant
    /// itself - see the note on hasBeenGrantedBefore's read site) so we
    /// know whether the user has already been through the System Settings
    /// dance before, and don't nag them with the same modal every launch.
    static var hasBeenGrantedBefore: Bool {
        get { UserDefaults.standard.bool(forKey: grantedBeforeKey) }
        set { UserDefaults.standard.set(newValue, forKey: grantedBeforeKey) }
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
