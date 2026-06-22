import Foundation
import SwiftData

// MARK: - SwiftData Models

@Model
final class DayLog {
    var id: UUID
    var date: Date
    var spent: Double
    var capAmount: Double
    var underCap: Bool

    init(id: UUID = UUID(), date: Date = .now, spent: Double, capAmount: Double) {
        self.id = id
        self.date = date
        self.spent = spent
        self.capAmount = capAmount
        self.underCap = spent <= capAmount
    }
}

@Model
final class CapPlan {
    var id: UUID
    var dailyCap: Double
    var effectiveFrom: Date

    init(id: UUID = UUID(), dailyCap: Double, effectiveFrom: Date = .now) {
        self.id = id
        self.dailyCap = dailyCap
        self.effectiveFrom = effectiveFrom
    }
}

@Model
final class StreakState {
    var id: UUID
    var currentStreak: Int
    var longestStreak: Int
    var lastCheckIn: Date?

    init(id: UUID = UUID(), currentStreak: Int = 0, longestStreak: Int = 0, lastCheckIn: Date? = nil) {
        self.id = id
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.lastCheckIn = lastCheckIn
    }
}

// MARK: - AppModel

@MainActor
final class AppModel: ObservableObject {
    let container: ModelContainer
    weak var store: Store?

    @Published private(set) var allLogs: [DayLog] = []
    @Published private(set) var todayLog: DayLog? = nil
    @Published private(set) var streak: StreakState = StreakState()
    @Published private(set) var activeCap: Double = 50.0

    init(container: ModelContainer) {
        self.container = container
        reload()
    }

    static func makeContainer() -> ModelContainer {
        let schema = Schema([DayLog.self, CapPlan.self, StreakState.self])
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    func reload() {
        let ctx = container.mainContext

        // Fetch logs sorted newest first
        let logDescriptor = FetchDescriptor<DayLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        allLogs = (try? ctx.fetch(logDescriptor)) ?? []
        todayLog = allLogs.first(where: { Calendar.current.isDateInToday($0.date) })

        // Fetch active cap (most recent)
        let capDescriptor = FetchDescriptor<CapPlan>(
            sortBy: [SortDescriptor(\.effectiveFrom, order: .reverse)]
        )
        let caps = (try? ctx.fetch(capDescriptor)) ?? []
        activeCap = caps.first?.dailyCap ?? 50.0

        // Fetch streak state
        let streakDescriptor = FetchDescriptor<StreakState>()
        let streaks = (try? ctx.fetch(streakDescriptor)) ?? []
        streak = streaks.first ?? StreakState()
    }

    func refresh() { reload() }

    // MARK: - Set daily cap
    func setDailyCap(_ amount: Double) {
        let ctx = container.mainContext
        let plan = CapPlan(dailyCap: amount, effectiveFrom: .now)
        ctx.insert(plan)
        try? ctx.save()
        reload()
    }

    // MARK: - Log today's spend
    func logSpend(_ amount: Double) {
        let ctx = container.mainContext
        let cap = activeCap

        if let existing = todayLog {
            existing.spent = amount
            existing.capAmount = cap
            existing.underCap = amount <= cap
        } else {
            let log = DayLog(spent: amount, capAmount: cap)
            ctx.insert(log)
        }
        try? ctx.save()
        updateStreak()
        reload()
    }

    // MARK: - Streak update
    private func updateStreak() {
        let ctx = container.mainContext

        // Recompute streak from sorted logs
        let descriptor = FetchDescriptor<DayLog>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let logs = (try? ctx.fetch(descriptor)) ?? []

        var current = 0
        var checkDate = Calendar.current.startOfDay(for: .now)
        let cal = Calendar.current

        for log in logs {
            let logDay = cal.startOfDay(for: log.date)
            if logDay == checkDate && log.underCap {
                current += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else if logDay == checkDate && !log.underCap {
                // Logged today but over cap: streak resets
                break
            } else if logDay < checkDate {
                // Gap in days: streak broken
                break
            }
        }

        let streakDescriptor = FetchDescriptor<StreakState>()
        let states = (try? ctx.fetch(streakDescriptor)) ?? []
        let state: StreakState
        if let existing = states.first {
            state = existing
        } else {
            state = StreakState()
            ctx.insert(state)
        }
        state.currentStreak = current
        state.longestStreak = max(state.longestStreak, current)
        state.lastCheckIn = .now
        try? ctx.save()
    }

    // MARK: - Weekly average spending
    var weeklyAverage: Double {
        let week = allLogs.prefix(7)
        guard !week.isEmpty else { return 0 }
        return week.map(\.spent).reduce(0, +) / Double(week.count)
    }

    // MARK: - Under-cap ratio (last 30 days)
    var underCapRatio: Double {
        let month = allLogs.prefix(30)
        guard !month.isEmpty else { return 0 }
        let under = month.filter(\.underCap).count
        return Double(under) / Double(month.count)
    }

    // MARK: - Delete all data
    func deleteAllData() {
        let ctx = container.mainContext
        try? ctx.delete(model: DayLog.self)
        try? ctx.delete(model: CapPlan.self)
        try? ctx.delete(model: StreakState.self)
        try? ctx.save()
        reload()
    }
}
