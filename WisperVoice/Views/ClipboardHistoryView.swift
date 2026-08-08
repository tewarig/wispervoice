import SwiftUI

/// History — every dictation, searchable. Actions sit on each row and stay quiet until
/// hover, so a long list reads as text rather than a wall of buttons.
struct ClipboardHistoryView: View {
    @ObservedObject var store = HistoryStore.shared
    @State private var search = ""
    @State private var copiedId: UUID?
    @State private var hoveredId: UUID?

    var filtered: [HistoryItem] {
        if search.isEmpty { return store.items }
        return store.items.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        Pane(title: "History", subtitle: "Everything you have dictated, newest first.") {
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(.secondary)
                    TextField("Search dictations", text: $search)
                        .textFieldStyle(.plain)
                    if !search.isEmpty {
                        Button { search = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 11).padding(.vertical, 8)
                .background(Theme.wellFill, in: RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous).stroke(Theme.border, lineWidth: 1))

                Text("\(filtered.count)")
                    .font(Theme.numeral).foregroundStyle(.secondary)
                    .contentTransition(.numericText())

                Button("Clear all", role: .destructive) { withAnimation { store.clear() } }
                    .buttonStyle(.bordered)
                    .disabled(store.items.isEmpty)
            }

            if filtered.isEmpty {
                Card(padding: 40) {
                    VStack(spacing: 10) {
                        Image(systemName: search.isEmpty ? "waveform" : "magnifyingglass")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(.secondary)
                        Text(search.isEmpty ? "No dictations yet" : "No matches")
                            .font(.system(size: 15, weight: .semibold))
                        Text(search.isEmpty
                             ? "Press \(HotkeyManager.currentPreset.label) anywhere to start."
                             : "Try a different search.")
                            .font(Theme.rowMeta).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                            if index > 0 { RowDivider() }
                            historyRow(item)
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ item: HistoryItem) -> some View {
        let isHovered = hoveredId == item.id
        return HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.text)
                    .font(.system(size: 13))
                    .lineSpacing(2)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 7) {
                    Text(item.date, style: .relative).font(Theme.numeral)
                    if !item.provider.isEmpty {
                        Text("·").font(Theme.numeral)
                        Text(item.provider).font(Theme.numeral).lineLimit(1)
                    }
                }
                .foregroundStyle(.tertiary)
            }

            HStack(spacing: 8) {
                Button(copiedId == item.id ? "Copied" : "Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.text, forType: .string)
                    withAnimation { copiedId = item.id }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { withAnimation { copiedId = nil } }
                }
                .buttonStyle(.bordered)
                .contentTransition(.numericText())
                // No "Paste" here: while browsing history, WisperVoice itself is the
                // focused app, so there is no sensible external cursor to paste into.
                // Dictation inserts at the cursor by default; history is for retrieval.

                Button {
                    withAnimation { store.items.removeAll { $0.id == item.id } }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Delete")
            }
            // Actions stay legible but recede until the row is hovered.
            .opacity(isHovered || copiedId == item.id ? 1 : 0.45)
            .animation(.easeOut(duration: 0.12), value: isHovered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(isHovered ? Color.primary.opacity(0.03) : .clear)
        .onHover { hoveredId = $0 ? item.id : (hoveredId == item.id ? nil : hoveredId) }
    }
}
