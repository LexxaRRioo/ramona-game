import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService (macOS 13+) for the menu bar's
/// "Launch at Login" toggle - no plist/helper-app boilerplate needed since
/// we're registering the main app itself, not a separate login-item target.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("LaunchAtLogin: failed to \(enabled ? "register" : "unregister"): \(error)")
        }
    }
}
