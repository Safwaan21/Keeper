import SwiftUI

@main
struct KeeperApp: App {
    @StateObject private var library = MacroLibrary()
    @StateObject private var recorder = MacroRecorder()
    @StateObject private var player = MacroPlayer()
    @StateObject private var permissions = Permissions()
    private let scheduler = MacroScheduler()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(library)
                .environmentObject(recorder)
                .environmentObject(player)
                .environmentObject(permissions)
                .task { scheduler.start(library: library, player: player) }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Macro") { library.create() }.keyboardShortcut("n")
            }
        }
    }
}
