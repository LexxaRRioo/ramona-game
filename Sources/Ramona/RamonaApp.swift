import SwiftUI

@main
struct RamonaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var debugInfoVisible = false

    var body: some Scene {
        MenuBarExtra("Ramona", systemImage: "cat.fill") {
            Button("Feed") {
                appDelegate.feed()
            }
            Button("Offer Toy") {
                appDelegate.offerToy()
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
