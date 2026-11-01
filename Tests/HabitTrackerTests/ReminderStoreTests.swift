import Foundation
import XCTest
@testable import HabitTracker

final class ReminderStoreTests: XCTestCase {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }

    func testReminderValidation() {
        let id = UUID()
        XCTAssertThrowsError(try Reminder(habitId: id, hour: 24, minute: 0))
        XCTAssertThrowsError(try Reminder(habitId: id, hour: 8, minute: 60))
        XCTAssertThrowsError(try Reminder(habitId: id, hour: 8, minute: 0, weekdays: []))
        XCTAssertNoThrow(try Reminder(habitId: id, hour: 8, minute: 30))
    }

    func testNextFireSameDayAndNextDay() throws {
        let id = UUID()
        let r = try Reminder(habitId: id, hour: 8, minute: 30)
        // 2026-11-02 07:00 -> same day 08:30.
        let morning = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 7, minute: 0))!
        XCTAssertEqual(r.nextFire(after: morning, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 8, minute: 30)))
        // 2026-11-02 09:00 -> next day 08:30.
        let late = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9, minute: 0))!
        XCTAssertEqual(r.nextFire(after: late, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 8, minute: 30)))
    }

    func testNextFireRespectsWeekdays() throws {
        let id = UUID()
        let r = try Reminder(habitId: id, hour: 8, minute: 0, weekdays: [.monday])
        // Tuesday 2026-11-03 09:00 -> next Monday 2026-11-09.
        let tuesday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 9, minute: 0))!
        XCTAssertEqual(r.nextFire(after: tuesday, calendar: calendar),
                       calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 8, minute: 0)))
    }

    func testStoreRoundTripAndIdempotentComplete() throws {
        let store = HabitStore(calendar: calendar)
        let habit = try Habit(name: "Read", createdDay: calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!, calendar: calendar)
        store.addHabit(habit)
        let day = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2))!
        XCTAssertTrue(store.complete(habitId: habit.id, on: day))
        XCTAssertFalse(store.complete(habitId: habit.id, on: day))
        XCTAssertTrue(store.uncomplete(habitId: habit.id, on: day))
        XCTAssertFalse(store.uncomplete(habitId: habit.id, on: day))
        XCTAssertTrue(store.complete(habitId: habit.id, on: day))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ht-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try store.save(to: url)
        let loaded = try HabitStore.load(from: url, calendar: calendar)
        XCTAssertEqual(loaded.habits, store.habits)
        XCTAssertEqual(loaded.completions, store.completions)
        XCTAssertEqual(loaded.completedDays(for: habit.id), [calendar.startOfDay(for: day)])
    }

    func testResolveByPrefixAndName() throws {
        let store = HabitStore(calendar: calendar)
        let habit = try Habit(name: "Morning Run", calendar: calendar)
        store.addHabit(habit)
        XCTAssertEqual(store.resolve(String(habit.id.uuidString.prefix(8)))?.id, habit.id)
        XCTAssertEqual(store.resolve("morning")?.id, habit.id)
        XCTAssertNil(store.resolve("zzz-nope"))
    }
}
