import SwiftUI
import HabitTracker

/// Detail screen: streak stats, this week's progress, and a month grid
/// driven by the engine's monthGrid (scheduled days only — rest days and
/// future days never show as missed).
struct HabitDetailView: View {
    @EnvironmentObject private var viewModel: HabitStoreViewModel
    let habit: Habit

    @State private var year: Int
    @State private var month: Int

    init(habit: Habit) {
        self.habit = habit
        let now = Date()
        let calendar = Calendar.current
        _year = State(initialValue: calendar.component(.year, from: now))
        _month = State(initialValue: calendar.component(.month, from: now))
    }

    private var calendar: Calendar { .current }

    private var monthName: String {
        let comps = DateComponents(year: year, month: month, day: 1)
        guard let date = calendar.date(from: comps) else { return "\(month)/\(year)" }
        return date.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [Date] {
        let comps = DateComponents(year: year, month: month, day: 1)
        guard let start = calendar.date(from: comps),
            let range = calendar.range(of: .day, in: .month, for: start)
        else { return [] }
        return range.compactMap { day in
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
    }

    private func shiftMonth(by delta: Int) {
        var comps = DateComponents(year: year, month: month, day: 1)
        guard let date = calendar.date(from: comps),
            let shifted = calendar.date(byAdding: .month, value: delta, to: date)
        else { return }
        year = calendar.component(.year, from: shifted)
        month = calendar.component(.month, from: shifted)
    }

    var body: some View {
        let week = viewModel.weekSummary(habit)
        let grid = viewModel.monthGrid(habit, year: year, month: month)
        let today = calendar.startOfDay(for: Date())
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    StatBox(
                        title: "Current streak", value: "\(viewModel.currentStreak(habit))")
                    StatBox(
                        title: "Longest streak", value: "\(viewModel.longestStreak(habit))")
                    StatBox(
                        title: "This week",
                        value: "\(week.completedDays)/\(week.weeklyTarget)")
                }
                Button {
                    viewModel.toggleToday(habit)
                } label: {
                    Label(
                        viewModel.isDoneToday(habit) ? "Done today — tap to undo" : "Mark done today",
                        systemImage: viewModel.isDoneToday(habit)
                            ? "checkmark.circle.fill" : "circle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(habitColor: habit.color))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button { shiftMonth(by: -1) } label: {
                            Image(systemName: "chevron.left")
                        }
                        Spacer()
                        Text(monthName).font(.headline)
                        Spacer()
                        Button { shiftMonth(by: 1) } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6
                    ) {
                        // Header labels repeat ("T", "S"), so iterate by
                        // index — using the labels as IDs would duplicate them.
                        let headerLabels = ["S", "M", "T", "W", "T", "F", "S"]
                        ForEach(headerLabels.indices, id: \.self) { i in
                            Text(headerLabels[i]).font(.caption).foregroundStyle(.secondary)
                        }
                        // Leading blanks so day 1 lands under its weekday.
                        if let first = daysInMonth.first {
                            let weekday = calendar.component(.weekday, from: first)
                            let blanks = (weekday - calendar.firstWeekday + 7) % 7
                            ForEach(0..<blanks, id: \.self) { _ in Color.clear }
                        }
                        ForEach(daysInMonth, id: \.self) { day in
                            let dayStart = calendar.startOfDay(for: day)
                            let dayNumber = calendar.component(.day, from: day)
                            if dayStart > today {
                                // Future day: never shown as missed.
                                Text("\(dayNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, height: 30)
                            } else if let done = grid[dayStart] {
                                Circle()
                                    .fill(
                                        done
                                            ? Color(habitColor: habit.color)
                                            : Color.secondary.opacity(0.25)
                                    )
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        Text("\(dayNumber)").font(.caption)
                                            .foregroundStyle(done ? .white : .primary)
                                    )
                            } else {
                                // Unscheduled day: never shown as missed.
                                Text("\(dayNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                }
                if !habit.note.isEmpty {
                    Text(habit.note).font(.body).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("\(habit.icon) \(habit.name)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatBox: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2).bold()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
