# AGENTS.md

Flutter app ("Koridor Hız Asistanı") — a Turkish EDS/radar speed assistant. Android-first, GPS/offline core plus Firebase (auth/Firestore) and TTS. Entry: `lib/main.dart` (`KoridorApp`, wrapped in `ProviderScope`).

## Commands

- `flutter pub get`
- `flutter analyze` — currently reports **0 issues**. Keep it at 0; `scratch/` is excluded in `analysis_options.yaml`.
- `flutter test` — **68 tests, all passing** across: geofence logic (`test/eds_geofence_service_test.dart`), score math (`test/driving_score_test.dart`, `test/driving_score_persistence_test.dart`, `test/driving_score_provider_test.dart`), badges (`test/badge_service_test.dart`), models (`test/eds_point_test.dart`), heading mapping (`test/heading_test.dart`), GPS notifier (`test/gps_tracking_notifier_test.dart`), storage (`test/eds_storage_service_test.dart`), and app auth-state branches (`test/widget_test.dart`, uses `authStateProvider` overrides — Firebase is never initialized in tests).
- Single test: `flutter test test/<file>.dart`
- `flutter run` (Android only, see below)

No CI, no Cloud Functions, empty `README.md`. `firestore.rules` + `firestore.indexes.json` + `firebase.json` + `.firebaserc` are committed and aligned with the app's field names; they still must be **deployed** with `firebase deploy --only firestore` (or pasted in the Firebase console). The deployed rules are live security state, not the repo file — reconcile after any collection/field change.

## Platform / Firebase gotchas

- `Firebase.initializeApp()` is called with no options. Android config is `android/app/google-services.json` (committed). There is **no** `firebase_options.dart` and **no iOS `GoogleService-Info.plist`** — iOS/web/macOS builds have no Firebase config.
- Android package is `com.edsasistani.app` (`namespace` + `applicationId` + `MainActivity`), not the Flutter default `com.example.eds_mobile_app`. `google-services.json` must contain a client for this exact package id and the release keystore's SHA-1.
- Firestore persistence is enabled in `main.dart`.
- Release signing reads `android/key.properties` (git-ignored) when present, otherwise falls back to the debug key. Never commit `key.properties`/keystores.

## Architecture

- Layers: `models/` → `services/` → `providers/` → `views/` → `widgets/`. Widgets must not import services directly; views orchestrate via Riverpod.
- Two state styles coexist: legacy GPS/offline state is `setState` inside `_DashboardViewState` (`lib/views/dashboard_view.dart`); newer network features (auth, friends, sharing, scores) use Riverpod providers in `lib/providers/`.
- Singletons (factory-constructor, do not create parallel instances) and their in-memory caches: `AudioService`, `EdsStorageService`, `EdsGeofenceService`, `DrivingScoreService`.

## Domain invariants

- All user-facing strings are Turkish. TTS language is hardcoded `tr-TR`. Never add English UI text.
- Default speed limit is `82` km/h (Turkish EDS standard).
- GPS stream uses `distanceFilter: 2` m; distance math assumes sequential ~2 m updates.
- `SpeedData.heading` is `double?`: `null` means "bearing unavailable". `LocationService.mapHeading` maps geolocator's negative sentinel (-1, or negative bearings) to `null`; a null heading therefore never triggers `checkAutomaticStart`. Android reports `heading: 0` while stationary — not null — by design.
- Geofence constants in `lib/services/eds_geofence_service.dart`: bounding box `0.006°` (tuned for ~38°N Turkey), trigger 500 m, end 100 m, heading tolerance 45°. `checkAutomaticStop` requires `distanceTraveledMeters >= 500` — do not lower it.
- Storage keys are per-user: `custom_eds_points_<uid>` (`EdsStorageService`) and `driving_scores_<uid>` (`DrivingScoreService`), falling back to `guest`. The `_storageKey` getters are guarded — if Firebase Auth is unavailable they fall back to `guest` instead of throwing. On auth change call `EdsStorageService().clearCache()` then `EdsGeofenceService().reloadPoints()` (already done in `auth_service.dart`).
- `EdsStorageService` caches points in `_cachedPoints`; invalidate with `clearCache()`, not by re-reading. After saving/deleting a custom point, call `_geofenceService.reloadPoints()`.
- `community_points` is read by lowercased `region` + `orderBy('upvotes')` + `limit` with `startAfterDocument` pagination (`sharing_service.dart`). A `geoHash` field is stored but prefix queries are not implemented.

