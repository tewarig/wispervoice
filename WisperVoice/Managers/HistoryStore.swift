import Foundation

struct HistoryItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var date: Date
    var provider: String
}

final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    @Published var items: [HistoryItem] = [] {
        didSet { save() }
    }

    private let key = "wisper.history"
    private init() { load() }

    func add(_ text: String) {
        guard !text.isEmpty else { return }
        let item = HistoryItem(text: text, date: Date(), provider: UserDefaults.standard.string(forKey: "provider") ?? "")
        items.insert(item, at: 0)
        if items.count > 100 { items = Array(items.prefix(100)) }
    }

    func clear() { items.removeAll() }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    private func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded
        }
    }
}
