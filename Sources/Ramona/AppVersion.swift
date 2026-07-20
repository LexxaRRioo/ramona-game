import Foundation

/// Reads CFBundleShortVersionString, set from the repo-root VERSION file by
/// both build scripts (see plan.md > Versioning). "dev" for a plain `swift
/// build` run outside either script, which has no Info.plist to read.
enum AppVersion {
    static var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
