import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var entries: [TranslationResult] = []

    private let defaults: UserDefaults
    private let key = "translationHistory"
    private let limit = 20

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ result: TranslationResult, enabled: Bool) {
        guard enabled else { return }
        entries.insert(result, at: 0)
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
        }
        save()
    }

    func clear() {
        entries.removeAll()
        defaults.removeObject(forKey: key)
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TranslationResult].self, from: data) else {
            entries = []
            return
        }
        entries = Array(decoded.prefix(limit))
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }
}
