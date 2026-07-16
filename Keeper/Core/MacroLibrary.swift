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
        documents.insert(document, at: 0)
        selection = document.id
        persist()
        return document.id
    }

    func update(_ id: UUID, _ transform: (inout MacroDocument) -> Void) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        transform(&documents[index])
        documents[index].modifiedAt = .now
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

    func markScheduleRun(_ id: UUID, at date: Date) {
        update(id) { $0.schedule?.lastRun = date }
    }

    private func load() {
        guard let data = try? Data(contentsOf: location),
              let saved = try? decoder.decode([MacroDocument].self, from: data) else { return }
        documents = saved
        selection = saved.first?.id
    }

    private func persist() {
        guard let data = try? encoder.encode(documents) else { return }
        try? data.write(to: location, options: .atomic)
    }
}
