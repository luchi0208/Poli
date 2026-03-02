import Foundation

@MainActor
final class UsageTracker {
    static let shared = UsageTracker()

    private static let totalCountKey = "usageTotalCount"
    private static let dailyCountKey = "usageDailyCount"
    private static let dailyDateKey = "usageDailyDate"

    private init() {
        resetDailyIfNeeded()
    }

    var totalCount: Int {
        UserDefaults.standard.integer(forKey: Self.totalCountKey)
    }

    var dailyCount: Int {
        resetDailyIfNeeded()
        return UserDefaults.standard.integer(forKey: Self.dailyCountKey)
    }

    func recordUsage() {
        resetDailyIfNeeded()
        UserDefaults.standard.set(totalCount + 1, forKey: Self.totalCountKey)
        UserDefaults.standard.set(dailyCount + 1, forKey: Self.dailyCountKey)
    }

    private func resetDailyIfNeeded() {
        let today = dateString(from: Date())
        let stored = UserDefaults.standard.string(forKey: Self.dailyDateKey) ?? ""
        if stored != today {
            UserDefaults.standard.set(0, forKey: Self.dailyCountKey)
            UserDefaults.standard.set(today, forKey: Self.dailyDateKey)
        }
    }

    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
