# AGENTS.md

Flutter app ("Koridor Hız Asistanı") — a Turkish EDS/radar speed assistant. Android-first, GPS/offline core plus Firebase (auth/Firestore), RevenueCat (subscriptions), and TTS. Entry: `lib/main.dart` (`KoridorApp`, wrapped in `ProviderScope`).

## Commands

- `flutter pub get`
- `flutter analyze` — currently reports 26 info/warning issues, no errors. `scratch/` is NOT excluded even though it is gitignored, so its files show up here.
- `flutter test` — currently **FAILS**. `test/widget_test.dart` is the untouched Flutter template (counter test, expects `Icons.add`, missing `ProviderScope`). Don't trust a green suite; this is the only test.
- Single test: `flutter test test/widget_test.dart`
- `flutter run` (Android only, see below)

No CI, no Cloud Functions, no `firestore.rules`/indexes, empty `README.md`. Rules/indexes live in the Firebase console.

## Platform / Firebase gotchas

- `Firebase.initializeApp()` is called with no options. Android config is `android/app/google-services.json` (committed). There is **no** `firebase_options.dart` and **no iOS `GoogleService-Info.plist`** — iOS/web/macOS builds have no Firebase config.
- Firestore persistence is enabled in `main.dart`.
- RevenueCat key in `lib/services/subscription_service.dart` is a `test_...` (sandbox) key; treat purchases as test-mode. `Purchases.logIn(uid)`/`logOut()` are wired into auth in `auth_service.dart`.

## Architecture

- Layers: `models/` → `services/` → `providers/` → `views/` → `widgets/`. Widgets must not import services directly; views orchestrate via Riverpod.
- Two state styles coexist: legacy GPS/offline state is `setState` inside `_DashboardViewState` (`lib/views/dashboard_view.dart`); newer network features (auth, subscription, friends, sharing, scores) use Riverpod providers in `lib/providers/`.
- Singletons (factory-constructor, do not create parallel instances) and their in-memory caches: `AudioService`, `EdsStorageService`, `EdsGeofenceService`, `DrivingScoreService`, `SubscriptionService`.

## Domain invariants

- All user-facing strings are Turkish. TTS language is hardcoded `tr-TR`. Never add English UI text.
- Default speed limit is `82` km/h (Turkish EDS standard).
- GPS stream uses `distanceFilter: 2` m; distance math assumes sequential ~2 m updates.
- Geofence constants in `lib/services/eds_geofence_service.dart`: bounding box `0.006°` (tuned for ~38°N Turkey), trigger 500 m, end 100 m, heading tolerance 45°. `checkAutomaticStop` requires `distanceTraveledMeters >= 500` — do not lower it.
- Storage keys are per-user: `custom_eds_points_<uid>` (`EdsStorageService`) and `driving_scores_<uid>` (`DrivingScoreService`), falling back to `guest`. On auth change call `EdsStorageService().clearCache()` then `EdsGeofenceService().reloadPoints()` (already done in `auth_service.dart`).
- `EdsStorageService` caches points in `_cachedPoints`; invalidate with `clearCache()`, not by re-reading. After saving/deleting a custom point, call `_geofenceService.reloadPoints()`.
- Pro status: check RevenueCat `CustomerInfo.entitlements.all["pro"]?.isActive` via `isProProvider` (`lib/providers/subscription_provider.dart`). Never read Firestore `isPro` (it is server-side only; `UserProfile.toFirestore()` hardcodes `isPro: false`).
- `community_points` is read by lowercased `region` + `orderBy('upvotes')` + `limit` with `startAfterDocument` pagination (`sharing_service.dart`). A `geoHash` field is stored but prefix queries are not implemented.

## Model quirks

- `EdsPoint` has no `==`/`hashCode` and no `copyWith`: compare via `id` or `hasSameCoordinates()`, and construct a full new instance to edit. JSON defaults `speedLimit` to 82.
- `SpeedData` has no `==`.
- `SpeedStatus` enum lives in `lib/theme/design_tokens.dart`, not a model.

## Dashboard change-safety rules (`lib/views/dashboard_view.dart`)

- Do not put TTS/audio calls inside `setState`, and do not wrap GPS-listener computation in `setState` — only final display assignments trigger rebuilds.
- Keep `_speedSubscription?.cancel()` at the top of `_startListeningToGPS()` to prevent double subscription.
- `_totalDistance` defaults to `10.0` km as a mock when no corridor is active.
- Wrap all TTS calls in try/catch; TTS fails silently without a Turkish voice pack.
- Prefer `MediaQuery.sizeOf(context)` over `MediaQuery.of(context).size`.

## Conventions

- All colors/text styles/decorations come from `lib/theme/design_tokens.dart`; no hardcoded color values elsewhere.
- `flutter_lints` v6 defaults (`analysis_options.yaml`), no custom rules. Existing analyzer noise to avoid adding more: `withOpacity` → `.withValues()`, `Radio.activeColor` → `activeThumbColor`, `TextFormField value` → `initialValue`, empty `catch {}`, `__` unused params, `for` without braces.
- `.gitignore` ignores `*.ps1` and `scratch/` (helper scripts are intentionally uncommitted).
