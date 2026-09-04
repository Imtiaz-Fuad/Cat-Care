# Architecture.md

# Cat Care App - Architecture

## Overview

This document defines the architecture, project structure, and development standards for the Cat Care application. Every implementation should follow this document unless explicitly instructed otherwise.

---

# Tech Stack

## Frontend

* Flutter (latest stable)
* Material 3

## State Management

* Provider

Responsibilities:

* Global app state
* Authentication state
* Theme state
* Feature-specific state

Business logic should reside inside providers or service classes, **not inside widgets**.

---

## Routing

* go_router

Responsibilities:

* Authentication routing
* Deep linking support
* Route guards
* Nested navigation when necessary

---

## Backend

Firebase

Services:

* Firebase Authentication
* Cloud Firestore
* Firebase Storage
* Firebase Cloud Messaging (Future)
* Firebase Analytics (Future)
* Firebase Remote Config (Future)

---

## Database

Cloud Firestore

Collections should be normalized where practical and secured with proper Firestore Security Rules.

---

## Local Storage

### SharedPreferences

Used only for:

* Theme mode
* First launch flag
* User preferences
* Cached UI settings

Sensitive information must never be stored here.

---

## Networking

Use Dio for all external HTTP requests.

Do not call APIs directly from widgets.

---

## Android Toolchain Baseline

The Android toolchain is pinned by [`android/settings.gradle.kts`](../android/settings.gradle.kts) and [`android/app/build.gradle.kts`](../android/app/build.gradle.kts). Any third-party Flutter plugin must be compatible with **all** of these floors, or it will fail CI with a Gradle stack trace instead of a 1-line error.

| Tool                 | Pinned Version | Notes                                                       |
| -------------------- | -------------- | ----------------------------------------------------------- |
| Flutter SDK          | 3.44.x stable  | Set in `.github/workflows/ci.yml` (`flutter-version`).      |
| Dart SDK             | 3.12.x         | Set in `pubspec.yaml` (`environment.sdk`).                  |
| Java JDK             | 17 (Temurin)   | Java 21 is not yet supported by AGP 8.1.1.                  |
| Android Gradle Plugin| 8.1.1          | Plugin AGP floor: 8.0. Plugins targeting AGP 9+ will break. |
| Gradle wrapper       | 8.10+          |                                                             |
| Kotlin               | 1.9.10         |                                                             |
| compileSdk / targetSdk | 36           | Plugins that hard-code `compileSdk < 34` will fail.         |
| minSdk               | 23             | Android 6.0+.                                               |
| Android NDK          | r26b (if used) |                                                             |
| Core library desugaring | enabled    | Required by `flutter_local_notifications`.                  |

**Plugin adoption checklist** (run before adding any plugin with native Android code):

1. Pub.dev: ≥ 100 likes, last published < 6 months ago, Flutter 3.x compatible.
2. Read its `CHANGELOG.md` — look for AGP/Kotlin/SDK upgrade notes.
3. Read its `android/build.gradle` — check the AGP version it pins. If it is
   ≥ 2 majors ahead of our 8.1.1, skip it or fork it.
4. Pin the version **exact** (`pkg: 11.0.3`, not `^11.0.3`) until you know it
   works, then loosen the pin.
5. Add the plugin **in the same commit as its first Dart import**. No
   speculative deps — the `tools/check_native_plugin_sdk_floor.dart` CI guard
   will flag plugins that pin a stale `compileSdk` even if unused.

---

## iOS Toolchain Baseline

Pinned by [`ios/Podfile`](../ios/Podfile) and
[`ios/Runner.xcodeproj/project.pbxproj`](../ios/Runner.xcodeproj/project.pbxproj).

| Tool                            | Pinned Version | Notes                                                  |
| ------------------------------- | -------------- | ------------------------------------------------------ |
| iOS deployment target (project) | 14.0           | Required by `google_maps_flutter_ios`.                 |
| iOS deployment target (Podfile) | 14.0           | CocoaPods would default to 13.0 if unset.              |
| Swift                           | 5.x            | Inferred from Flutter stable toolchain.                |
| Xcode                           | 15.x           | Required by Flutter 3.44.x.                            |
| CocoaPods                       | 1.13+          |                                                        |

