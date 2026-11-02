import SwiftUI
import HabitTracker

/// iOS front end for the HabitTracker engine.
///
/// This directory is intentionally NOT a SwiftPM target: SwiftUI is only
/// available on Apple platforms, while the engine package builds on Linux
/// too. To run the app, create a new iOS App project in Xcode, add this
/// package as a local dependency, and add the files in this directory to
/// the app target. CI type-checks these sources on macOS (see .github/workflows/ci.yml).
@main
struct HabitTrackerApp: App {
    @StateObject private var viewModel = HabitStoreViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
