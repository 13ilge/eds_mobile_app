# AGENTS.md

## Must-follow constraints

- All user-facing strings (labels, messages, TTS output) MUST be in Turkish. Never introduce English UI text.
- TTS language is hardcoded to `tr-TR`. Audio messages must be natural Turkish sentences.
- `EdsPoint` has no `==`/`hashCode` override — always compare by `point.id`, never by identity.
- `EdsPoint` has no `copyWith` — construct a new `EdsPoint` with all fields when editing.
- `SpeedStatus` enum lives in `lib/theme/design_tokens.dart`, NOT in a model file. Import from there.
- `AudioService`, `EdsStorageService`, `EdsGeofenceService` are all singletons (factory constructor pattern). Never create parallel instances. These singletons stay as-is for the offline/GPS layer.
- `EdsStorageService` caches points in-memory (`_cachedPoints`). After any external modification to SharedPreferences, call `loadCustomPoints()` to invalidate the cache — but this only works because the singleton's cache is the single source of truth.
- After saving/deleting a custom EDS point, you MUST call `_geofenceService.reloadPoints()` to sync the geofence active list.
- Default speed limit is `82` km/h. This is the Turkish EDS standard, not arbitrary.
- GPS stream uses `distanceFilter: 2` (meters). All distance calculations assume sequential position updates at ~2m intervals.
- **Pro status MUST be checked via RevenueCat `CustomerInfo.entitlements.active["pro"]`**, never via Firestore `users/{uid}/isPro`. Firestore `isPro` is only for server-side (Cloud Functions / Security Rules), updated by RevenueCat webhooks.
- **`community_points` Firestore reads MUST use GeoHash prefix query + `limit()` pagination.** Never fetch the entire collection.

## Repo-specific conventions

- **Layer structure**: `models/` → `services/` → `providers/` → `views/` → `widgets/`. No cross-layer violations (e.g., widgets must not import services directly; views orchestrate via Riverpod providers).
- **State management**: Riverpod (`flutter_riverpod`) is the approved state management solution. Used for new network-dependent features (auth, subscription, friends, sharing). Mevcut GPS/offline singletons remain unchanged.
  - New views that consume auth/subscription/friend state MUST use `ConsumerWidget` or `ConsumerStatefulWidget`.
  - Pro gate checks: always `ref.watch(isProProvider)`, never direct Firestore read.
- **Design tokens**: All colors, text styles, and card decorations come from `lib/theme/design_tokens.dart`. Do not use hardcoded color values outside this file.
- **Geofence coordinates are for Turkey** (~38°N lat). Bounding box pre-filter uses `0.006°` threshold — do not change this value without recalculating for the target latitude.
- `EdsDataRepository.malatyaEdsPoints` contains hardcoded reference points. Custom user points are stored via `EdsStorageService` in SharedPreferences under key `custom_eds_points`.

## Important locations

- Entry point: `lib/main.dart` — app class is `KoridorApp`, wrapped in `ProviderScope`
- All GPS processing + setState logic: `lib/views/dashboard_view.dart` (`_startListeningToGPS`)
- Geofence start/stop logic: `lib/services/eds_geofence_service.dart`
- Persistent storage (custom points + audio mode): `lib/services/eds_storage_service.dart` and `lib/services/audio_service.dart` (both use SharedPreferences)
- Hardcoded EDS reference data: `lib/services/eds_data_repository.dart`
- Riverpod providers: `lib/providers/` (auth, subscription/isPro, user profile, friends, sharing)
- Dead files (0 bytes, no imports): `widgets/action_card.dart`, `widgets/average_speed_hero_card.dart`, `widgets/route_progress_bar.dart`

## Change safety rules

- Do NOT move audio/TTS calls inside `setState` — they were intentionally extracted to avoid blocking UI rebuilds.
- Do NOT wrap GPS listener computation in `setState`. Only final display-value assignments trigger rebuilds.
- `_speedSubscription?.cancel()` at the top of `_startListeningToGPS()` prevents double-subscription. Do not remove this guard.
- `checkAutomaticStop` requires `distanceTraveledMeters < 500.0` guard to prevent immediate corridor exit on entry. Do not lower this threshold.

## Known gotchas

- `_totalDistance` defaults to `10.0` km — this is a mock value used when no corridor is active. Progress bar will show incorrect values during manual tracking.
- TTS may fail silently on devices without Turkish language pack installed. All TTS calls must be wrapped in try/catch.
- `MediaQuery.of(context).size` registers rebuild dependency on all MediaQuery changes. Prefer `MediaQuery.sizeOf(context)` in widgets.
- Mevcut dashboard state `_DashboardViewState` içinde yaşıyor (GPS/offline katman). Auth/subscription/friends gibi yeni ağ-bağımlı state ise Riverpod provider'ları üzerinden yönetilir.
- RevenueCat `Purchases.logIn(firebaseUid)` auth giriş sırasında, `Purchases.logOut()` çıkış sırasında çağrılmalıdır. Yoksa abonelik durumu yanlış kullanıcıya bağlanır.
