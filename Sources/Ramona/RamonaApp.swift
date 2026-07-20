import SwiftUI

@main
struct RamonaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var debugInfoVisible = false
    @State private var quietModeEnabled = false
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    /// nil = autonomous behavior; a value pins that action (debug preview).
    @State private var forcedAction: CatAction? = nil

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
            Menu("Debug") {
                Text("Version \(AppVersion.current)")
                Divider()
                Toggle("Debug Info (HUD)", isOn: $debugInfoVisible)
                    .onChange(of: debugInfoVisible) { _, visible in
                        DebugSettings.shared.isVisible = visible
                    }
                Divider()
                Picker("Force Action", selection: $forcedAction) {
                    Text("Auto (behavior)").tag(CatAction?.none)
                    ForEach(CatAction.allCases, id: \.self) { action in
                        Text(action.debugName).tag(CatAction?.some(action))
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: forcedAction) { _, action in
                    appDelegate.forceAction(action)
                }
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
