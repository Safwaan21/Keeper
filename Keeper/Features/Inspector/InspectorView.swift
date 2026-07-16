import SwiftUI

struct InspectorView: View {
    @EnvironmentObject private var library: MacroLibrary
    @EnvironmentObject private var permissions: Permissions
    let macro: MacroDocument?
    let selectedStep: UUID?

    private var step: MacroStep? { macro?.steps.first { $0.id == selectedStep } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(step == nil ? "Macro" : "Step").font(.system(size: 13, weight: .semibold)).padding(16)
            Divider().opacity(0.55)
            if let macro {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let step { StepInspector(macroID: macro.id, step: step) }
                        else { MacroInspector(macro: macro) }
                        permissionSection
                    }.padding(16)
                }
            } else {
                Text("Select a macro to inspect it.").font(.system(size: 11)).foregroundStyle(.secondary).padding(16)
            }
        }.background(Theme.panel)
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            InspectorLabel("System access")
            HStack {
                Circle().fill(permissions.accessibility ? Color.green : Theme.recording).frame(width: 6, height: 6)
                Text(permissions.accessibility ? "Accessibility enabled" : "Accessibility required").font(.system(size: 11))
                Spacer()
            }
            if !permissions.accessibility {
                Button("Open System Settings") { permissions.openSettings() }.font(.system(size: 11)).buttonStyle(.link)
            }
        }
    }
}

private struct MacroInspector: View {
    @EnvironmentObject private var library: MacroLibrary
    let macro: MacroDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                InspectorLabel("Playback")
                HStack {
                    Text("Speed").font(.system(size: 11)); Spacer()
                    Picker("", selection: Binding(get: { macro.playbackRate }, set: { rate in library.update(macro.id) { $0.playbackRate = rate } })) {
                        Text("0.5×").tag(0.5); Text("1×").tag(1.0); Text("1.5×").tag(1.5); Text("2×").tag(2.0)
                    }.labelsHidden().frame(width: 86).controlSize(.small)
                }
            }
            ScheduleEditor(macro: macro)
            VStack(alignment: .leading, spacing: 8) {
                InspectorLabel("Details")
                MetadataRow(label: "Created", value: macro.createdAt.formatted(date: .abbreviated, time: .omitted))
                MetadataRow(label: "Duration", value: macro.duration.formattedElapsed)
                MetadataRow(label: "Actions", value: "\(macro.steps.count)")
            }
        }
    }
}

private struct ScheduleEditor: View {
    @EnvironmentObject private var library: MacroLibrary
    let macro: MacroDocument
    private var enabled: Binding<Bool> { Binding(
        get: { macro.schedule?.enabled ?? false },
        set: { value in library.update(macro.id) { doc in
            if doc.schedule == nil { doc.schedule = RunSchedule() }
            doc.schedule?.enabled = value
        }}
    )}
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InspectorLabel("Schedule")
            Toggle("Run automatically", isOn: enabled).font(.system(size: 11)).toggleStyle(.switch).controlSize(.mini)
            if macro.schedule?.enabled == true {
                DatePicker("Time", selection: Binding(
                    get: { macro.schedule?.time ?? .now },
                    set: { date in library.update(macro.id) { $0.schedule?.time = date } }
                ), displayedComponents: .hourAndMinute).font(.system(size: 11)).controlSize(.small)
                Text("Runs while Keeper is open.").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
    }
}

private struct StepInspector: View {
    @EnvironmentObject private var library: MacroLibrary
    let macroID: UUID
    let step: MacroStep
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                InspectorLabel("Action")
                Label(step.kind.title, systemImage: step.kind.symbol).font(.system(size: 12, weight: .medium))
                Text(step.detail).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                InspectorLabel("Timing")
                HStack {
                    Text("Offset").font(.system(size: 11)); Spacer()
                    OffsetEditor(value: step.offset) { value in
                        update { $0.offset = value }
                    }
                    .id(step.id)
                    Text("s").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            if let x = step.pointX, let y = step.pointY {
                VStack(alignment: .leading, spacing: 8) {
                    InspectorLabel("Position")
                    MetadataRow(label: "X", value: "\(Int(x))")
                    MetadataRow(label: "Y", value: "\(Int(y))")
                }
            }
        }
    }
    private func update(_ transform: (inout MacroStep) -> Void) {
        library.update(macroID) { macro in
            guard let index = macro.steps.firstIndex(where: { $0.id == step.id }) else { return }
            transform(&macro.steps[index]); macro.steps.sort { $0.offset < $1.offset }
        }
    }
}

private struct OffsetEditor: View {
    let value: TimeInterval
    let commit: (TimeInterval) -> Void
    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(value: TimeInterval, commit: @escaping (TimeInterval) -> Void) {
        self.value = value
        self.commit = commit
        _draft = State(initialValue: String(format: "%.2f", value))
    }

    var body: some View {
        TextField("Seconds", text: $draft)
            .textFieldStyle(.roundedBorder)
            .frame(width: 72)
            .multilineTextAlignment(.trailing)
            .font(.system(size: 11, design: .monospaced))
            .focused($isFocused)
            .onSubmit {
                commitDraft()
                isFocused = false
            }
            .onExitCommand {
                draft = String(format: "%.2f", value)
                isFocused = false
            }
            .onChange(of: isFocused) { wasFocused, focused in
                if wasFocused && !focused { commitDraft() }
            }
            .onChange(of: value) { _, newValue in
                if !isFocused { draft = String(format: "%.2f", newValue) }
            }
    }

    private func commitDraft() {
        let normalized = draft.replacingOccurrences(of: ",", with: ".")
        guard let number = Double(normalized), number.isFinite else {
            draft = String(format: "%.2f", value)
            return
        }
        let clamped = max(0, number)
        draft = String(format: "%.2f", clamped)
        if clamped != value { commit(clamped) }
    }
}

private struct InspectorLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(0.7).foregroundStyle(.tertiary) }
}

private struct MetadataRow: View {
    let label: String, value: String
    var body: some View { HStack { Text(label).foregroundStyle(.secondary); Spacer(); Text(value) }.font(.system(size: 11)) }
}