**Why 14.0 and not 13.0:** `google_maps_flutter_ios` requires iOS 14+.
CocoaPods defaults to 13.0 when `platform :ios, ...` is unset, which fails
`pod install` with "The plugin ... requires a higher minimum iOS deployment
version". The `Podfile` `post_install` hook also rewrites every pod target's
`IPHONEOS_DEPLOYMENT_TARGET` to `14.0` so transitive plugins inherit the
floor even if their podspec asks for something older.

**Plugin adoption checklist (iOS):**

1. Pub.dev: ≥ 100 likes, last published < 6 months ago, Flutter 3.x compatible.
2. Read its podspec — check `platform :ios, ...`. If it requires a target
   higher than our `14.0`, bump the project (this section) and the Podfile.
3. Run `flutter build ios --debug --no-codesign --no-pub` locally before push
   to catch CocoaPods / deployment-target failures.

---

## Logging

Use the `logger` package.

Never use `print()` in production code.

---

## Image Loading

Use `cached_network_image` for all remote images.

---

# Architecture Pattern

The application follows a **Feature-First architecture** with clear separation of responsibilities.

```
UI
│
├── Provider
│
├── Repository
│
├── Services
│
└── Firebase / External APIs
```

Rules:

* UI should never directly communicate with Firebase.
* Providers should never contain UI code.
* Services should never depend on Widgets.
* Repositories abstract data sources.
* Every layer should only know about the layer directly below it.

---

# Phase 4 — Daily Loop

The Daily Loop is the Phase 4 milestone: the four bottom-navigation
features (Home, Routine, Nutrition, Profile) wired against a single
active cat, with local notifications synced from the user's routine
schedule. This section locks the contracts that the screens, providers,
and the new notification scheduler all depend on.

## Active cat

`CatProvider` is the single source of truth for the **active cat**
(the cat whose data the current shell is showing). It exposes:

- `activeCatId` / `activeCat` — the current cat (may be `null` before
  the first stream emission or after sign-out).
- `_catsSub` — a Firestore subscription that re-emits whenever the
  user's cat list changes. Providers below `CatProvider` must listen
  to `CatProvider` and rebind their own subscriptions whenever the
  active cat changes (never read `activeCatId` once and cache it).
- `activeCatId` is persisted to `SharedPreferences` under
  `AppConstants.activeCatIdKey` so the user lands on the same cat
  after a cold start. `null` is persisted as a missing key (lets a
  future "choose your cat" bootstrap re-prompt).

## RoutineProvider

`RoutineProvider` holds the resolved routine list for the active cat
and exposes the computed daily metrics Home/Profile consume.

- `routines` — all routine tasks for the active cat (unmodifiable).
- `todaysRoutines` — tasks due on the current local date according to
  their `daily`, `weekdays`, `weekly`, or `monthly` repeat rule. The
  provider does **not** filter out tasks completed earlier today; the UI
  derives their state from `lastCompletedAt`.
- `completedTodayCount` — count of tasks whose `lastCompletedAt` is
  on or after midnight (local time). This is the single number Home
  and Profile show.
- `completionPercent` — `100 * completed / total`, clamped to `0..100`.
  Returns `0` when there are no tasks (avoids a NaN dashboard).
- `setCompletion(task, done: true)` — sets `lastCompletedAt` through
  `RoutineRepository.updateTask`; marking it undone clears that timestamp.
  The provider never touches
  the task's `notes` field; clearing notes uses the sentinel argument
  on `RoutineRepository.updateTask` directly (see below).
- `seedIfEmpty` / `reseedDefaults` — populate the routine list from
  `RoutineGeneratorService` when the active cat has no routines.
  Generation is driven by `CatLifeStage` (derived from
  `CatProfile.birthday` — there is no separate `lifeStage` field)
  plus `CatProfile.priorities`.

