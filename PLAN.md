# PLAN — 9-week beginner run/walk app (native Swift)

Working name: **Run-Walk** (folder `~/Developer/run-walk`) until you pick the app name.
The original brief was written for Expo / React Native. You asked for native Swift, so this plan
keeps every product requirement and swaps each library for its first-party Apple equivalent.
Nothing is built yet. **Reply "go" (plus answers to the questions at the bottom) to start phase 1.**

## 1. What changes by going native

| Brief (Expo) | Native Swift (this plan) |
|---|---|
| Expo SDK, React Native, TS strict | SwiftUI, Swift 6 (strict concurrency), iOS 26, iPhone only |
| Expo Router tabs | `TabView` (4 tabs) + `fullScreenCover` for Onboarding / Run / Summary |
| expo-sqlite + typed layer | System `SQLite3` + a small typed wrapper, versioned migrations (no dependency, no ORM) |
| zustand | `@Observable` stores injected via `@Environment` |
| date-fns | Foundation `Calendar`, `Date.FormatStyle` |
| expo-speech | `AVSpeechSynthesizer` |
| expo-audio (mix + duck) | `AVAudioSession` `.playback` + `.mixWithOthers` + `.duckOthers`, deactivated with `.notifyOthersOnDeactivation` after each cue so music comes back |
| expo-haptics | Core Haptics patterns (run = 2 strong taps, walk = 1 long buzz) |
| expo-location + task-manager | Core Location `CLLocationUpdate.liveUpdates()` + `CLBackgroundActivitySession` |
| react-native-maps | MapKit for SwiftUI (`Map` + `MapPolyline`) |
| expo-notifications (local) | `UserNotifications` (local only) |
| expo-keep-awake | `UIApplication.isIdleTimerDisabled` while the Run screen is up |
| expo-file-system + sharing | Temp files + `ShareLink` |
| react-native-svg charts | SwiftUI shapes for the segment bar, Swift Charts (first-party) for the weekly chart |
| Jest + RTL | Swift Testing for logic, a few XCUITests for key flows |
| ESLint + Prettier | `swift format` (ships with Xcode 26) |
| Expo Go → dev build in phase 4 | Xcode build to your iPhone from phase 1, no Expo Go step |
| Android | **Dropped**: native Swift means iPhone only |

Project setup follows Receipt Calc: `project.yml` + **xcodegen**, and all pure logic in a local
Swift package (**RunKit**) that tests on the Mac in seconds with `swift test`.

## 2. Architecture

- **RunKit** (Swift package, no UIKit/SwiftUI imports): program data, run engine state machine,
  cue scheduling, coach rules, scheduler, calculations, GPS filter and distance math, DB layer.
  Everything takes an injected clock (`now: () -> Date`) so tests use a fake clock.
- **App target**: SwiftUI views, `@Observable` stores, and thin "effect" services that turn engine
  events into sound, speech, haptics, notifications and location.
- Engine emits *events* (segment started, 3-2-1, halfway, one minute, last run, finished); a
  `CuePlayer` service performs them. The engine never touches audio, so it stays testable.
- Elapsed time is always `now − startedAt − pausedTotal`. The UI redraws every 250 ms with a
  `TimelineView`. Coming back from background recomputes position and announces the current segment once.

## 3. Keeping the run alive when the phone is locked (needs your decision, Q3)

- **GPS on**: `CLBackgroundActivitySession` + location background mode keeps the app running, so
  voice cues play normally while locked.
- **Treadmill / GPS off**: the brief's plan is scheduled local notifications at every segment
  boundary. They beep and vibrate, but **cannot speak**. iOS 26 now offers `HKWorkoutSession` on
  iPhone (checked in the iOS 26.5 SDK), which keeps the app running in the background with no GPS,
  so voice cues work on a treadmill too. It needs a one-time Health permission and saves each run as
  a workout in Apple Health (still on-device; no network).
- Recommended: HKWorkoutSession for every run, with notifications kept as the fallback if Health
  permission is denied.

## 4. File tree

