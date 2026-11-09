# Run-Walk

A calm iPhone app for a 9-week beginner run/walk plan: from short run/walk intervals to 30 minutes
of non-stop running. Voice, beeps and vibration announce every change, so you never need to look at
the screen. No account, no tracking, everything stays on the phone.

Native SwiftUI, iOS 26, iPhone only. No third-party dependencies.

## Run it

```bash
brew install xcodegen          # once
git clone https://github.com/LucasVilela/run-walk.git && cd run-walk
xcodegen generate              # after adding or removing files
open RunWalk.xcodeproj
```

Needs Xcode 26 or later. Pick a simulator and press ⌘R; the simulator needs no signing changes. Putting it on your own phone (Developer Mode, signing,
locked-screen checks) is covered step by step in [PHONE.md](PHONE.md).

Debug builds add a ×1 / ×10 / ×60 speed button on the Run screen and a "Try any workout (dev)" menu
in Settings, so a whole workout can be tested in seconds. Neither exists in Release builds.

### On your own iPhone

The project is set up for the author's Apple developer team. To sign it with yours, change these in
`project.yml` (then run `xcodegen generate`):

- `DEVELOPMENT_TEAM`: your team ID (Xcode → Settings → Accounts).
- `bundleIdPrefix` and every `com.lucasvilela.runwalk…` bundle ID: a prefix of your own.
- The app group `group.com.lucasvilela.runwalk`, here and in `RunWalk/RunWalk.entitlements`,
  `RunWalkWidgets/RunWalkWidgets.entitlements` and `Shared/WidgetShared.swift`.

## Test it

```bash
./scripts/test.sh          # format lint + RunKit tests + app build and tests (about a minute)
./scripts/test.sh --fast   # lint + RunKit tests only (seconds)
```

- **RunKit** (`cd RunKit && swift test`): the program data, run engine (fake clock), cue timing and
  lines, scheduler, coach rules, badges, reminders, calculations, day-by-day view, SQLite
  storage and migrations, export.
- **RunWalkTests**: the app model end to end on an in-memory database (onboarding, finishing runs,
  the 80% rule, crash resume, coach cards, settings, delete, start over, export).
- Formatting: `swift format` (ships with Xcode), config in `.swift-format`.

## Build for release

1. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`, run `xcodegen generate`.
2. Xcode → Product → Archive → Distribute App.
3. No background modes and no location permission. With the phone locked, each segment switch
   arrives as a local notification with a beep; the voice resumes when the app is open.

## Looks

Settings → Look switches the whole app between five designs: **Calm** (the default, the brief's
palette), **Futuristic** (neon on deep night, monospaced), **Bold** (black, volt and heavy condensed
type), **Optimized** (pure black for OLED battery life, maximum contrast) and **Sunrise** (warm
pastels, rounded). They change colours, type, corners and light/dark behaviour only; every look keeps
run, walk and warm-up distinct and passes the contrast tests in `RunWalkTests/ThemeTests.swift`.
Add a look by adding a case to `RunWalk/App/Looks.swift`.

## Lock screen

- **Live Activity** during every run (lock screen and Dynamic Island): workout time left and a progress
  bar, animated by iOS itself, so they stay right while the app sleeps.
- **Widgets** (lock screen: rectangular, circular, inline; home screen: small): the current segment
  and its countdown during a run, switching at the right moments from a timeline written at run start;
  otherwise the next run and progress.
- The app shares a small snapshot with the widget extension through the app group
  `group.com.lucasvilela.runwalk` (`Shared/WidgetShared.swift`).

## Other runs

Runs outside the 9-week plan, from the **+** on Today and Progress: timed in the app (a stopwatch,
`RunKit/Engine/FreeRun.swift`, with a spoken time check every 5 minutes) or logged by hand. They are
stored in `runs` with `workoutId = "other"` (no schema change), add to history, day by day and totals,
and never move the plan, earn badges or start the rest window. An other run still going when the app
closes carries on when it reopens.

## How it's built

```
RunKit/                Swift package: all logic, no UI. Tested on the Mac.
  Plan/                the 27 workouts (exact data), tips
  Engine/              run state machine, cue timeline, spoken lines
  Coach/               scheduler, day by day, coach rules, badges, reminders
  Calc/                pace, stats, dates, formatting, export
  DB/                  SQLite wrapper, versioned migrations, RunStore
RunWalk/               the app
  App/                 entry point, AppModel (state), Theme (colours, type, spacing)
  Services/            voice/beeps/haptics, cue + reminder notifications
  Features/            Onboarding, Today, Plan, Run, Summary, Progress, Settings
  Components/          shared views (segment bar, cards, chips, run stats, settings controls)
scripts/               test.sh, make-beeps.py, make-icon.swift
```

Key rules (more in [CLAUDE.md](CLAUDE.md)):

- Time is never counted by summing ticks: moving time = now − start − paused time. After a crash, a
  run comes back paused at its last save, so time the app was closed never counts as running.
- The plan is sequential and dates are forecasts, recomputed on every open, so missed runs slide
  forward. Nothing is ever shown as "missed".
- A run counts when at least 80% of the main block is done; below that you choose "Retry this run next
  time" (default) or "Count it anyway".
- Coach suggestions never change the plan until you tap them; one at a time; each can be dismissed.

## Privacy

No accounts, analytics or tracking SDKs, no location, and no network code at all. Runs and settings live in a
SQLite file in the app's Application Support folder; Settings → Your data exports them as JSON and CSV.

## Contributing

Issues and pull requests are welcome. Please run `./scripts/test.sh` before sending a change, and
keep to the product principles in [CLAUDE.md](CLAUDE.md): calm, private, eyes-free, no extra screens.

This app is not affiliated with any official running programme, and it is not medical advice. Check
with a doctor before starting to run if you have any health concerns.

## License

[MIT](LICENSE) © 2026 Lucas Vilela