## NutritionProvider

`NutritionProvider` aggregates feeding + water entries for the active
cat and surfaces today's totals + the per-cat `NutritionTarget`.

- `target` — `NutritionTarget.forCat(activeCat)` when the active cat
  has a usable weight; `NutritionTarget.fallback` otherwise. The
  fallback uses documented defaults (70 g food, 200 ml water, 220
  kcal, 3 meals) and is the only path Home/Profile ever render
  before weight is known.
- `todayFoodGrams`, `todayWaterMl` — rolling totals for "today"
  (local-time midnight onward).
- `todayStatus` — enum returned to the UI that drives the Home
  snapshot's status text (`onTrack`, `belowTarget`, `aboveTarget`,
  `noData`). This is the only place the UI ever reads "is my cat
  okay" — the UI must not recompute thresholds.

## NotificationSchedulerService

`NotificationSchedulerService` reconciles the user's routine tasks
with the local notification layer. It is wired in `main.dart`'s
`_AppRouterHost._buildWiring()` as a `ChangeNotifierProvider` so the
service is app-scoped and survives route changes.

- Inputs (via constructor): `NotificationScheduleRepository`,
  `NotificationService`, `RoutineProvider`, `CatProvider`.
- Listens to `RoutineProvider` and `CatProvider`. When either
  notifies, it calls `syncNow()`.
- `syncNow()`:
  1. Watches every existing schedule for the active owner via
     `NotificationScheduleRepository.watchSchedules`.
  2. Builds the desired set of recurring `NotificationSchedule` plans from
     the current routine list (one per routine, or five weekday plans for a
     `weekdays` routine).
  3. Cancels and deletes any schedule whose `sourceType:sourceId`
     is not in the desired set (covers routine edits + cat
     switches).
  - Schedules and persists any new or changed plans.
- `idForKey(key)` — static deterministic mapping
  `String -> int` for the OS notification id. Implementation:
  `hash = hash * 31 + code; hash & 0x7fffffff`. The 31-bit mask
  guarantees the result is non-negative and fits the Android
  32-bit signed notification-id range. Same `key` must always
  produce the same id (`test/features/notifications/notification_scheduler_id_test.dart`
  pins this contract).

### Firestore schema

`users/{uid}/notification_schedules/{scheduleId}` — one document per
local notification. Fields: `catId`, `channelKey`, `title`, `body`,
`fireAt` (ISO 8601), `payload`, `sourceType`, `sourceId`, `createdAt`.
A schedule's `sourceType:sourceId` (e.g. `routine:<taskId>`) is the
stable identity the scheduler uses for diffing on the next sync.

### `RoutineRepository.updateTask` note-clearing sentinel

`RoutineRepository.updateTask` takes `Object? notes = _sentinel`
where `_sentinel` is a library-private `Object()`. The contract is:

- `_sentinel` — "leave the field alone" (no write).
- `null` — "explicitly clear the field" (write `null` to Firestore).
- `String` — "write the trimmed value" (Firestore preserves the
  trimmed string).

This three-way logic is the only path that can clear a routine
note. `RoutineProvider.updateTask` forwards via `RoutineTask.copyWith`,
which uses the standard `?? this.x` pattern and therefore **cannot**
clear nullable fields — clearing notes must call the repository
directly. Documented in `routine_provider_test.dart` and tracked
as a known asymmetry; redesigning `copyWith` to use the sentinel
pattern is a follow-up.

---

# Folder Structure

```
lib/

core/
    constants/
    errors/
    extensions/
    models/
    services/
    theme/
    utils/
    widgets/

features/

    authentication/
        models/
        providers/
        repositories/
        services/
        screens/
        widgets/

    home/
        providers/
        screens/
        widgets/

    cats/
        models/
        providers/
        repositories/
        services/
        screens/
        widgets/

    nutrition/
        ...

    health/
        ...

    reminders/
        ...

    ai/
        ...

    profile/
        ...

    settings/
        ...

routes/

main.dart
```

