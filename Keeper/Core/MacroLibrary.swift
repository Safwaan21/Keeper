import Foundation

@MainActor
final class MacroLibrary: ObservableObject {
    @Published private(set) var documents: [MacroDocument] = []
    @Published var selection: UUID?

    private let location: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = support.appendingPathComponent("Keeper", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        location = folder.appendingPathComponent("Library.json")
        load()
    }

    var selected: MacroDocument? { documents.first { $0.id == selection } }

    @discardableResult
    func create() -> UUID {
        let number = documents.count + 1
        let document = MacroDocument(name: "New macro \(number)")
        documents.append(document)
        selection = document.id
        persist()
        return document.id
    }

    func update(_ id: UUID, _ transform: (inout MacroDocument) -> Void) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        let previousName = documents[index].name
        transform(&documents[index])
        documents[index].modifiedAt = .now
        if documents[index].name != previousName {
            let newName = documents[index].name
            for documentIndex in documents.indices {
                for stepIndex in documents[documentIndex].steps.indices
                where documents[documentIndex].steps[stepIndex].referencedMacroID == id {
                    documents[documentIndex].steps[stepIndex].referencedMacroName = newName
                }
            }
        }
        persist()
    }

    func delete(_ id: UUID) {
        documents.removeAll { $0.id == id }
        if selection == id { selection = documents.first?.id }
        persist()
    }

    func duplicate(_ id: UUID) {
        guard var copy = documents.first(where: { $0.id == id }) else { return }
        copy.id = UUID(); copy.name += " copy"; copy.createdAt = .now; copy.modifiedAt = .now
        copy.schedule = nil
        documents.insert(copy, at: 0)
        selection = copy.id
        persist()
    }

    func canNest(_ childID: UUID, inside parentID: UUID) -> Bool {
        guard childID != parentID else { return false }
        return !references(childID, target: parentID, visited: [])
    }

    func nest(_ childID: UUID, inside parentID: UUID) {
        guard canNest(childID, inside: parentID),
              let child = documents.first(where: { $0.id == childID }) else { return }
        update(parentID) { macro in
            macro.steps.append(MacroStep(offset: macro.duration + 0.1, kind: .macro,
                                         referencedMacroID: child.id, referencedMacroName: child.name))
        }
    }

    func deleteBlock(_ blockID: UUID, from macroID: UUID) {
        update(macroID) { macro in
            guard let block = macro.blocks.first(where: { $0.id == blockID }) else { return }
            let ids = Set(block.steps.map(\.id))
            macro.steps.removeAll { ids.contains($0.id) }
            macro.steps = Self.retimed(macro.blocks)
        }
    }

    func insertBlocks(_ inserted: [ActionBlock], after targetID: UUID?, in macroID: UUID) {
        let allowed = inserted.filter { block in
            guard case let .macro(childID) = block.family, let childID else { return true }
            return canNest(childID, inside: macroID)
        }
        guard !allowed.isEmpty else { return }
        update(macroID) { macro in
            var blocks = macro.blocks
            let fresh = allowed.map { block in
                ActionBlock(family: block.family, steps: block.steps.map { step in
                    var copy = step; copy.id = UUID(); return copy
                })
            }
            let index = targetID.flatMap { id in blocks.firstIndex(where: { $0.id == id }).map { $0 + 1 } } ?? blocks.count
            blocks.insert(contentsOf: fresh, at: min(index, blocks.count))
            macro.steps = Self.retimed(blocks)
        }
    }

    func moveBlock(_ sourceID: UUID, before targetID: UUID, in macroID: UUID) {
        guard sourceID != targetID else { return }
        update(macroID) { macro in
            var blocks = macro.blocks
            guard let sourceIndex = blocks.firstIndex(where: { $0.id == sourceID }),
                  let targetIndex = blocks.firstIndex(where: { $0.id == targetID }) else { return }
            let moved = blocks.remove(at: sourceIndex)
            let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
            blocks.insert(moved, at: adjustedTarget)
            macro.steps = Self.retimed(blocks)
        }
    }

    func markScheduleRun(_ id: UUID, at date: Date) {
        update(id) { $0.schedule?.lastRun = date }
    }

    private func load() {
        guard let data = try? Data(contentsOf: location),
              let saved = try? decoder.decode([MacroDocument].self, from: data) else { return }
        documents = saved
        // Remove a back-edge from any invalid graph loaded from an external or older file.
        for index in documents.indices {
            let parentID = documents[index].id
            documents[index].steps.removeAll { step in
                guard step.kind == .macro, let childID = step.referencedMacroID else { return false }
                return !canNest(childID, inside: parentID)
            }
        }
        selection = saved.first?.id
    }

    private func references(_ source: UUID, target: UUID, visited: Set<UUID>) -> Bool {
        guard !visited.contains(source), let document = documents.first(where: { $0.id == source }) else { return false }
        var nextVisited = visited; nextVisited.insert(source)
        for child in document.steps.compactMap(\.referencedMacroID) {
            if child == target || references(child, target: target, visited: nextVisited) { return true }
        }
        return false
    }

    private static func retimed(_ blocks: [ActionBlock]) -> [MacroStep] {
        var cursor: TimeInterval = 0
        return blocks.flatMap { block -> [MacroStep] in
            let origin = block.start
            let adjusted = block.steps.map { step -> MacroStep in
                var copy = step; copy.offset = cursor + max(0, step.offset - origin); return copy
            }
            cursor += max(block.duration, 0.02) + 0.08
            return adjusted
        }
    }

    private func persist() {
        guard let data = try? encoder.encode(documents) else { return }
        try? data.write(to: location, options: .atomic)
    }
}
