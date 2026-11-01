import Foundation
import XCTest
@testable import HabitTracker

final class StreakTests: XCTestCase {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }

    func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func days(_ specs: [(Int, Int, Int)]) -> Set<Date> {
        Set(specs.map { day($0.0, $0.1, $0.2) })
    }

    func testDailyCurrentStreakIncludesToday() throws {
        let habit = try Habit(name: "Read", frequency: .daily, createdDay: day(2026, 10, 26), calendar: calendar)
        let done = days([(2026, 10, 30), (2026, 10, 31), (2026, 11, 1)])
        XCTAssertEqual(StreakEngine(calendar: calendar).currentStreak(habit: habit, completedDays: done, today: day(2026, 11, 1)), 3)
    }

    func testUntrainedTodayDoesNotBreakStreak() throws {
        let habit = try Habit(name: "Read", frequency: .daily, createdDay: day(2026, 10, 26), calendar: calendar)
        let done = days([(2026, 10, 30), (2026, 10, 31)])
        // Today (Nov 1) not done yet, but yesterday was: streak is still 2.
        XCTAssertEqual(StreakEngine(calendar: calendar).currentStreak(habit: habit, completedDays: done, today: day(2026, 11, 1)), 2)
    }

    func testGapBreaksStreak() throws {
        let habit = try Habit(name: "Read", frequency: .daily, createdDay: day(2026, 10, 26), calendar: calendar)
        let done = days([(2026, 10, 28), (2026, 10, 30), (2026, 10, 31)])
        XCTAssertEqual(StreakEngine(calendar: calendar).currentStreak(habit: habit, completedDays: done, today: day(2026, 10, 31)), 2)
        XCTAssertEqual(StreakEngine(calendar: calendar).longestStreak(habit: habit, completedDays: done), 2)
    }

    func testWeekdayHabitSkipsUnscheduledDays() throws {
        // Mon/Wed/Fri habit; Nov 2 = Mon, Nov 4 = Wed, Nov 6 = Fri.
        let habit = try Habit(name: "Gym", frequency: .weekdays([.monday, .wednesday, .friday]), createdDay: day(2026, 11, 2), calendar: calendar)
        let done = days([(2026, 11, 2), (2026, 11, 4), (2026, 11, 6)])
        XCTAssertEqual(StreakEngine(calendar: calendar).currentStreak(habit: habit, completedDays: done, today: day(2026, 11, 6)), 3)
        // A missed scheduled day breaks it even though Tue/Thu are unscheduled.
        let missed = days([(2026, 11, 2), (2026, 11, 6)])
        XCTAssertEqual(StreakEngine(calendar: calendar).currentStreak(habit: habit, completedDays: missed, today: day(2026, 11, 6)), 1)
    }

    func testUnscheduledTodayDoesNotZeroStreak() throws {
        // Mon/Wed/Fri habit; Nov 6 = Fri completed, Nov 8 = Sun (unscheduled).
        let habit = try Habit(name: "Gym", frequency: .weekdays([.monday, .wednesday, .friday]), createdDay: day(2026, 11, 2), calendar: calendar)
        let done = days([(2026, 11, 2), (2026, 11, 4), (2026, 11, 6)])
        XCTAssertEqual(StreakEngine(calendar: calendar).currentStreak(habit: habit, completedDays: done, today: day(2026, 11, 8)), 3)
    }

    func testWeekSummary() throws {
        let habit = try Habit(name: "Gym", frequency: .weekdays([.monday, .wednesday, .friday]), createdDay: day(2026, 11, 2), calendar: calendar)
        let done = days([(2026, 11, 2), (2026, 11, 4)])
        let week = StreakEngine(calendar: calendar).weekSummary(habit: habit, completedDays: done, containing: day(2026, 11, 4))
        XCTAssertEqual(week.scheduledDays, 3)
        XCTAssertEqual(week.completedDays, 2)
        XCTAssertFalse(week.targetMet)
    }

    func testMonthSummaryAndGrid() throws {
        let habit = try Habit(name: "Read", frequency: .daily, createdDay: day(2026, 11, 1), calendar: calendar)
        let done = days([(2026, 11, 1), (2026, 11, 2)])
        let engine = StreakEngine(calendar: calendar)
        let month = engine.monthSummary(habit: habit, completedDays: done, year: 2026, month: 11)
        XCTAssertEqual(month.scheduledDays, 30)
        XCTAssertEqual(month.completedDays, 2)
        let grid = engine.monthGrid(habit: habit, completedDays: done, year: 2026, month: 11)
        XCTAssertEqual(grid.count, 30)
        XCTAssertEqual(grid[day(2026, 11, 1)], true)
        XCTAssertEqual(grid[day(2026, 11, 3)], false)
    }
}
