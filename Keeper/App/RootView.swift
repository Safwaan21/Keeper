import SwiftUI

struct RootView: View {
    @EnvironmentObject private var library: MacroLibrary
    @EnvironmentObject private var permissions: Permissions
    @State private var selectedStep: UUID?
    @State private var search = ""

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(search: $search)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 270)
        } content: {
            Group {
                if let macro = library.selected {
                    SequenceView(macro: macro, selectedStep: $selectedStep)
                } else {
                    WelcomeView()
                }
            }
            .navigationSplitViewColumnWidth(min: 480, ideal: 620)
        } detail: {
            InspectorView(macro: library.selected, selectedStep: selectedStep)
                .navigationSplitViewColumnWidth(min: 240, ideal: 270, max: 320)
        }
        .background(Theme.canvas)
        .toolbar { permissionToolbar }
        .onChange(of: library.selection) { _, _ in
            selectedStep = nil
        }
    }

    @ToolbarContentBuilder private var permissionToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if !permissions.accessibility {
                Button("Enable Access") { permissions.request() }
                    .font(.system(size: 11, weight: .medium)).buttonStyle(.bordered).controlSize(.small)
                    .help("Keeper needs Accessibility permission to record and replay input")
            }
        }
    }
}
