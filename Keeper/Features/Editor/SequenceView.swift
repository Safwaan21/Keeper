import SwiftUI

struct SequenceView: View {
    @EnvironmentObject private var library: MacroLibrary
    @EnvironmentObject private var player: MacroPlayer
    let macro: MacroDocument
    @Binding var selectedStep: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)
            if macro.steps.isEmpty {
                EmptyPlaceholder(symbol: "waveform.path", title: "Nothing recorded",
                    message: "Choose Record in the toolbar. Keeper will place every captured action here in order.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(macro.steps.enumerated()), id: \.element.id) { index, step in
                                StepRow(index: index + 1, step: step, selected: selectedStep == step.id,
                                        playing: player.currentStep == step.id)
                                    .id(step.id)
                                    .onTapGesture { selectedStep = step.id }
                                    .contextMenu {
                                        Button("Delete") { delete(step.id) }
                                    }
                            }
                        }.padding(10)
                    }
                    .onChange(of: player.currentStep) { _, id in
                        if let id { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
        }.background(Theme.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                TextField("Macro name", text: Binding(
                    get: { macro.name },
                    set: { value in library.update(macro.id) { $0.name = value } }
                ))
                .textFieldStyle(.plain).font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(macro.steps.count) steps").font(.system(size: 11)).foregroundStyle(.secondary)
                Text(macro.duration.formattedElapsed).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            if player.isPlaying {
                ProgressView(value: player.progress).progressViewStyle(.linear).tint(.primary)
            }
        }.padding(.horizontal, 18).padding(.top, 17).padding(.bottom, 14)
    }

    private func delete(_ id: UUID) {
        library.update(macro.id) { $0.steps.removeAll { $0.id == id } }
        if selectedStep == id { selectedStep = nil }
    }
}

private struct StepRow: View {
    let index: Int
    let step: MacroStep
    let selected: Bool
    let playing: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(String(format: "%02d", index)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 24)
            Image(systemName: step.kind.symbol).font(.system(size: 11, weight: .medium)).frame(width: 28, height: 28)
                .background(playing ? Color.primary : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(playing ? Theme.canvas : .primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.kind.title).font(.system(size: 12, weight: .medium))
                Text(step.detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(step.offset.formattedElapsed).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 9).frame(height: 48)
        .background(selected ? Color.primary.opacity(0.075) : .clear, in: RoundedRectangle(cornerRadius: 9))
        .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}
