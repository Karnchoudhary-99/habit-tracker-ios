import SwiftUI
import HabitTracker

/// Maps the engine's stored color names onto SwiftUI colors.
extension Color {
    init(habitColor name: String) {
        switch name.lowercased() {
        case "red": self = .red
        case "orange": self = .orange
        case "yellow": self = .yellow
        case "blue": self = .blue
        case "purple": self = .purple
        case "pink": self = .pink
        case "teal": self = .teal
        case "brown": self = .brown
        default: self = .green
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: HabitStoreViewModel
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.activeHabits.isEmpty {
                    ContentUnavailableView(
                        "No habits yet",
                        systemImage: "checkmark.circle",
                        description: Text("Tap + to add your first habit and start a streak.")
                    )
                } else {
                    List {
                        ForEach(viewModel.activeHabits) { habit in
                            NavigationLink(destination: HabitDetailView(habit: habit)) {
                                HabitRow(habit: habit)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Archive") { viewModel.archive(habit) }
                                    .tint(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                Button { showingAdd = true } label: {
                    Label("Add habit", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddHabitView()
            }
        }
    }
}

private struct HabitRow: View {
    @EnvironmentObject private var viewModel: HabitStoreViewModel
    let habit: Habit

    var body: some View {
        HStack(spacing: 12) {
            Button { viewModel.toggleToday(habit) } label: {
                Image(
                    systemName: viewModel.isDoneToday(habit)
                        ? "checkmark.circle.fill" : "circle"
                )
                .font(.title3)
                .foregroundStyle(Color(habitColor: habit.color))
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(habit.icon) \(habit.name)")
                    .font(.headline)
                Text("\(habit.frequency.description) · 🔥 \(viewModel.currentStreak(habit)) day streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
