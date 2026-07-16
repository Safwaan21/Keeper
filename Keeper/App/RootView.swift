import SwiftUI

struct RootView: View {
    @EnvironmentObject private var library: MacroLibrary
    @EnvironmentObject private var recorder: MacroRecorder
    @EnvironmentObject private var player: MacroPlayer
    @EnvironmentObject private var permissions: Permissions
    @State private var selectedStep: UUID?
    @State private var showCapture = false
    @State private var capture = CaptureSettings()
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
        .toolbar { transport }
        .onChange(of: library.selection) { _, _ in
            selectedStep = nil
            capture = library.selected?.settings ?? CaptureSettings()
        }
    }

    @ToolbarContentBuilder private var transport: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 7) {
                if recorder.isRecording {
                    Button(action: finishRecording) {
                        HStack(spacing: 7) {
                            Circle().fill(Theme.recording).frame(width: 7, height: 7)
                            Text(recorder.elapsed.formattedElapsed).monospacedDigit()
                            Text("Stop").fontWeight(.medium)
                        }
                        .font(.system(size: 12)).padding(.horizontal, 12).frame(height: 30)
                        .background(Theme.recording.opacity(0.1), in: Capsule()).foregroundStyle(Theme.recording)
                    }.buttonStyle(.plain).keyboardShortcut(".", modifiers: [.command])
                } else {
                    Button { showCapture.toggle() } label: {
                        Label("Record", systemImage: "record.circle").font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 11).frame(height: 30)
                            .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain).disabled(library.selected == nil || player.isPlaying)
                    .popover(isPresented: $showCapture, arrowEdge: .bottom) {
                        CapturePopover(settings: $capture, start: beginRecording)
                    }
                }

                Button {
                    guard let macro = library.selected else { return }
                    player.isPlaying ? player.stop() : player.play(macro, library: library)
                } label: {
                    Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold)).frame(width: 30, height: 30)
                        .background(Color.primary, in: Circle()).foregroundStyle(Theme.canvas)
                }
                .buttonStyle(.plain)
                .disabled(library.selected?.steps.isEmpty != false || recorder.isRecording || !permissions.accessibility)
                .help(player.isPlaying ? "Stop" : "Run macro")
            }
        }
        ToolbarItem(placement: .primaryAction) {
            if !permissions.accessibility {
                Button("Enable Access") { permissions.request() }
                    .font(.system(size: 11, weight: .medium)).buttonStyle(.bordered).controlSize(.small)
                    .help("Keeper needs Accessibility permission to record and replay input")
            }
        }
    }

    private func beginRecording() {
        guard permissions.accessibility else { permissions.request(); return }
        guard recorder.start(settings: capture) else { return }
        showCapture = false
    }

    private func finishRecording() {
        let steps = recorder.stop()
        guard let id = library.selection else { return }
        library.update(id) { $0.steps = steps; $0.settings = capture }
    }
}