```
run-walk/
├─ project.yml                 xcodegen spec (app, unit tests, UI tests)
├─ CLAUDE.md  PLAN.md  README.md
├─ scripts/test.sh             swift test + xcodebuild test
├─ RunKit/                     Swift package: pure logic
│  ├─ Package.swift
│  ├─ Sources/RunKit/
│  │  ├─ Plan/      Program.swift (27 workouts), Segment.swift, Tips.swift
│  │  ├─ Engine/    RunEngine.swift, RunState.swift, CueSchedule.swift, CueLines.swift
│  │  ├─ Coach/     Scheduler.swift, CoachRules.swift, Badges.swift, Reminders.swift
│  │  ├─ Calc/      Pace.swift, PaceCalculator.swift, Riegel.swift, Stats.swift, DateHelpers.swift
│  │  ├─ GPS/       PointFilter.swift, Haversine.swift, Splits.swift, RollingPace.swift
│  │  └─ DB/        Database.swift (SQLite3 wrapper), Migrations.swift, Repositories.swift, Export.swift
│  └─ Tests/RunKitTests/       one test file per folder + Fixtures/ (GPS tracks)
├─ RunWalk/                    app target
│  ├─ App/        RunWalkApp.swift, AppStore.swift (@Observable), Theme.swift
│  ├─ Services/   CuePlayer.swift (speech, beeps, haptics, ducking), LocationService.swift,
│  │              WorkoutSessionService.swift, NotificationService.swift, ActiveRunPersistence.swift
│  ├─ Features/
│  │  ├─ Onboarding/  OnboardingView.swift (3 steps)
│  │  ├─ Today/       TodayView.swift, CoachCard.swift
│  │  ├─ Run/         RunView.swift, RunControls.swift, LockOverlay.swift, DevSpeedToggle.swift
│  │  ├─ Summary/     RunSummaryView.swift, CheckInView.swift
│  │  ├─ Plan/        PlanView.swift, WorkoutPreviewSheet.swift
│  │  ├─ Progress/    ProgressView.swift, WeeklyChart.swift, HistoryList.swift, RunDetailView.swift,
│  │  │               PaceCalculatorCard.swift, BadgesGrid.swift
│  │  └─ Settings/    SettingsView.swift
│  ├─ Components/ SegmentBar.swift, BigButton.swift, EmptyState.swift
│  └─ Resources/  Assets.xcassets, beep-short.caf, beep-long.caf (tones generated by script, original)
├─ RunWalkTests/               app-side tests (stores, persistence)
└─ RunWalkUITests/             onboarding → Today "Week 1 · Run 1"; start/pause/end a run
```

## 5. Data model

Same tables as the brief (settings, workout_progress, runs, route_points, splits, badges,
coach_dismissals, active_run) in SQLite at `Application Support/runwalk.sqlite`, with a
`schema_version` table and numbered migrations. The active run is saved every 10 s; on launch the
app offers "Resume your run?".

## 6. Phases (stop and report after each: build, `swift format lint`, all tests)

1. **Foundation**: xcodegen project, RunKit package, Theme tokens, Program (27 workouts + tests
   from the brief), scheduler, coach rules, calculations, GPS math, all unit-tested. Placeholder tabs.
2. **Run engine**: state machine + fake-clock tests (transitions, pause/resume, skip, end early,
   background resume, completion %), cue lines, CuePlayer (speech, beeps, haptics, ducking), Run
   screen in time-only mode, lock overlay, `#if DEBUG` ×10 / ×60 speed toggle, background keep-alive (per Q3).
3. **Core loop**: SQLite + migrations, onboarding, Today, Plan, Summary + check-in, 80% rule,
   plan advancement, crash-resume.
4. **GPS**: location service + background session, filter, rolling pace, splits, route map,
   notification fallback for cues, treadmill manual distance.
5. **Progress & coach**: stats, weekly chart, history, run detail (edit/delete), pace calculator,
   projected 5K, badges, reminders, suggestion cards, settings, JSON + CSV export.
6. **Polish**: VoiceOver labels, Dynamic Type, reduced motion, dark mode, empty states, copy
   review, placeholder icon, README. Final report against the "Done when" list.

How you'll test on your phone: plug in the iPhone, open `RunWalk.xcodeproj`, pick your phone,
press Run. Signing uses your existing team (as in Receipt Calc). The Debug build shows the speed toggle.

## 7. Questions for you

1. **App name?** (Used for the display name, bundle id `com.lucasvilela.<name>`, and copy.) Not "Couch to 5K".
2. **iPhone only, iOS 26 minimum** — OK? (Native Swift drops Android.) And your test phone is an
   iPhone on iOS 26 — which model?
3. **Locked-screen voice cues on a treadmill**: use `HKWorkoutSession` (recommended; adds a Health
   permission and saves runs to Apple Health), or stick to the brief's notification-only fallback (beeps, no voice)?
4. **Storage**: raw SQLite as the brief says (recommended: exact schema, migrations, testable on the
   Mac), or SwiftData (more "native", but less control over migrations)?
5. **Lock-screen Live Activity** ("Week 3 · Run 2 — Walk 1:12 left") is the iOS equivalent of the
   Android persistent notification in the brief. Add it in phase 4, or leave it out (scope lock)?
6. Locale **en-AU** and km default, as in the brief — confirm?
7. Your experience level, so I pitch the phase reports right?
