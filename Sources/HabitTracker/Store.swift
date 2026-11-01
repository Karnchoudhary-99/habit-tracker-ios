import Foundation

/// Versioned JSON document for the whole tracker state.
public struct StoreData: Codable {
    public var version: Int
    public var habits: [Habit]
    public var completions: [Completion]
    public var reminders: [Reminder]

    public init(version: Int = 1, habits: [Habit] = [], completions: [Completion] = [], reminders: [Reminder] = []) {
        self.version = version
        self.habits = habits
        self.completions = completions
        self.reminders = reminders
    }
}

/// In-memory tracker state with atomic JSON persistence.
public final class HabitStore {
    public let calendar: Calendar
    public private(set) var habits: [Habit]
    public private(set) var completions: [Completion]
    public private(set) var reminders: [Reminder]

    public init(calendar: Calendar = .current, data: StoreData = StoreData()) {
        self.calendar = calendar
        self.habits = data.habits
        self.completions = data.completions
        self.reminders = data.reminders
    }

    public static func load(from url: URL, calendar: Calendar = .current) throws -> HabitStore {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(StoreData.self, from: data)
        return HabitStore(calendar: calendar, data: decoded)
    }

    /// Writes via a temp file + rename so a crash never leaves a torn document.
    public func save(to url: URL) throws {
        let data = StoreData(habits: habits, completions: completions, reminders: reminders)
        let encoded = try JSONEncoder().encode(data)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let tmp = dir.appendingPathComponent(url.lastPathComponent + ".tmp")
        try encoded.write(to: tmp, options: .atomic)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.moveItem(at: tmp, to: url)
    }

    @discardableResult
    public func addHabit(_ habit: Habit) -> Habit {
        habits.append(habit)
        return habit
    }

    public func habit(id: UUID) -> Habit? { habits.first { $0.id == id } }

    /// Resolves a habit by UUID prefix or case-insensitive name substring.
    public func resolve(_ query: String) -> Habit? {
        if let id = UUID(uuidString: query) { return habit(id: id) }
        if let hit = habits.first(where: { $0.id.uuidString.lowercased().hasPrefix(query.lowercased()) }) {
            return hit
        }
        return habits.first { $0.name.lowercased().contains(query.lowercased()) }
    }

    public func archive(id: UUID) {
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[i].isArchived = true
    }

    /// Marks a habit done on a day. Returns false if it was already done.
    @discardableResult
    public func complete(habitId: UUID, on date: Date) -> Bool {
        let c = Completion(habitId: habitId, day: date, calendar: calendar)
        guard !completions.contains(c) else { return false }
        completions.append(c)
        return true
    }

    @discardableResult
    public func uncomplete(habitId: UUID, on date: Date) -> Bool {
        let c = Completion(habitId: habitId, day: date, calendar: calendar)
        guard let i = completions.firstIndex(of: c) else { return false }
        completions.remove(at: i)
        return true
    }

    public func completedDays(for habitId: UUID) -> Set<Date> {
        Set(completions.filter { $0.habitId == habitId }.map { calendar.startOfDay(for: $0.day) })
    }

    public func addReminder(_ reminder: Reminder) {
        reminders.removeAll { $0.habitId == reminder.habitId && $0.hour == reminder.hour && $0.minute == reminder.minute }
        reminders.append(reminder)
    }

    public func reminders(for habitId: UUID) -> [Reminder] {
        reminders.filter { $0.habitId == habitId }
    }
}
