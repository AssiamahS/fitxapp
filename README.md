# FitX

Workout tracker for iPhone and Apple Watch. Log sets, rest between them, look back at what you lifted. Heavily inspired by Hevy.

## Features

**iPhone**
- Log workouts: exercises → sets → weight × reps, with warm-up / failure / drop set markers
- Start from scratch or from a template (Push / Pull / Legs seeded on first launch)
- Rest timer with +30s and skip, elapsed workout clock, live session volume
- "Previous" hints per exercise so you know what to beat
- History with duration, volume, sets and per-set estimated 1RM (Epley)
- Exercise library (~50 movements) plus custom exercises

**Apple Watch**
- Start a workout from the wrist — quick start or template
- Log sets with steppers, rest timer on-screen
- Finished workouts transfer to the phone over WatchConnectivity

No account, no server. Everything is stored on-device as JSON.

## Project layout

```
project.yml     XcodeGen spec — single source of truth (.xcodeproj is generated, not committed)
Shared/         models, store, exercise library, connectivity (compiled into both apps + tests)
FitX/           iPhone app (SwiftUI, iOS 17+)
FitXWatch/      watch app (SwiftUI, watchOS 10+)
FitXTests/      unit tests
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

- Template sync phone → watch
- HealthKit workout sessions + heart rate on the watch
- Charts: weekly volume, 1RM trend
- Duration/distance set types for cardio (right now cardio is rep-based)
