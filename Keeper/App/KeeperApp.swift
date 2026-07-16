import SwiftUI

@main
struct KeeperApp: App {
    @StateObject private var library = MacroLibrary()
    @StateObject private var recorder = MacroRecorder()
    @StateObject private var player = MacroPlayer()
    @StateObject private var permissions = Permissions()
    @StateObject private var settings = KeeperSettings()
    @StateObject private var scheduler = MacroScheduler()

    var body: some Scene {
        WindowGroup("Keeper", id: "main") {
            RootView()
                .environmentObject(library)
                .environmentObject(recorder)
                .environmentObject(player)
                .environmentObject(permissions)
                .environmentObject(settings)
                .environmentObject(scheduler)
                .task { scheduler.start(library: library, player: player, settings: settings) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Macro") { library.create() }.keyboardShortcut("n")
            }
        }

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(scheduler)
        }

        MenuBarExtra("Keeper", systemImage: scheduler.isPaused ? "pause.circle" : "command.square") {
            MenuBarView()
                .environmentObject(scheduler)
                .environmentObject(settings)
        }
    }
}
