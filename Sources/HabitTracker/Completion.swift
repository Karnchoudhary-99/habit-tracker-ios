import Foundation

/// One completed day of one habit. `day` is always start-of-day.
public struct Completion: Codable, Equatable, Hashable {
    public let habitId: UUID
    public let day: Date

    public init(habitId: UUID, day: Date, calendar: Calendar = .current) {
        self.habitId = habitId
        self.day = calendar.startOfDay(for: day)
    }
}

/// A daily reminder for a habit. `weekdays == nil` means every day.
public struct Reminder: Codable, Equatable {
    public let habitId: UUID
    public let hour: Int
    public let minute: Int
    public let weekdays: Set<Weekday>?

    public init(habitId: UUID, hour: Int, minute: Int, weekdays: Set<Weekday>? = nil) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw HabitError.invalidReminder("hour must be 0...23 and minute 0...59")
        }
        if let days = weekdays, days.isEmpty {
            throw HabitError.invalidReminder("weekdays must not be empty")
        }
        self.habitId = habitId
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
    }

    /// The next fire time strictly after `date`, looking at most 8 days ahead.
    public func nextFire(after date: Date, calendar: Calendar) -> Date? {
        for offset in 0...8 {
            let day = calendar.addingDays(offset, to: date)
            if let days = weekdays, !days.contains(calendar.weekday(of: day)) { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            if let fire = calendar.date(from: comps), fire > date { return fire }
        }
        return nil
    }

    public var timeString: String { String(format: "%02d:%02d", hour, minute) }
}
