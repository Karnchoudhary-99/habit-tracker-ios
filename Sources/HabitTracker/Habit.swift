import Foundation

/// A weekday, using the Calendar convention (1 = Sunday … 7 = Saturday).
public enum Weekday: Int, Codable, CaseIterable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.rawValue < rhs.rawValue }

    public var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

/// How often a habit is scheduled.
public enum Frequency: Equatable, Codable {
    case daily
    case weekdays(Set<Weekday>)
    case timesPerWeek(Int)

    private enum CodingKeys: String, CodingKey { case kind, days, count }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .kind) {
        case "daily": self = .daily
        case "weekdays": self = .weekdays(try c.decode(Set<Weekday>.self, forKey: .days))
        case "timesPerWeek": self = .timesPerWeek(try c.decode(Int.self, forKey: .count))
        default: throw HabitError.invalidFrequency("unknown frequency kind")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .daily:
            try c.encode("daily", forKey: .kind)
        case .weekdays(let days):
            try c.encode("weekdays", forKey: .kind)
            try c.encode(days, forKey: .days)
        case .timesPerWeek(let count):
            try c.encode("timesPerWeek", forKey: .kind)
            try c.encode(count, forKey: .count)
        }
    }

    /// Weekly target: the number of completions that counts as a full week.
    public var weeklyTarget: Int {
        switch self {
        case .daily: return 7
        case .weekdays(let days): return days.count
        case .timesPerWeek(let count): return count
        }
    }

    public var description: String {
        switch self {
        case .daily: return "daily"
        case .weekdays(let days):
            return days.sorted().map(\.shortName).joined(separator: ",")
        case .timesPerWeek(let count): return "\(count)x/week"
        }
    }
}

public enum HabitError: Error, Equatable, CustomStringConvertible {
    case emptyName
    case invalidFrequency(String)
    case invalidReminder(String)
    case unknownHabit
    case duplicateCompletion

    public var description: String {
        switch self {
        case .emptyName: return "habit name must not be empty"
        case .invalidFrequency(let m): return "invalid frequency: \(m)"
        case .invalidReminder(let m): return "invalid reminder: \(m)"
        case .unknownHabit: return "unknown habit"
        case .duplicateCompletion: return "already completed that day"
        }
    }
}

public struct Habit: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var note: String
    public var icon: String
    public var color: String
    public var frequency: Frequency
    public var createdDay: Date
    public var isArchived: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        note: String = "",
        icon: String = "✅",
        color: String = "green",
        frequency: Frequency = .daily,
        createdDay: Date = Date(),
        isArchived: Bool = false,
        calendar: Calendar = .current
    ) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HabitError.emptyName }
        switch frequency {
        case .weekdays(let days):
            guard !days.isEmpty else { throw HabitError.invalidFrequency("weekdays must not be empty") }
        case .timesPerWeek(let count):
            guard (1...7).contains(count) else { throw HabitError.invalidFrequency("timesPerWeek must be 1...7") }
        case .daily: break
        }
        self.id = id
        self.name = trimmed
        self.note = note
        self.icon = icon
        self.color = color
        self.frequency = frequency
        self.createdDay = calendar.startOfDay(for: createdDay)
        self.isArchived = isArchived
    }

    /// Is this habit scheduled on the given day (ignoring time of day)?
    public func isScheduled(on date: Date, calendar: Calendar) -> Bool {
        switch frequency {
        case .daily:
            return true
        case .weekdays(let days):
            return days.contains(Weekday(rawValue: calendar.component(.weekday, from: date)) ?? .sunday)
        case .timesPerWeek:
            return true
        }
    }
}

public extension Calendar {
    /// The weekday of a date as a `Weekday`.
    func weekday(of date: Date) -> Weekday {
        Weekday(rawValue: component(.weekday, from: date)) ?? .sunday
    }

    func addingDays(_ n: Int, to date: Date) -> Date {
        self.date(byAdding: .day, value: n, to: startOfDay(for: date))!
    }
}
