# FitX

Workout tracker for iPhone and Apple Watch, heavily inspired by Hevy — plus the
stuff around training that you'd otherwise need three more apps for: macros,
food scanning, and a live activity so the rest timer lives in the Dynamic Island.

## Features

**Training (iPhone)**
- Hevy-style set logging: previous-session column (tap to copy), warm-up / failure /
  drop markers, per-exercise notes, PR flames when a set beats your best e1RM
- Plate calculator, kg/lb switch, configurable default rest timer
- Coach insights: "you haven't hit Squat in 5 weeks", "Bench declining 3 sessions",
  "Curl up 6%" — plus Fitbod-style muscle recovery chips and a weekly streak
- Routines (Push / Pull / Legs seeded), start-empty, repeat any past workout
- Exercise library: 51 movements with two-frame demo photos + step-by-step
  instructions (public-domain free-exercise-db), 1RM & volume charts, records
- History by month with duration, volume, sets, PR count and watch heart rate
- Profile: workouts/week + volume/week charts, 30-day muscle split, body-weight log
- Live Activity: elapsed time + rest countdown on the lock screen and Dynamic Island

**Macros**
- Daily calorie ring + protein/carbs/fat bars vs targets, four meals
- OpenFoodFacts text search, barcode scanner, manual quick add, recents
- Food photo detection: point the camera at your plate — on-device Vision
  classification guesses the food (scan-line overlay, torch for bad light) and
  logs macro estimates from a bundled table
- Today's steps + active energy from Apple Health

**Apple Watch**
- HealthKit workout session: live heart rate, average/max HR and active calories —
  saved to Apple Health and stamped onto the workout
- Native-Workout-style pages: controls / live metrics / exercise log
- Dial weight with the Digital Crown, demo photos on the wrist
- Rest timer with end-of-rest haptics; finished workouts and live HR stream to the
  phone over WatchConnectivity; routines sync phone → watch

No account, no server. Everything is stored on-device as JSON (nutrition and
training in separate files). Food search/barcode lookups hit the public
OpenFoodFacts API; photo detection is fully on-device.

## Project layout

```
project.yml     XcodeGen spec — single source of truth (.xcodeproj is generated)
Shared/         models, stores, insights engine, connectivity, exercise media
FitX/           iPhone app (SwiftUI, iOS 17+) + bundled exercise demo photos
FitXWatch/      watch app (SwiftUI + HealthKit, watchOS 10+)
FitXWidgets/    live activity (lock screen + Dynamic Island)
FitXTests/      unit tests (insights, nutrition math, store migration, units)
```

## Building

CI builds and tests every push on a macOS runner:
1. `xcodegen generate`
2. `xcodebuild test` — unit tests on an iPhone 16 simulator
3. `xcodebuild build` — watch app against the watchOS simulator SDK

Locally:

```sh
brew install xcodegen
xcodegen generate
open FitX.xcodeproj
```

## Roadmap

- Superset support and per-exercise rest overrides
- Watch-side routine start with target reps preloaded
- Food photo portion-size estimation
- Export (CSV) and Health workout route/session deep-links
