# iOS Habit Tracker

Build daily habits with streaks, reminders and progress — in Swift.

The core engine is a dependency-free Swift package (`HabitTracker`) so it can be
shared between an iOS app and this command-line front end. The `ht` CLI is the
runnable demo: add habits, check them off, and watch streaks and weekly/monthly
progress update.

## Roadmap

- [x] Project scaffold (README roadmap, license, gitignore)
- [x] Habit model + streak engine
- [x] Reminders and progress views (`ht progress`, `ht remind`)
- [ ] iOS SwiftUI front end on top of the engine (engine API is UI-ready)
- [ ] Self-review checklist, then public

## Quick start

```sh
swift build -c release
HT_STORE=habits.json .build/release/ht add "Read 20 pages" --frequency daily
HT_STORE=habits.json .build/release/ht add "Gym" --frequency weekdays:1,3,5
HT_STORE=habits.json .build/release/ht complete Gym
HT_STORE=habits.json .build/release/ht streak
HT_STORE=habits.json .build/release/ht progress
```

Or try the seeded demo (3 habits, 14 days of history):

```sh
HT_STORE=/tmp/demo-habits.json .build/release/ht demo
```

Frequencies: `daily`, `weekdays:1,3,5` (1 = Sunday … 7 = Saturday),
`times:3` (3 times per week). State lives in a versioned JSON file
(`$HT_STORE`, default `./habits.json`), written atomically.

## Streak rules

- A streak counts consecutive **scheduled** days. Unscheduled days (e.g. rest
  days of a Mon/Wed/Fri habit) never break it — only a missed scheduled day does.
- If today isn't done yet, the current streak is measured to yesterday, so an
  untrained today doesn't break the run.
- Weekly progress compares completions against the habit's weekly target
  (daily = 7, weekdays = number of days, times-per-week = that count).

## Reminders

```sh
HT_STORE=habits.json .build/release/ht remind Gym 07:30 weekdays:1,3,5
HT_STORE=habits.json .build/release/ht reminders
```

A reminder stores an hour/minute and optional weekdays; `nextFire(after:)`
computes the next occurrence. On iOS this maps directly onto
`UNCalendarNotificationTrigger` — the engine deliberately keeps the
computation platform-free so it is testable on Linux too.

## More commands

```sh
HT_STORE=habits.json .build/release/ht calendar Gym --month 2026-11
HT_STORE=habits.json .build/release/ht export --format csv
HT_STORE=habits.json .build/release/ht archive "Read 20 pages"
HT_STORE=habits.json .build/release/ht list --all
```

The calendar view marks done (✓), missed scheduled days (○) and
unscheduled/future days (·); export dumps completions as CSV or JSON.

## Tests

```sh
swift test
```

## License

MIT — see [LICENSE](LICENSE).