Every feature should be self-contained.

---

# Layer Responsibilities

## UI Layer

Contains:

* Screens
* Dialogs
* Widgets

Responsibilities:

* Display data
* Collect user input
* Listen to Providers

Must NOT:

* Query Firestore
* Execute business logic
* Parse JSON
* Call AI APIs

---

## Provider Layer

Responsibilities:

* Manage UI state
* Call repositories
* Handle loading state
* Handle error state
* Notify listeners

Providers should remain lightweight.

---

## Repository Layer

Responsibilities:

* Abstract Firebase and external services
* Combine multiple data sources when required
* Convert raw data into models

UI must never know where data comes from.

---

## Service Layer

Contains:

* Firebase services
* AI services
* Notification services
* Storage services

Each service should have one responsibility.

---

# Models

Every Firestore document should have a strongly typed model.

Models should include:

* fromJson()
* toJson()
* copyWith() (manual if needed)

Avoid using raw Map<String, dynamic> throughout the app.

---

# Error Handling

All exceptions should be caught inside repositories or services.

Providers should expose user-friendly error states.

Avoid exposing Firebase exceptions directly to the UI.

---

# Firestore Rules

The application must never rely on client-side validation alone.

Every collection must be protected using Firestore Security Rules.

Never use:

```
allow read, write: if true;
```

---

# Authentication Flow

```
Splash

↓

Check Firebase Authentication

↓

Authenticated
    ↓
Home

Not Authenticated
    ↓
Login
```

The app should automatically restore login sessions through Firebase Authentication.

SharedPreferences should not be used to determine authentication status.

---

# AI Architecture

```
Flutter (cat_care)
    │
    │  HTTPS · ?key=$GEMINI_API_KEY
    ▼
Generative Language API  (gemini-1.5-flash)
```

CatCare calls Google's Gemini `generateContent` endpoint **directly
from the device**. There is no intermediary Cloud Function and no
backend deployment involved in the AI path.

### Flow

1. The user invokes one of three AI surfaces — chat, weekly report,
   or food-label extraction — from a screen wired to `AiProvider`.
2. `AiProvider` delegates to `AiRepository`, which first checks the
   per-device daily cap stored in `SharedPreferences`
   (`ai.local.calls.{chat|weekly|food}`). If the cap is reached,
   the repository throws `AiQuotaExceededFailure` and the UI flips
   `aiAvailable` to `false`, disabling the input.
3. If the cap is OK, the repository POSTs a Gemini-shape JSON body
   to
   `https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}`.
   Auth is the `?key=` query parameter (no `Authorization` header).
4. The Gemini reply is parsed leniently (`_parseJsonLenient`) and
   rendered into a domain model.

### Where the key lives

| Surface             | Location                                          |
| ------------------- | ------------------------------------------------- |
| Source of truth     | `assets/.env` (`GEMINI_API_KEY=…`)                |
| Build-time override | `--dart-define=GEMINI_API_KEY=…` (CI / release)   |
| Runtime accessor    | `AppEnv.geminiApiKey`                             |

See `docs/CLIENT_GEMINI_KEY.md` for restriction guidance (Generative
Language API only), on-device rate-limit details (20 chat + 5 weekly
+ 5 food-label per UTC day), and the leak-response procedure.

### Diagrams

* Chat: `AiAssistantScreen` → `AiProvider.sendChatMessage` →
  `AiRepository.chat` → `lib/features/ai/prompts/chat_*.dart` +
  `gemini-1.5-flash:generateContent?key=…`.
* Weekly report: `WeeklyReportScreen` → `AiProvider.requestWeeklyReport` →
  `AiRepository.weeklyReport` → JSON-mode `generateContent`. The parsed
  report is cached by `(catId, weekId)` in `SharedPreferences` so
  re-opening the screen never re-bills Gemini.
* Food label: `FoodLabelScreen` → `AiProvider.extractFoodLabel` →
  `AiRepository.extractFoodLabel` → `generateContent` with an inline
  base64 image part, response parsed to `FoodLabelExtraction`.

