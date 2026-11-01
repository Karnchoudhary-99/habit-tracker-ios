import Foundation
import HabitTracker

// ht — command-line front end for the HabitTracker engine.
// State file: $HT_STORE, else ./habits.json. Dates are yyyy-MM-dd (UTC).

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("ht: \(message)\n".utf8))
    exit(1)
}

func parseDate(_ s: String, calendar: Calendar) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = calendar.timeZone
    guard let d = f.date(from: s) else { fail("bad date '\(s)' (expected yyyy-MM-dd)") }
    return d
}

func fmtDay(_ d: Date, calendar: Calendar) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = calendar.timeZone
    return f.string(from: d)
}

func parseFrequency(_ s: String) -> Frequency {
    if s == "daily" { return .daily }
    if s.hasPrefix("weekdays:") {
        let parts = s.dropFirst("weekdays:".count).split(separator: ",").compactMap { Int($0) }.compactMap { Weekday(rawValue: $0) }
        return .weekdays(Set(parts))
    }
    if s.hasPrefix("times:") {
        if let n = Int(s.dropFirst("times:".count)) { return .timesPerWeek(n) }
    }
    fail("bad frequency '\(s)' (daily | weekdays:1,3,5 | times:3)")
}

func loadStore(path: String, calendar: Calendar) -> HabitStore {
    let url = URL(fileURLWithPath: path)
    if FileManager.default.fileExists(atPath: path) {
        do { return try HabitStore.load(from: url, calendar: calendar) }
        catch { fail("cannot load \(path): \(error)") }
    }
    return HabitStore(calendar: calendar)
}

func saveStore(_ store: HabitStore, path: String) {
    do { try store.save(to: URL(fileURLWithPath: path)) }
    catch { fail("cannot save \(path): \(error)") }
}

let calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    c.firstWeekday = 2 // Monday
    return c
}()

let args = Array(CommandLine.arguments.dropFirst())
let storePath = ProcessInfo.processInfo.environment["HT_STORE"] ?? "habits.json"
let command = args.first ?? "help"

func usage() {
    print("""
    ht — habit tracker CLI
      ht add <name> [--frequency daily|weekdays:1,3,5|times:3] [--note TEXT] [--icon EMOJI]
      ht list [--all]
      ht complete <id-prefix|name> [--date YYYY-MM-DD]
      ht uncomplete <id-prefix|name> [--date YYYY-MM-DD]
      ht streak [id-prefix|name]
      ht progress [id-prefix|name] [--month YYYY-MM]
      ht remind <id-prefix|name> <HH:MM> [weekdays:1,3,5]
      ht reminders
      ht archive <id-prefix|name>
      ht export [--format csv|json] [id-prefix|name]
      ht calendar [id-prefix|name] [--month YYYY-MM]
      ht demo
    """)
}

