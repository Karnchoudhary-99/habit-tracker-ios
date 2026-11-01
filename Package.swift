// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "habit-tracker-ios",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "HabitTracker", targets: ["HabitTracker"]),
        .executable(name: "ht", targets: ["ht"]),
    ],
    targets: [
        .target(name: "HabitTracker", path: "Sources/HabitTracker"),
        .executableTarget(name: "ht", dependencies: ["HabitTracker"], path: "Sources/ht"),
        .testTarget(name: "HabitTrackerTests", dependencies: ["HabitTracker"], path: "Tests/HabitTrackerTests"),
    ]
)
