import Foundation

/// One-time import of UserDefaults left behind under the app's former bundle identifiers.
/// The bundle id churned during early dev (com.wispervoice.app → …wisperflow01 → …02) and
/// each change silently orphaned history + settings in the old domain — the app looked
/// "suddenly reset". The id is permanently `com.wispervoice.dev` now; this pulls the
/// orphaned data forward exactly once. Requires no sandbox (we read foreign domains).
enum LegacyDefaults {
    private static let legacyDomains = [
        "com.wispervoice.app",
        "com.wispervoice.app.wisperflow01",
        "com.wispervoice.app.wisperflow02",
    ]
    /// Per-window/system state that must not follow the app across identities.
    private static let skippedPrefixes = ["NS", "com_apple", "Apple", "didMigrate"]

    static func migrateOnce() {
        let flag = "didMigrateLegacyDefaults"
        let std = UserDefaults.standard
        guard !std.bool(forKey: flag) else { return }
        for domain in legacyDomains {
            guard let keys = CFPreferencesCopyKeyList(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] else { continue }
            for key in keys where !skippedPrefixes.contains(where: key.hasPrefix) {
                guard let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString) else { continue }
                // Secrets go straight to the Keychain — writing the legacy API key back
                // into UserDefaults would recreate exactly the plaintext copy the
                // Keychain migration deletes.
                if key == "openAIKey" {
                    if let secret = value as? String, !secret.isEmpty, KeychainStore.get("openAIKey") == nil {
                        KeychainStore.set(secret, account: "openAIKey")
                    }
                    continue
                }
                // Existing values in the new domain always win — never clobber.
                guard std.object(forKey: key) == nil else { continue }
                std.set(value, forKey: key)
            }
        }
        std.set(true, forKey: flag)
    }
}

struct HistoryItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var text: String
    var date: Date
    var provider: String
    /// Recording length in seconds. Optional so history saved before this field decodes.
    var duration: TimeInterval? = nil
}

final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    @Published var items: [HistoryItem] = [] {
        didSet { save() }
    }

    private let key = "wisper.history"
    private init() {
        // HistoryStore can be touched before applicationDidFinishLaunching (scene setup),
        // so the migration is anchored here as well — migrateOnce() self-guards.
        LegacyDefaults.migrateOnce()
        load()
    }

    func add(_ text: String, duration: TimeInterval? = nil) {
        guard !text.isEmpty else { return }
        let item = HistoryItem(text: text, date: Date(), provider: UserDefaults.standard.string(forKey: "provider") ?? "", duration: duration)
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
