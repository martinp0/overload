# Overload for iPhone and Apple Watch

A native SwiftUI companion to the Overload web app: log sets on your wrist with a HealthKit
workout session, and keep the same history as the browser through the web app's backup file.

> **Status:** source only. It hasn't been compiled yet (it was written without Xcode). Generate
> the project and build it on a Mac before using it.

## What it does

**Apple Watch**
- Start a saved workout, repeat one of your last five, or start an empty one and add exercises
  by muscle.
- Log each set on the wrist. Tap weight, reps or seconds and turn the Digital Crown. Each set is
  prefilled with what you lifted last time. Tick it to save it and start the rest timer, which
  taps your wrist when the rest is over.
- Runs an `HKWorkoutSession` (traditional strength training) for live heart rate and active
  energy, and saves the workout to Health/Fitness when you finish.
- The workout in progress is saved after every change, and the HealthKit session is recovered if
  the app gets relaunched.
- Finished workouts go to the iPhone with `WCSession.transferUserInfo`, which queues them until
  the phone is reachable.

**iPhone**
- History with sets, volume, duration, heart rate, energy and records. Records are recomputed
  with the same rules as `detectRecords()` in `js/engine.js`.
- Saved workouts (templates), which are pushed to the Watch. Any past workout can be saved as one.
- **Import backup** / **Export backup** using exactly the JSON from the web app's
  *Settings → Export backup*. Import can either add only new workouts (matched by id) or replace
  everything, like the web app does. Export can be imported back in the browser.

## Data compatibility

There's no backend. The web app keeps everything in `localStorage`, so the native apps use the
same backup format (`{ app: "overload", version: 1, settings, history, templates, custom, prefs }`):

- Workouts, sets, templates and custom exercises use the same fields and ids (`uid()` format).
- `settings` and `prefs` are carried through unchanged, and the unit (kg/lb) is read from them.
- Workouts logged on the Watch get one extra optional key, `health` (`activeKcal`,
  `avgHeartRate`, `maxHeartRate`). The web app ignores it.
- The exercise library comes from `js/data.js` through `Shared/Resources/exercises.json`. After
  changing `js/data.js`, regenerate the file with `node apple/scripts/export-exercises.mjs`.

## Build

```sh
brew install xcodegen
cd apple
xcodegen generate
open Overload.xcodeproj
```

Pick your team under *Signing & Capabilities* for both targets, then run the `Overload` scheme on
an iPhone paired with a Watch. The Watch app is embedded in the iPhone app.

| Target | Bundle ID | Platform |
|---|---|---|
| Overload | `cz.martinpohl.overload` | iOS 17+ |
| OverloadWatch | `cz.martinpohl.overload.watchkitapp` | watchOS 10+ |

Capabilities: **HealthKit** on the Watch target, plus the Watch background mode
`workout-processing`. Both are already in `project.yml`, but the HealthKit capability also has
to be enabled for the App ID in the Apple Developer portal.

## Code map

| Path | What's in it |
|---|---|
| `Shared/Models.swift` | Backup/workout/template/exercise models, matching the web app's JSON |
| `Shared/Engine.swift` | e1RM, records, stats and "last time" lookups, ported from `js/engine.js` |
| `Shared/SyncPayload.swift` | What the phone and Watch send each other |
| `iOS/OverloadStore.swift` | Local JSON store, import/merge/export, Watch context |
| `iOS/PhoneSync.swift` | iPhone side of WatchConnectivity |
| `watchOS/WatchStore.swift` | Watch state, workout in progress, sending finished workouts |
| `watchOS/WorkoutManager.swift` | HealthKit workout session and builder |
| `watchOS/SetLoggerView.swift` | Set logging with the Digital Crown, rest timer |
