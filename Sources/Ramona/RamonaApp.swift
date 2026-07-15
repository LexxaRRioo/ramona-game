import SwiftUI

@main
struct RamonaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var debugInfoVisible = false
    @State private var quietModeEnabled = false
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled

    var body: some Scene {
        MenuBarExtra("Ramona", systemImage: "cat.fill") {
            Button("Feed") {
                appDelegate.feed()
            }
            Button("Offer Toy") {
                appDelegate.offerToy()
            }
            Divider()
            Toggle("Quiet Mode", isOn: $quietModeEnabled)
                .onChange(of: quietModeEnabled) { _, enabled in
                    appDelegate.setQuietMode(enabled)
                }
            Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                .onChange(of: launchAtLoginEnabled) { _, enabled in
                    LaunchAtLogin.setEnabled(enabled)
                }
            Divider()
            Toggle("Debug Info", isOn: $debugInfoVisible)
                .onChange(of: debugInfoVisible) { _, visible in
                    DebugSettings.shared.isVisible = visible
                }
            Divider()
            Button("Quit Ramona") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
