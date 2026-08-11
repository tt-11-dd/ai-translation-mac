import Foundation

/// 翻译历史记录
struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let source: String
    let target: String
    let sourceLanguage: String
    let targetLanguage: String

    init(id: UUID = UUID(), timestamp: Date = Date(), source: String, target: String, sourceLanguage: String, targetLanguage: String) {
        self.id = id
        self.timestamp = timestamp
        self.source = source
        self.target = target
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

/// 历史记录存储：UserDefaults + JSON，最多保留 maxCount 条
@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var items: [HistoryItem] = []

    private let maxCount = 50
    private let key = "translationHistory"

    private init() {
        load()
    }

    func add(source: String, target: String, sourceLanguage: TranslateLanguage, targetLanguage: TranslateLanguage) {
        let item = HistoryItem(
            source: source,
            target: target,
            sourceLanguage: sourceLanguage.displayName,
            targetLanguage: targetLanguage.displayName
        )
        items.insert(item, at: 0)
        if items.count > maxCount {
            items = Array(items.prefix(maxCount))
        }
        save()
    }

    func remove(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return
        }
        items = decoded
    }
}
