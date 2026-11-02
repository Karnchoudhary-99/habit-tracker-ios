import SwiftUI
import HabitTracker

/// Form for creating a habit. Frequency choices mirror the engine's
/// `Frequency` enum exactly (daily, chosen weekdays, N times per week).
struct AddHabitView: View {
    @EnvironmentObject private var viewModel: HabitStoreViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var note = ""
    @State private var icon = "✅"
    @State private var color = "green"
    @State private var frequencyKind = 0  // 0 daily, 1 weekdays, 2 times/week
    @State private var selectedDays: Set<Weekday> = [.monday, .wednesday, .friday]
    @State private var timesPerWeek = 3
    @State private var errorMessage: String?

    private let icons = ["✅", "🏋️", "📖", "🧘", "💧", "🎸", "✍️", "🏃"]
    private let colors = ["green", "red", "orange", "yellow", "blue", "purple", "pink", "teal"]

    private var frequency: Frequency {
        switch frequencyKind {
        case 1: return .weekdays(selectedDays)
        case 2: return .timesPerWeek(timesPerWeek)
        default: return .daily
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                    TextField("Note (optional)", text: $note)
                }
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8)) {
                        ForEach(icons, id: \.self) { candidate in
                            Button { icon = candidate } label: {
                                Text(candidate)
                                    .font(.title3)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                                    .background(
                                        icon == candidate
                                            ? Color.accentColor.opacity(0.2) : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Color") {
                    HStack {
                        ForEach(colors, id: \.self) { candidate in
                            Button { color = candidate } label: {
                                Circle()
                                    .fill(Color(habitColor: candidate))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle().stroke(
                                            Color.primary,
                                            lineWidth: color == candidate ? 2 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section("Schedule") {
                    Picker("Frequency", selection: $frequencyKind) {
                        Text("Daily").tag(0)
                        Text("Weekdays").tag(1)
                        Text("Times per week").tag(2)
                    }
                    .pickerStyle(.segmented)
                    if frequencyKind == 1 {
                        HStack {
                            ForEach(Weekday.allCases, id: \.self) { day in
                                Button {
                                    if selectedDays.contains(day) {
                                        selectedDays.remove(day)
                                    } else {
                                        selectedDays.insert(day)
                                    }
                                } label: {
                                    Text(day.shortName)
                                        .font(.caption)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            selectedDays.contains(day)
                                                ? Color.accentColor : Color.secondary.opacity(0.2)
                                        )
                                        .foregroundStyle(
                                            selectedDays.contains(day) ? .white : .primary
                                        )
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    if frequencyKind == 2 {
                        Stepper("\(timesPerWeek) times per week", value: $timesPerWeek, in: 1...7)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            let habit = try Habit(
                                name: name, note: note, icon: icon, color: color,
                                frequency: frequency)
                            viewModel.addHabit(habit)
                            dismiss()
                        } catch {
                            // HabitError's CustomStringConvertible text is
                            // clearer than the default localized description.
                            errorMessage = String(describing: error)
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
