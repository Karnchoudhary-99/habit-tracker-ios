import Foundation

/// Pure streak / progress calculations over a set of completed days.
/// Unscheduled days never break a streak — only a missed *scheduled* day does.
public struct StreakEngine {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Consecutive scheduled days completed, ending today — or yesterday if
    /// today is not done yet (an untrained today must not break the run).
    public func currentStreak(habit: Habit, completedDays: Set<Date>, today: Date) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        var anchor = todayStart
        if !completedDays.contains(todayStart) {
            anchor = calendar.addingDays(-1, to: todayStart)
            guard completedDays.contains(anchor) else { return 0 }
        }
        var streak = 0
        var day = anchor
        while true {
            if habit.isScheduled(on: day, calendar: calendar) {
                guard completedDays.contains(day) else { break }
                streak += 1
            }
            if day <= habit.createdDay && streak > 0 { break }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            if prev < habit.createdDay { break }
            day = prev
            // Safety bound: no streak can exceed the days since creation + 1.
            if streak > 3660 { break }
        }
        return streak
    }

    /// Longest run of consecutive scheduled days ever completed.
    public func longestStreak(habit: Habit, completedDays: Set<Date>) -> Int {
        guard let first = completedDays.min(), let last = completedDays.max() else { return 0 }
        var best = 0
        var run = 0
        var day = calendar.startOfDay(for: first)
        let end = calendar.startOfDay(for: last)
        while day <= end {
            if habit.isScheduled(on: day, calendar: calendar) {
                if completedDays.contains(day) {
                    run += 1
                    best = max(best, run)
                } else {
                    run = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }

    public struct WeekSummary: Equatable {
        public let weekStart: Date
        public let scheduledDays: Int
        public let completedDays: Int
        public let weeklyTarget: Int
        public var targetMet: Bool { completedDays >= weeklyTarget }
        public var rate: Double {
            scheduledDays == 0 ? 1.0 : Double(completedDays) / Double(scheduledDays)
        }
    }

    /// Summary of the calendar week containing `date`.
    public func weekSummary(habit: Habit, completedDays: Set<Date>, containing date: Date) -> WeekSummary {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return WeekSummary(weekStart: date, scheduledDays: 0, completedDays: 0, weeklyTarget: habit.frequency.weeklyTarget)
        }
        var scheduled = 0
        var completed = 0
        var day = interval.start
        while day < interval.end {
            if habit.isScheduled(on: day, calendar: calendar) {
                scheduled += 1
                if completedDays.contains(calendar.startOfDay(for: day)) { completed += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return WeekSummary(
            weekStart: interval.start,
            scheduledDays: scheduled,
            completedDays: completed,
            weeklyTarget: habit.frequency.weeklyTarget
        )
    }

    public struct MonthSummary: Equatable {
        public let year: Int
        public let month: Int
        public let scheduledDays: Int
        public let completedDays: Int
        public var rate: Double {
            scheduledDays == 0 ? 1.0 : Double(completedDays) / Double(scheduledDays)
        }
    }

    /// Summary of one calendar month (1...12).
    public func monthSummary(habit: Habit, completedDays: Set<Date>, year: Int, month: Int) -> MonthSummary {
        var comps = DateComponents(year: year, month: month, day: 1)
        guard let start = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: start)
        else {
            return MonthSummary(year: year, month: month, scheduledDays: 0, completedDays: 0)
        }
        var scheduled = 0
        var completed = 0
        for day in range {
            comps.day = day
            guard let date = calendar.date(from: comps) else { continue }
            if habit.isScheduled(on: date, calendar: calendar) {
                scheduled += 1
                if completedDays.contains(calendar.startOfDay(for: date)) { completed += 1 }
            }
        }
        return MonthSummary(year: year, month: month, scheduledDays: scheduled, completedDays: completed)
    }

    /// Day-by-day completion map for a month, for heatmap-style views.
    public func monthGrid(habit: Habit, completedDays: Set<Date>, year: Int, month: Int) -> [Date: Bool] {
        var comps = DateComponents(year: year, month: month, day: 1)
        guard let start = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: start)
        else { return [:] }
        var grid: [Date: Bool] = [:]
        for day in range {
            comps.day = day
            guard let date = calendar.date(from: comps) else { continue }
            let d = calendar.startOfDay(for: date)
            if habit.isScheduled(on: date, calendar: calendar) {
                grid[d] = completedDays.contains(d)
            }
        }
        return grid
    }
}
