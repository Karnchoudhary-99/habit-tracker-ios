import Foundation
import HabitTracker
import SwiftUI

/// Observable bridge between SwiftUI views and the platform-free engine.
///
/// The engine owns all rules (streaks, scheduling, persistence); this class
/// only mirrors engine state into `@Published` properties and persists
/// after every mutation, so views stay thin and the rules stay testable.
final class HabitStoreViewModel: ObservableObject {
    @Published private(set) var habits: [Habit] = []
    /// Habit IDs completed today; refreshed whenever state changes.
    @Published private(set) var doneToday: Set<UUID> = []

    private let store: HabitStore
    private let engine = StreakEngine()
    private let fileURL: URL
    private let calendar: Calendar

    /// Loads the on-disk store if present, otherwise starts empty.
    /// - Parameter fileURL: defaults to `habits.json` in the app's Documents
    ///   directory; injectable so previews/tests can use a scratch file.
    init(fileURL: URL? = nil, calendar: Calendar = .current) {
        self.calendar = calendar
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = fileURL ?? docs.appendingPathComponent("habits.json")
        self.fileURL = url
        if FileManager.default.fileExists(atPath: url.path),
            let loaded = try? HabitStore.load(from: url, calendar: calendar)
        {
            self.store = loaded
        } else {
            self.store = HabitStore(calendar: calendar)
        }
        refresh()
    }

    /// Habits that are not archived, in creation order.
    var activeHabits: [Habit] { habits.filter { !$0.isArchived } }

    func refresh() {
        habits = store.habits
        let today = calendar.startOfDay(for: Date())
        doneToday = Set(store.habits.filter { store.isCompleted(habitId: $0.id, on: today) }.map(\.id))
    }

    private func persist() {
        try? store.save(to: fileURL)
        refresh()
    }

    @discardableResult
    func addHabit(_ habit: Habit) -> Habit {
        let added = store.addHabit(habit)
        persist()
        return added
    }

    func archive(_ habit: Habit) {
        store.archive(id: habit.id)
        persist()
    }

    /// Toggles today's completion for a habit.
    func toggleToday(_ habit: Habit) {
        let today = Date()
        if store.isCompleted(habitId: habit.id, on: today) {
            store.uncomplete(habitId: habit.id, on: today)
        } else {
            store.complete(habitId: habit.id, on: today)
        }
        persist()
    }

    func isDoneToday(_ habit: Habit) -> Bool { doneToday.contains(habit.id) }

    func currentStreak(_ habit: Habit) -> Int {
        engine.currentStreak(
            habit: habit, completedDays: store.completedDays(for: habit.id), today: Date())
    }

    func longestStreak(_ habit: Habit) -> Int {
        engine.longestStreak(habit: habit, completedDays: store.completedDays(for: habit.id))
    }

    func weekSummary(_ habit: Habit) -> StreakEngine.WeekSummary {
        engine.weekSummary(
            habit: habit, completedDays: store.completedDays(for: habit.id), containing: Date())
    }

    func monthGrid(_ habit: Habit, year: Int, month: Int) -> [Date: Bool] {
        engine.monthGrid(habit: habit, completedDays: store.completedDays(for: habit.id), year: year, month: month)
    }
}
