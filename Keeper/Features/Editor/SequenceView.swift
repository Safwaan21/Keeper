import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SequenceView: View {
    @EnvironmentObject private var library: MacroLibrary
    @EnvironmentObject private var player: MacroPlayer
    let macro: MacroDocument
    @Binding var selectedStep: UUID?
    @State private var expanded: Set<UUID> = []
    @State private var draggedBlock: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.55)
            if macro.blocks.isEmpty {
                EmptyPlaceholder(symbol: "square.stack.3d.up", title: "No blocks yet",
                    message: "Record a workflow or add another macro. Consecutive actions are grouped automatically.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(macro.blocks.enumerated()), id: \.element.id) { index, block in
                                BlockView(index: index + 1, block: block,
                                    isExpanded: expanded.contains(block.id), selectedStep: $selectedStep,
                                    playingStep: player.currentStep,
                                    toggle: { toggle(block.id) })
                                .id(block.id)
                                .onDrag {
                                    draggedBlock = block.id
                                    return NSItemProvider(object: block.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: BlockDropDelegate(
                                    target: block.id, dragged: $draggedBlock,
                                    move: { library.moveBlock($0, before: $1, in: macro.id) }
                                ))
                                .contextMenu { blockMenu(block) }
                            }
                        }.padding(12)
                    }
                    .onChange(of: player.currentStep) { _, id in
                        guard let id, let block = macro.blocks.first(where: { $0.steps.contains { $0.id == id } }) else { return }
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(block.id, anchor: .center) }
                    }
                }
            }
        }.background(Theme.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField("Macro name", text: Binding(get: { macro.name }, set: { value in library.update(macro.id) { $0.name = value } }))
                    .textFieldStyle(.plain).font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
                Menu {
                    let candidates = library.documents.filter { library.canNest($0.id, inside: macro.id) }
                    if candidates.isEmpty { Text("No macros available") }
                    ForEach(candidates) { candidate in
                        Button(candidate.name) { library.nest(candidate.id, inside: macro.id) }
                    }
                } label: {
                    Label("Add macro", systemImage: "plus").font(.system(size: 11, weight: .medium))
                }.menuStyle(.borderlessButton).fixedSize()
                Text("\(macro.blocks.count) blocks").font(.system(size: 11)).foregroundStyle(.secondary)
                Text(macro.duration.formattedElapsed).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            if player.isPlaying { ProgressView(value: player.progress).progressViewStyle(.linear).tint(.primary) }
        }.padding(.horizontal, 18).padding(.top, 17).padding(.bottom, 14)
    }

    @ViewBuilder private func blockMenu(_ block: ActionBlock) -> some View {
        Button("Copy Block") { BlockClipboard.copy([block]) }
        Button("Paste After") { if let blocks = BlockClipboard.read() { library.insertBlocks(blocks, after: block.id, in: macro.id) } }
            .disabled(!BlockClipboard.hasBlocks)
        Button("Duplicate") { library.insertBlocks([block], after: block.id, in: macro.id) }
        Divider()
        Button("Delete Block", role: .destructive) {
            library.deleteBlock(block.id, from: macro.id)
            if block.steps.contains(where: { $0.id == selectedStep }) { selectedStep = nil }
        }
    }

    private func toggle(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.16)) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
    }
}

private struct BlockView: View {
    let index: Int
    let block: ActionBlock
    let isExpanded: Bool
    @Binding var selectedStep: UUID?
    let playingStep: UUID?
    let toggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "line.3.horizontal").font(.system(size: 10, weight: .semibold)).foregroundStyle(.quaternary)
                Image(systemName: block.family.symbol).font(.system(size: 12, weight: .medium)).frame(width: 30, height: 30)
                    .background(isPlaying ? Color.primary : Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(isPlaying ? Theme.canvas : .primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(blockTitle).font(.system(size: 12, weight: .semibold))
                    Text(blockSubtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(block.start.formattedElapsed).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                Button(action: toggle) {
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).rotationEffect(.degrees(isExpanded ? 90 : 0)).frame(width: 22, height: 22)
                }.buttonStyle(.plain).opacity(block.steps.count > 1 ? 1 : 0.35)
            }.padding(.horizontal, 11).frame(height: 54).contentShape(Rectangle()).onTapGesture(perform: toggle)

            if isExpanded {
                Divider().padding(.leading, 52).opacity(0.5)
                VStack(spacing: 0) {
                    ForEach(Array(block.steps.enumerated()), id: \.element.id) { index, step in
                        StepRow(index: index + 1, step: step, selected: selectedStep == step.id, playing: playingStep == step.id)
                            .onTapGesture { selectedStep = step.id }
                    }
                }.padding(.vertical, 5)
            }
        }
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(isPlaying ? Color.primary.opacity(0.25) : Theme.line))
    }

    private var isPlaying: Bool { block.steps.contains { $0.id == playingStep } }
    private var blockTitle: String {
        if case .macro = block.family { return block.steps.first?.referencedMacroName ?? "Missing macro" }
        return block.family.title
    }
    private var blockSubtitle: String {
        if case .macro = block.family { return "Nested macro" }
        return "\(block.steps.count) \(block.steps.count == 1 ? "action" : "actions") · \(block.duration.formattedElapsed)"
    }
}

private struct StepRow: View {
    let index: Int, step: MacroStep
    let selected: Bool, playing: Bool
    var body: some View {
        HStack(spacing: 10) {
            Text(String(format: "%02d", index)).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 24)
            Image(systemName: step.kind.symbol).font(.system(size: 10)).frame(width: 22)
            Text(step.kind.title).font(.system(size: 11, weight: .medium))
            Text(step.detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            Text(step.offset.formattedElapsed).font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
        }.padding(.horizontal, 12).frame(height: 34)
            .background(selected || playing ? Color.primary.opacity(0.065) : .clear)
            .contentShape(Rectangle())
    }
}

private struct BlockDropDelegate: DropDelegate {
    let target: UUID
    @Binding var dragged: UUID?
    let move: (UUID, UUID) -> Void
    func dropEntered(info: DropInfo) { if let dragged, dragged != target { move(dragged, target) } }
    func performDrop(info: DropInfo) -> Bool { dragged = nil; return true }
}

private enum BlockClipboard {
    private static let type = NSPasteboard.PasteboardType("com.keeper.action-blocks")
    static var hasBlocks: Bool { NSPasteboard.general.availableType(from: [type]) != nil }
    static func copy(_ blocks: [ActionBlock]) {
        let steps = blocks.map(\.steps)
        guard let data = try? JSONEncoder().encode(steps) else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setData(data, forType: type)
    }
    static func read() -> [ActionBlock]? {
        guard let data = NSPasteboard.general.data(forType: type),
              let groups = try? JSONDecoder().decode([[MacroStep]].self, from: data) else { return nil }
        return groups.compactMap { steps in steps.first.map { ActionBlock(family: $0.blockFamily, steps: steps) } }
    }
}
