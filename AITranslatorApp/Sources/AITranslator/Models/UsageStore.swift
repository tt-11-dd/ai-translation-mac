import Foundation

/// 用量统计：按月份累计翻译字符数与请求次数
@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore()

    struct MonthUsage: Codable {
        var key: String          // "2026-08"
        var characterCount: Int  // 输入字符数（近似 = 消耗）
        var requestCount: Int
    }

    @Published private(set) var usages: [MonthUsage] = []

    private let storageKey = "usageRecords"

    private init() {
        load()
    }

    var currentMonthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }

    /// 当前月用量
    var currentUsage: MonthUsage {
        usages.first(where: { $0.key == currentMonthKey })
            ?? MonthUsage(key: currentMonthKey, characterCount: 0, requestCount: 0)
    }

    /// 累计字符数
    var totalCharacters: Int {
        usages.reduce(0) { $0 + $1.characterCount }
    }

    /// 累计请求次数
    var totalRequests: Int {
        usages.reduce(0) { $0 + $1.requestCount }
    }

    /// 记录一次翻译请求：输入字符数 + 请求数 +1
    func record(characters: Int) {
        var list = usages
        let key = currentMonthKey
        if let index = list.firstIndex(where: { $0.key == key }) {
            list[index].characterCount += characters
            list[index].requestCount += 1
        } else {
            list.insert(MonthUsage(key: key, characterCount: characters, requestCount: 1), at: 0)
        }
        // 只保留最近 24 个月，避免无限膨胀
        if list.count > 24 {
            list = Array(list.prefix(24))
        }
        usages = list
        save()
    }

    func reset() {
        usages.removeAll()
        save()
    }

    /// 格式化为人类可读："12,345"
    static func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(usages) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MonthUsage].self, from: data) else {
            return
        }
        usages = decoded
    }
}