## Model quirks

- `EdsPoint` has `copyWith`, `==`/`hashCode` (field-based) and `hasSameCoordinates()`. `==` compares ALL fields (id, name, coords, bidirectional, speedLimit); for positional/near-same-place checks use `hasSameCoordinates()` (epsilon `0.00001`) or `id`. JSON defaults `speedLimit` to 82.
- `SpeedData` has no `==`.
- `SpeedStatus` enum lives in `lib/theme/design_tokens.dart`, not a model.

## Dashboard architecture (`lib/views/dashboard_view.dart` + `lib/providers/gps_tracking_provider.dart`)

- All GPS tracking state (activity, speed/distance/status, scoring counters, auto start/stop) lives in `TrackingState` via `gpsTrackingNotifier` (`GpsTrackingNotifier`, a `StateNotifier`). The view is a thin renderer — do NOT add new mutable fields to `_DashboardViewState`.
- `dashboard_view` yields no logic of its own: watch state in build, call notifier methods (`requestPermission`, `toggleTracking`, `cycleAudioMode`), and consume UI side effects through `ref.listen` (snackbars via `TrackingUiEvent`, score sheet via `lastSession` id change, custom-route dialog via `customEdsPrompt`).
- Session-end scoring stays in the notifier (`DrivingScoreService.calculateScore`) and persists via `drivingScoreListProvider.addScore` (fire-and-forget).
- GPS subscription guard: `requestPermission()` subscribes once (`_speedSubscription != null` check) — geolocator stream tests override `locationServiceProvider` with a fake `Stream<SpeedData>`.
- `_totalDistance` defaults to `10.0` km as a mock when no corridor is active (`TrackingState.totalDistanceKm`).

## Firestore rules & indexes

- In `firestore.rules`: `users` is readable by any signed-in user (needed by email search + both leaderboards); writes are self-only. `friendCount` is no longer updated cross-user (legacy/unused field — derive it from `friendships` if ever needed). `community_points.upvotes` may be changed by ±1 by any signed-in user (owner-only for everything else); friendships/shared_points stay participant-scoped.
- Required composite indexes are committed in `firestore.indexes.json`: `community_points(region ↑, upvotes ↓)`, `friendships(participants CONTAINS, status ↑, createdAt ↓)`, `friendships(toUid ↑, status ↑, createdAt ↓)`, `shared_points(targetUid ↑, createdAt ↓)`, `users(isLeaderboardHidden ↑, averageScore ↓)`.

## Release / store checklist

- Deploy backend first: `firebase deploy --only firestore` (project `eds-mobile-app-80d12`, pinned in `.firebaserc`).
- Android: create `android/key.properties` + upload keystore, register the release SHA-1 in Firebase (Google Sign-In), then `flutter build appbundle --release`.
- iOS is currently unconfigured: needs `GoogleService-Info.plist` and `firebase_options.dart` (FlutterFire CLI).

## Conventions

- All colors/text styles/decorations come from `lib/theme/design_tokens.dart`; no hardcoded color values elsewhere.
- `flutter_lints` v6 defaults + `scratch/**` analyzer exclude (`analysis_options.yaml`). Baseline is **0 issues** — write in the fixed style directly: `withOpacity` → `.withValues()`, `Radio.activeColor` → `activeThumbColor`, `TextFormField value` → `initialValue`, no empty `catch {}`, `_` (not `__`/`___`) unused params, `for` with braces.
- `.gitignore` ignores `*.ps1` and `scratch/` (helper scripts are intentionally uncommitted).
