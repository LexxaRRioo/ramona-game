import Foundation

/// Bridges the SwiftUI menu bar toggle (RamonaApp) to the AppKit-side
/// overlay (AppDelegate/CatScene) - there's no shared observable state
/// between them otherwise, so a plain closure-notified singleton is
/// simplest.
final class DebugSettings {
    static let shared = DebugSettings()
    private init() {}

    var isVisible = false {
        didSet { onChange?(isVisible) }
    }
    var onChange: ((Bool) -> Void)?
}