func flagValue(_ name: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

switch command {
case "help", "--help", "-h":
    usage()

case "add":
    guard args.count >= 2 else { fail("usage: ht add <name> [flags]") }
    let freq = parseFrequency(flagValue("--frequency", in: args) ?? "daily")
    do {
        let store = loadStore(path: storePath, calendar: calendar)
        let habit = try Habit(
            name: args[1],
            note: flagValue("--note", in: args) ?? "",
            icon: flagValue("--icon", in: args) ?? "✅",
            frequency: freq,
            createdDay: calendar.startOfDay(for: Date()),
            calendar: calendar
        )
        store.addHabit(habit)
        saveStore(store, path: storePath)
        print("added \(habit.icon) \(habit.name) [\(habit.frequency.description)] id=\(habit.id.uuidString.prefix(8))")
    } catch { fail("\(error)") }

case "list":
    let store = loadStore(path: storePath, calendar: calendar)
    let showAll = args.contains("--all")
    let habits = store.habits.filter { showAll || !$0.isArchived }
    if habits.isEmpty { print("no habits yet — ht add <name>"); break }
    let engine = StreakEngine(calendar: calendar)
    let today = Date()
    for h in habits.sorted(by: { $0.name < $1.name }) {
        let done = store.completedDays(for: h.id).contains(calendar.startOfDay(for: today))
        let streak = engine.currentStreak(habit: h, completedDays: store.completedDays(for: h.id), today: today)
        print("\(h.icon) \(h.name) [\(h.frequency.description)] \(done ? "✓ today" : "○ today") streak=\(streak) id=\(h.id.uuidString.prefix(8))\(h.isArchived ? " (archived)" : "")")
    }

case "complete", "uncomplete":
    guard args.count >= 2 else { fail("usage: ht \(command) <id-prefix|name> [--date YYYY-MM-DD]") }
    let store = loadStore(path: storePath, calendar: calendar)
    guard let habit = store.resolve(args[1]) else { fail("no habit matching '\(args[1])'") }
    let date = flagValue("--date", in: args).map { parseDate($0, calendar: calendar) } ?? Date()
    let changed: Bool
    if command == "complete" {
        changed = store.complete(habitId: habit.id, on: date)
        print(changed ? "✓ \(habit.name) done on \(fmtDay(calendar.startOfDay(for: date), calendar: calendar))" : "already done on that day")
    } else {
        changed = store.uncomplete(habitId: habit.id, on: date)
        print(changed ? "○ \(habit.name) undone on \(fmtDay(calendar.startOfDay(for: date), calendar: calendar))" : "was not done on that day")
    }
    saveStore(store, path: storePath)

case "streak":
    let store = loadStore(path: storePath, calendar: calendar)
    let engine = StreakEngine(calendar: calendar)
    let targets = args.count >= 2 ? [store.resolve(args[1])].compactMap { $0 } : store.habits.filter { !$0.isArchived }
    for h in targets {
        let days = store.completedDays(for: h.id)
        print("\(h.icon) \(h.name): current=\(engine.currentStreak(habit: h, completedDays: days, today: Date())) longest=\(engine.longestStreak(habit: h, completedDays: days)) total=\(days.count)")
    }

case "progress":
    let store = loadStore(path: storePath, calendar: calendar)
    let engine = StreakEngine(calendar: calendar)
    let targets = args.count >= 2 && !args[1].hasPrefix("--") ? [store.resolve(args[1])].compactMap { $0 } : store.habits.filter { !$0.isArchived }
    var year = calendar.component(.year, from: Date())
    var month = calendar.component(.month, from: Date())
    if let m = flagValue("--month", in: args) {
        let parts = m.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { fail("bad --month (expected YYYY-MM)") }
        year = parts[0]; month = parts[1]
    }
    for h in targets {
        let days = store.completedDays(for: h.id)
        let week = engine.weekSummary(habit: h, completedDays: days, containing: Date())
        let mon = engine.monthSummary(habit: h, completedDays: days, year: year, month: month)
        let rate = String(format: "%.0f%%", mon.rate * 100)
        print("\(h.icon) \(h.name): this week \(week.completedDays)/\(week.scheduledDays) (target \(week.weeklyTarget), met=\(week.targetMet)) · \(year)-\(String(format: "%02d", month)): \(mon.completedDays)/\(mon.scheduledDays) (\(rate))")
    }

case "remind":
    guard args.count >= 3 else { fail("usage: ht remind <habit> <HH:MM> [weekdays:1,3,5]") }
    let store = loadStore(path: storePath, calendar: calendar)
    guard let habit = store.resolve(args[1]) else { fail("no habit matching '\(args[1])'") }
    let hm = args[2].split(separator: ":").compactMap { Int($0) }
    guard hm.count == 2 else { fail("bad time '\(args[2])' (expected HH:MM)") }
    var days: Set<Weekday>? = nil
    if args.count >= 4, args[3].hasPrefix("weekdays:") {
        days = Set(args[3].dropFirst("weekdays:".count).split(separator: ",").compactMap { Int($0) }.compactMap { Weekday(rawValue: $0) })
    }
    do {
        let r = try Reminder(habitId: habit.id, hour: hm[0], minute: hm[1], weekdays: days)
        store.addReminder(r)
        saveStore(store, path: storePath)
        let next = r.nextFire(after: Date(), calendar: calendar).map { fmtDay($0, calendar: calendar) + " " + r.timeString } ?? "—"
        print("reminder for \(habit.name) at \(r.timeString), next: \(next)")
    } catch { fail("\(error)") }

case "reminders":
    let store = loadStore(path: storePath, calendar: calendar)
    if store.reminders.isEmpty { print("no reminders"); break }
    for r in store.reminders {
        let name = store.habit(id: r.habitId)?.name ?? "?"
        let next = r.nextFire(after: Date(), calendar: calendar).map { fmtDay($0, calendar: calendar) + " " + r.timeString } ?? "—"
        print("\(name) at \(r.timeString)\(r.weekdays.map { " on " + $0.sorted().map(\.shortName).joined(separator: ",") } ?? "") next: \(next)")
    }

case "archive":
    guard args.count >= 2 else { fail("usage: ht archive <id-prefix|name>") }
    let store = loadStore(path: storePath, calendar: calendar)
    guard let habit = store.resolve(args[1]) else { fail("no habit matching '\(args[1])'") }
    store.archive(id: habit.id)
    saveStore(store, path: storePath)
    print("archived \(habit.name) (still listed with --all)")

case "export":
    let store = loadStore(path: storePath, calendar: calendar)
    let format = flagValue("--format", in: args) ?? "csv"
    let targets = args.count >= 2 && !args[1].hasPrefix("--") ? [store.resolve(args[1])].compactMap { $0 } : store.habits
    if format == "csv" {
        print("habit_id,habit_name,day")
        for h in targets {
            for day in store.completedDays(for: h.id).sorted() {
                let name = h.name.contains(",") ? "\"\(h.name)\"" : h.name
                print("\(h.id.uuidString),\(name),\(fmtDay(day, calendar: calendar))")
            }
        }
    } else if format == "json" {
        let data = StoreData(habits: targets, completions: store.completions.filter { c in targets.map(\.id).contains(c.habitId) }, reminders: store.reminders.filter { r in targets.map(\.id).contains(r.habitId) })
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(data: try enc.encode(data), encoding: .utf8) ?? "")
    } else {
        fail("bad --format '\(format)' (csv | json)")
    }

case "calendar":
    let store = loadStore(path: storePath, calendar: calendar)
    let engine = StreakEngine(calendar: calendar)
    guard let habit = args.count >= 2 && !args[1].hasPrefix("--") ? store.resolve(args[1]) : store.habits.first(where: { !$0.isArchived }) else {
        fail("no habit found")
    }
    var year = calendar.component(.year, from: Date())
    var month = calendar.component(.month, from: Date())
    if let m = flagValue("--month", in: args) {
        let parts = m.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { fail("bad --month (expected YYYY-MM)") }
        year = parts[0]; month = parts[1]
    }
    let grid = engine.monthGrid(habit: habit, completedDays: store.completedDays(for: habit.id), year: year, month: month)
    print("\(habit.icon) \(habit.name) — \(year)-\(String(format: "%02d", month))  (✓ done · ○ missed · · unscheduled)")
    print("Mo Tu We Th Fr Sa Su")
    var line = ""
    let first = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
    // Pad to the Monday of the first week.
    let weekday = calendar.component(.weekday, from: first) // 1 = Sun
    let pad = (weekday + 5) % 7
    for _ in 0..<pad { line += "   " }
    let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 0
    for d in 1...daysInMonth {
        let day = calendar.date(from: DateComponents(year: year, month: month, day: d))!
        let mark: String
        if calendar.startOfDay(for: day) > calendar.startOfDay(for: Date()) {
            mark = "·" // future days are not missed yet
        } else if let done = grid[calendar.startOfDay(for: day)] {
            mark = done ? "✓" : "○"
        } else {
            mark = "·"
        }
        line += String(format: "%2d%@", d, mark) + " "
        if calendar.component(.weekday, from: day) == 1 { // Sunday ends the row
            print(line.trimmingCharacters(in: .whitespaces))
            line = ""
        }
    }
    if !line.isEmpty { print(line.trimmingCharacters(in: .whitespaces)) }

case "demo":
    let store = loadStore(path: storePath, calendar: calendar)
    if store.habits.isEmpty {
        do {
            let read = try Habit(name: "Read 20 pages", icon: "📖", frequency: .daily, createdDay: calendar.addingDays(-13, to: Date()), calendar: calendar)
            let gym = try Habit(name: "Gym", icon: "🏋️", frequency: .weekdays([.monday, .wednesday, .friday]), createdDay: calendar.addingDays(-13, to: Date()), calendar: calendar)
            let meditate = try Habit(name: "Meditate", icon: "🧘", frequency: .timesPerWeek(5), createdDay: calendar.addingDays(-13, to: Date()), calendar: calendar)
            for h in [read, gym, meditate] { store.addHabit(h) }
            // Two weeks of plausible history: read daily except 2 days ago, gym on its days, meditate 5x/week.
            for offset in (0...13).reversed() {
                let day = calendar.addingDays(-offset, to: Date())
                if offset != 2 { store.complete(habitId: read.id, on: day) }
                if gym.isScheduled(on: day, calendar: calendar) && offset != 6 { store.complete(habitId: gym.id, on: day) }
                if offset % 7 != 3 && offset != 1 { store.complete(habitId: meditate.id, on: day) }
            }
            saveStore(store, path: storePath)
            print("seeded 3 demo habits with 14 days of history")
        } catch { fail("\(error)") }
    }
    let engine = StreakEngine(calendar: calendar)
    for h in store.habits {
        let days = store.completedDays(for: h.id)
        print("\(h.icon) \(h.name): current streak \(engine.currentStreak(habit: h, completedDays: days, today: Date())), longest \(engine.longestStreak(habit: h, completedDays: days)), total \(days.count)")
    }

default:
    fail("unknown command '\(command)' — try: ht help")
}
