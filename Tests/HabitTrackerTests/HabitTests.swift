import Foundation
import XCTest
@testable import HabitTracker

final class HabitTests: XCTestCase {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }

    func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    func testEmptyNameRejected() {
        XCTAssertThrowsError(try Habit(name: "   ", calendar: calendar)) { error in
            XCTAssertEqual(error as? HabitError, .emptyName)
        }
    }

    func testTimesPerWeekBounds() {
        XCTAssertThrowsError(try Habit(name: "X", frequency: .timesPerWeek(0), calendar: calendar))
        XCTAssertThrowsError(try Habit(name: "X", frequency: .timesPerWeek(8), calendar: calendar))
        XCTAssertNoThrow(try Habit(name: "X", frequency: .timesPerWeek(7), calendar: calendar))
    }

    func testEmptyWeekdaysRejected() {
        XCTAssertThrowsError(try Habit(name: "X", frequency: .weekdays([]), calendar: calendar))
    }

    func testWeeklyTargets() {
        XCTAssertEqual(Frequency.daily.weeklyTarget, 7)
        XCTAssertEqual(Frequency.weekdays([.monday, .friday]).weeklyTarget, 2)
        XCTAssertEqual(Frequency.timesPerWeek(3).weeklyTarget, 3)
    }

    func testScheduledDays() throws {
        // 2026-11-02 is a Monday.
        let habit = try Habit(name: "Gym", frequency: .weekdays([.monday, .wednesday]), calendar: calendar)
        XCTAssertTrue(habit.isScheduled(on: day(2026, 11, 2), calendar: calendar))
        XCTAssertFalse(habit.isScheduled(on: day(2026, 11, 3), calendar: calendar))
        XCTAssertTrue(habit.isScheduled(on: day(2026, 11, 4), calendar: calendar))
    }

    func testFrequencyRoundTrip() throws {
        let habit = try Habit(name: "Gym", frequency: .weekdays([.monday, .friday]), calendar: calendar)
        let data = try JSONEncoder().encode(habit)
        let decoded = try JSONDecoder().decode(Habit.self, from: data)
        XCTAssertEqual(decoded, habit)
    }

    func testIsCompletedIgnoresTimeOfDay() throws {
        let store = HabitStore(calendar: calendar)
        let habit = try store.addHabit(Habit(name: "Read", calendar: calendar))
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 8))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 21))!
        XCTAssertFalse(store.isCompleted(habitId: habit.id, on: morning))
        XCTAssertTrue(store.complete(habitId: habit.id, on: morning))
        XCTAssertTrue(store.isCompleted(habitId: habit.id, on: evening))
        XCTAssertTrue(store.uncomplete(habitId: habit.id, on: evening))
        XCTAssertFalse(store.isCompleted(habitId: habit.id, on: morning))
    }
}
