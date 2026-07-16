import SwiftUI

struct LibrarySidebar: View {
    @EnvironmentObject private var library: MacroLibrary
    @Binding var search: String

    private var filtered: [MacroDocument] {
        search.isEmpty ? library.documents : library.documents.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keeper").font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                SymbolButton(symbol: "square.and.pencil", help: "New macro") { library.create() }
            }
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 9)

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                TextField("Search", text: $search).textFieldStyle(.plain).font(.system(size: 12))
            }
            .padding(.horizontal, 9).frame(height: 30)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 7))
            .padding(.horizontal, 10).padding(.bottom, 10)

            if filtered.isEmpty {
                Spacer()
                EmptyPlaceholder(symbol: "square.stack.3d.up", title: search.isEmpty ? "No macros yet" : "No results",
                                 message: search.isEmpty ? "Create one to begin recording." : "Try another search.")
                Spacer()
            } else {
                List(filtered, selection: $library.selection) { macro in
                    MacroRow(macro: macro).tag(macro.id)
                        .contextMenu {
                            Button("Duplicate") { library.duplicate(macro.id) }
                            Divider()
                            Button("Delete", role: .destructive) { library.delete(macro.id) }
                        }
                }
                .listStyle(.sidebar).scrollContentBackground(.hidden)
            }
        }
        .background(.regularMaterial)
    }
}

private struct MacroRow: View {
    let macro: MacroDocument
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: macro.schedule?.enabled == true ? "clock.badge.checkmark" : "command")
                .font(.system(size: 11, weight: .medium)).frame(width: 25, height: 25)
                .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(macro.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text("\(macro.steps.count) steps · \(macro.duration.formattedElapsed)")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 3)
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var library: MacroLibrary
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "command.square").font(.system(size: 38, weight: .ultraLight)).foregroundStyle(.secondary)
            VStack(spacing: 6) {
                Text("Automate the repetitive").font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("Record a workflow, refine each step, then run it whenever you need.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Button("Create your first macro") { library.create() }.buttonStyle(.borderedProminent).tint(.primary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.canvas)
    }
}
