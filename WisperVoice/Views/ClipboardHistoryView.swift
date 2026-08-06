import SwiftUI

struct ClipboardHistoryView: View {
    @ObservedObject var store = HistoryStore.shared
    @State private var search = ""
    @State private var copiedId: UUID?

    var filtered: [HistoryItem] {
        if search.isEmpty { return store.items }
        return store.items.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if filtered.isEmpty {
                ContentUnavailableView(search.isEmpty ? "No history yet" : "No matches", systemImage: "clock.arrow.circlepath", description: Text(search.isEmpty ? "Dictate to build history." : "Try another search."))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.text).font(Theme.transcript).lineSpacing(2).textSelection(.enabled)
                            HStack(spacing: 8) {
                                Text(item.date, style: .relative).font(.caption2).foregroundStyle(.tertiary)
                                if !item.provider.isEmpty { Text("• \(item.provider)").font(.caption2).foregroundStyle(.tertiary).lineLimit(1) }
                                Spacer()
                                Button(copiedId == item.id ? "Copied!" : "Copy") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.text, forType: .string)
                                    withAnimation { copiedId = item.id }
                                    DispatchQueue.main.asyncAfter(deadline: .now()+1.2){ withAnimation { copiedId = nil } }
                                }.buttonStyle(.bordered).controlSize(.mini).tint(Theme.accent)
                                Button("Paste") { TextInjector.inject(text: item.text) }.buttonStyle(.borderedProminent).controlSize(.mini)
                            }
                        }
                        .padding(.vertical, 6)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { withAnimation { if let idx = store.items.firstIndex(where: { $0.id == item.id }) { store.items.remove(at: idx) } } } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 520, minHeight: 380)
        .background(.ultraThinMaterial)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear All", role: .destructive) { withAnimation { store.clear() } }.disabled(store.items.isEmpty)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            TextField("Search history…", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 260)
            if !search.isEmpty { Button("Clear") { search = "" }.buttonStyle(.borderless).font(.caption) }
            Spacer()
            Text("\(filtered.count) items").font(.caption).foregroundStyle(.secondary)
        }
        .padding(10).background(.bar)
    }
}