---

# Code Standards

## Prefer

* StatelessWidget whenever possible
* Small reusable widgets
* Composition over inheritance
* Feature isolation
* Named constructors
* Const constructors

---

## Avoid

* Massive widgets
* Business logic inside UI
* Duplicate code
* Global mutable variables
* Direct Firebase access from widgets

---

# Naming Conventions

Classes

```
CatRepository
```

Providers

```
CatProvider
```

Services

```
FirestoreService
```

Models

```
CatModel
```

Screens

```
HomeScreen
```

Widgets

```
CatCard
```

---

## Development Rules

1. Read catcare.prd before implementing product features.
2. Read catcare.design before implementing UI.
3. Follow architecture.md for technical decisions.
4. Do not invent health/care/food content.
5. Use placeholders or Firestore-backed content where content is not provided.
6. Do not introduce new dependencies without justification.
7. Do not change architecture without explaining why.
8. Do not implement multiple unrelated features in one task.
9. Run relevant tests after implementation.

# Performance Guidelines

* Paginate Firestore queries when needed.
* Cache remote images.
* Minimize unnecessary rebuilds.
* Dispose controllers appropriately.
* Avoid rebuilding large widget trees.

---

# Security

* Never hardcode secrets.
* Validate user input.
* Secure Firestore with rules.
* Use Firebase Authentication for user identity.
* Restrict Storage access through security rules.

## Firebase client configuration

The following files are committed to the repository and are **not** secrets:

* `lib/firebase_options.dart` — generated by `flutterfire configure` from
  the CatCare Firebase project. Contains the Android/iOS `FirebaseOptions`
  constants consumed by `Firebase.initializeApp`.
* `android/app/google-services.json` — Android Gradle plugin reads this at
  build time to inject the project id, app id, and `api_key` as string
  resources.
* `ios/Runner/GoogleService-Info.plist` — iOS Firebase SDK reads this at
  runtime to resolve the project.

These files contain public identifiers (Firebase project id, app id,
messaging sender id, and the Firebase API key). Per Firebase's own
documentation, the `api_key` field is not an auth secret — it identifies
the Firebase project to SDKs and is shipped inside every Firebase
distribution. The real security boundary is the Firestore Security Rules
(`firestore.rules`) and Firebase App Check, not the api_key value.

What **must** stay out of the repository regardless of this convention:

* Firebase Admin SDK service-account JSON (`*-firebase-adminsdk-*.json`).
* APNs auth keys / `.p8` files.
* Android signing keystores (`*.jks`, `*.keystore`) and their passwords.
* Cloud Functions runtime config that embeds third-party API keys (Google
  Places, OpenAI, etc.) — those belong in Firebase Functions config or
  Secret Manager, never committed.
* `.env` files with developer-specific overrides.

## Third-party AI keys (Gemini)

CatCare ships **one** third-party AI key (`GEMINI_API_KEY`) bundled
into the Flutter snapshot. Unlike the Firebase `api_key` above, this
one is **revocable and rate-limited** — it is not a project
identifier. See [`CLIENT_GEMINI_KEY.md`](CLIENT_GEMINI_KEY.md) for
the AI-Studio restriction checklist, the per-device daily caps, and
the leak-response procedure.

## Firestore Security Rules

Source of truth: [`firestore.rules`](../firestore.rules) at the project root.

The rule set is intentionally minimal and covers the whole data model with three patterns:

| Path | Read | Write |
| --- | --- | --- |
| `/content/{category}/items/{id}` | public | admin-only (Cloud Functions / Admin SDK) |
| `/vet_clinics/{id}` | public | admin-only |
| `/users/{uid}/...` | owner (`request.auth.uid == uid`) | owner |

Anything outside these paths is implicitly denied. The deployed `firebase.json` should declare this file via `firestore.rules`, and later phases may add composite indexes to `firestore.indexes.json` as needed.

---

# Testing

Minimum expectations:

* Provider unit tests
* Repository tests
* Widget tests for important screens

---


