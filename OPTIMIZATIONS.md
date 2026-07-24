# EDS Mobile App — Full Optimization Audit

> Audited: **24 July 2026**  
> Scope: All Dart source files under `lib/`  
> Files reviewed: 14 (including 3 empty dead files)

---

## 1) Optimization Summary

**Current health**: The codebase is small and architecturally sound (clean layer separation), but has several **performance-critical issues in its GPS hot path** — the code that runs every ~2 meters of vehicle movement. The UI layer also has unnecessary rebuild volume and the project carries dead code from refactoring iterations.

### Top 3 Highest-Impact Improvements

1. **Massive `setState()` scope in GPS listener** — the entire `_startListeningToGPS` callback is wrapped in a single `setState` that rebuilds the full widget tree on every GPS tick (~every 2m at highway speed = dozens of rebuilds/sec). This is the single biggest performance drain.
2. **Repeated `SharedPreferences.getInstance()` calls** — awaited from disk on every `setMode()`, `loadMode()`, save, delete. The instance should be cached once.
3. **Geofence scan is O(n) on every GPS tick** — `Geolocator.distanceBetween()` (haversine trig) is called 2–4× per EDS point per tick even when no corridor is active.

### Biggest Risk If No Changes Are Made

Battery drain and UI jank on mid/low-end Android devices while driving at highway speed, where GPS updates can fire 5–20×/sec. The current architecture will cause dropped frames, delayed audio warnings, and excessive CPU/battery use — exactly the situation this app is designed for.

---

## 2) Findings (Prioritized)

### F1: Excessive `setState` Scope in GPS Hot Path

* **Category**: Frontend / CPU
* **Severity**: **Critical**
* **Impact**: Frame rate, battery, CPU
* **Evidence**: [dashboard_view.dart L110–L195](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L110-L195) — the entire GPS listener callback body is inside `setState(() { ... })`, including geofence checks, distance calculations, audio service calls, and snackbar triggers.
* **Why it's inefficient**: `setState` marks the widget dirty and schedules a full rebuild of `_DashboardViewState.build()`. At highway speed with `distanceFilter: 2`, this fires potentially dozens of times per second. Most of the work inside (geofence checks, distance math, audio calls) does NOT need to trigger a rebuild — only the final UI state values (`_currentLiveSpeed`, `_averageSpeed`, `_currentStatus`, `_currentDistanceMeters`) need to trigger a repaint.
* **Recommended fix**:
  1. Move all computation **outside** `setState`.
  2. Call `setState` only at the end with the minimal set of changed values.
  3. Better yet, extract the tracking state into a `ValueNotifier` / `ChangeNotifier` and use `ValueListenableBuilder` or `AnimatedBuilder` to rebuild only the affected widgets.
* **Tradeoffs / Risks**: Requires restructuring the listener, but logic stays the same.
* **Expected impact**: ~60–80% reduction in unnecessary widget rebuilds during active tracking.
* **Removal Safety**: Safe
* **Reuse Scope**: module (views layer pattern)

---

### F2: `SharedPreferences.getInstance()` Called Repeatedly

* **Category**: I/O
* **Severity**: **High**
* **Impact**: Latency on every audio mode change, storage save/delete
* **Evidence**:
  - [audio_service.dart L30](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/audio_service.dart#L30) and [L37](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/audio_service.dart#L37) — `getInstance()` called in both `_loadMode()` and `setMode()`
  - [eds_storage_service.dart L14](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/eds_storage_service.dart#L14) and [L48](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/eds_storage_service.dart#L48) — `getInstance()` called in `loadCustomPoints()` and `_savePointsToPrefs()`
* **Why it's inefficient**: `SharedPreferences.getInstance()` performs platform channel I/O on first call, and while subsequent calls return a cached future internally, the repeated `await` still adds unnecessary async overhead and obscures that a singleton is being used. More critically, `loadCustomPoints()` is called inside `saveCustomPoint()` and `deleteCustomPoint()`, creating a read-modify-write pattern that hits the prefs twice per operation.
* **Recommended fix**: Cache the `SharedPreferences` instance in a field initialized once (e.g., in a static `init()` method or `late final` with a completer).
* **Tradeoffs / Risks**: Need to ensure `init()` is called before any access — trivial with `WidgetsFlutterBinding.ensureInitialized()`.
* **Expected impact**: Eliminates 4 redundant async hops per save/delete cycle, ~20–50ms per operation on low-end devices.
* **Removal Safety**: Safe
* **Reuse Scope**: service-wide

---

### F3: O(n) Geofence Scan with Heavy Trig on Every GPS Tick

* **Category**: Algorithm / CPU
* **Severity**: **High**
* **Impact**: CPU, battery, latency
* **Evidence**: [eds_geofence_service.dart L25–L66](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/eds_geofence_service.dart#L25-L66) — `checkAutomaticStart()` iterates over all EDS points and calls `Geolocator.distanceBetween()` (haversine with `sin/cos/sqrt`) 2–4 times per point, on every GPS update.
* **Why it's inefficient**: With N EDS points, this is O(N) haversine calls per tick. Currently N=2 which is fine, but the app supports user-added custom points, so N is unbounded. Even at N=2, calling `distanceBetween` 4–8 times per GPS tick (at 5–20 ticks/sec) is ~20–160 haversine computations/sec — measurable on budget devices.
* **Recommended fix**:
  1. **Coarse bounding-box pre-filter**: Before haversine, check if the point is within ±0.01° lat/lng (~1.1 km) — a simple comparison is 1000× cheaper than haversine.
  2. **Skip geofence checks when a corridor is already active** (already partially done in dashboard, but the method is still called).
  3. For large N: use a spatial index (R-tree or geohash grid).
* **Tradeoffs / Risks**: Bounding box has edge cases near poles/antimeridian — irrelevant for Turkey.
* **Expected impact**: 80–95% reduction in trig calls during non-corridor driving.
* **Removal Safety**: Safe
* **Reuse Scope**: service-wide

---

### F4: Audio Service Fire-and-Forget Without Error Handling

* **Category**: Reliability
* **Severity**: **High**
* **Impact**: Silent failures, unhandled exceptions
* **Evidence**: [dashboard_view.dart L173–L181](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L173-L181) — `AudioService().speakViolation()`, `.speakSafe()`, `.speakMilestone()` are called without `await` or `.catchError()` inside the `setState` callback. [audio_service.dart L22–L27](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/audio_service.dart#L22-L27) — `_initTts()` is fire-and-forget from the constructor with no error handling.
* **Why it's inefficient**: If TTS fails (engine not installed, language pack missing — common on Turkish-locale budget phones), the future completes with an unhandled exception that can crash the isolate. Also, calling `speak()` inside `setState` means TTS scheduling delays the state update completion.
* **Recommended fix**:
  1. Move audio calls **outside** `setState`.
  2. Add `try/catch` to all TTS calls.
  3. Add error handling to `_initTts()`.
* **Tradeoffs / Risks**: None — strictly additive safety.
* **Expected impact**: Prevents crash-level bugs on devices without TTS support.
* **Removal Safety**: Safe
* **Reuse Scope**: service-wide

---

### F5: Dead Files — 3 Empty Widget Files

* **Category**: Dead Code
* **Severity**: **Medium**
* **Impact**: Maintenance confusion, IDE clutter
* **Evidence**:
  - [action_card.dart](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/widgets/action_card.dart) — 0 bytes, empty
  - [average_speed_hero_card.dart](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/widgets/average_speed_hero_card.dart) — 0 bytes, empty
  - [route_progress_bar.dart](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/widgets/route_progress_bar.dart) — 0 bytes, empty
* **Why it's inefficient**: These are leftover artifacts from iteration. They are listed as "completed" in `progress.md` but are empty. They waste mental overhead when navigating the project and may confuse contributors.
* **Recommended fix**: Delete the 3 files. Update `progress.md` to reflect that these were consolidated into existing widgets.
* **Tradeoffs / Risks**: None — no imports reference them.
* **Expected impact**: Cleaner project, no runtime impact.
* **Removal Safety**: Safe
* **Reuse Scope**: local file
* **Classification**: Dead Code (safe removal)

---

### F6: Unused Design Token Styles

* **Category**: Dead Code
* **Severity**: **Low**
* **Impact**: Minor maintenance overhead
* **Evidence**:
  - `DesignTokens.metricLarge` ([design_tokens.dart L42–L46](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/theme/design_tokens.dart#L42-L46)) — defined but never referenced anywhere in the codebase.
  - `DesignTokens.metricMassive` ([design_tokens.dart L48–L52](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/theme/design_tokens.dart#L48-L52)) — defined but never referenced anywhere in the codebase.
* **Why it's inefficient**: Dead design tokens can mislead developers into thinking they are part of the active design system.
* **Recommended fix**: Remove or mark with `// TODO: unused` for planned features.
* **Tradeoffs / Risks**: May be intended for future use; verify with design plan.
* **Expected impact**: Trivial — cleanliness.
* **Removal Safety**: Safe (no references)
* **Reuse Scope**: local file
* **Classification**: Dead Code (safe removal)

---

### F7: Unused Import in `dashboard_view.dart`

* **Category**: Dead Code
* **Severity**: **Low**
* **Impact**: Minor build/analysis overhead
* **Evidence**: [dashboard_view.dart L14](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L14) — `import '../services/eds_data_repository.dart';` is imported but `EdsDataRepository` is never referenced in this file (it's used only inside `EdsGeofenceService`).
* **Why it's inefficient**: Unused imports increase analysis time and can trigger linter warnings.
* **Recommended fix**: Remove the import.
* **Tradeoffs / Risks**: None.
* **Expected impact**: Cleaner analysis.
* **Removal Safety**: Safe
* **Reuse Scope**: local file
* **Classification**: Dead Code (safe removal)

---

### F8: `_permissionMessage` is `final` but Never Changes — Should be `const` or `static const`

* **Category**: Memory
* **Severity**: **Low**
* **Impact**: Minor allocation per widget instance
* **Evidence**: [dashboard_view.dart L35](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L35) — `final String _permissionMessage = "Konum İzni Gerekli\n(İzin vermek için buraya dokunun)";`
* **Why it's inefficient**: This allocates a new String per state instance. As a `static const`, it would be a compile-time constant.
* **Recommended fix**: Change to `static const String _permissionMessage = ...;`
* **Tradeoffs / Risks**: None.
* **Expected impact**: Negligible — micro-optimization for correctness.
* **Removal Safety**: Safe
* **Reuse Scope**: local file

---

### F9: `print()` Used for Error Logging in Production Code

* **Category**: Reliability / Maintainability
* **Severity**: **Medium**
* **Impact**: Missing error visibility in production
* **Evidence**: [eds_storage_service.dart L26](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/eds_storage_service.dart#L26) — `print('Error decoding custom EDS points: $e');`
* **Why it's inefficient**: `print()` output is lost on release builds with no crash reporting. A corrupted `SharedPreferences` value will silently return an empty list, causing the user's saved EDS points to vanish with no trace.
* **Recommended fix**: Use `debugPrint()` for debug-only output, or integrate a logging package like `logger` or `logging`. Consider showing a user-facing snackbar if decode fails.
* **Tradeoffs / Risks**: Adding a dependency; alternatively use `dart:developer log()`.
* **Expected impact**: Diagnosability of production issues.
* **Removal Safety**: Safe
* **Reuse Scope**: service-wide

---

### F10: 1-Second UI Timer Causes Unnecessary Rebuilds During Manual Tracking

* **Category**: Frontend / CPU / Battery
* **Severity**: **Medium**
* **Impact**: Battery, CPU, frame budget
* **Evidence**: [dashboard_view.dart L246–L248](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L246-L248):
  ```dart
  _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    if (mounted) setState(() {});
  });
  ```
* **Why it's inefficient**: This timer fires a full `setState(() {})` every second to update the elapsed time display. Combined with the GPS listener also calling `setState`, the widget rebuilds up to **20+ times per second**. The timer is only needed for the manual-mode elapsed clock (`MM:SS`), but it rebuilds the entire screen.
* **Recommended fix**:
  1. Use a `StreamBuilder` or `ValueListenableBuilder` scoped only to the elapsed time widget.
  2. Or use `Timer.periodic` but only update a dedicated `ValueNotifier<String>` for the time display.
  3. The timer is also not cancelled on auto-start (only manual start sets it), inconsistency risk.
* **Tradeoffs / Risks**: Minor refactor.
* **Expected impact**: Eliminates 1 full rebuild/sec during manual tracking.
* **Removal Safety**: Safe
* **Reuse Scope**: local file

---

### F11: `EdsPoint` Model Lacks `==`/`hashCode` Override

* **Category**: Algorithm / Reliability
* **Severity**: **Medium**
* **Impact**: Correctness of `indexWhere` in save, potential set/map bugs
* **Evidence**: [eds_point.dart L1–L47](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/models/eds_point.dart) — no `==` or `hashCode` override. Identity comparison is used. [eds_storage_service.dart L32](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/eds_storage_service.dart#L32) — `indexWhere((p) => p.id == point.id)` manually compares by `id` because `==` doesn't work.
* **Why it's inefficient**: Every place that needs to compare points must manually compare by `id`. If someone adds the point to a `Set` or uses it as a `Map` key, it will silently break.
* **Recommended fix**: Override `==` and `hashCode` based on `id`, or use `equatable` / `freezed`.
* **Tradeoffs / Risks**: Adding `==` changes behavior if code relies on identity — unlikely here.
* **Expected impact**: Correctness and cleaner code.
* **Removal Safety**: Needs Verification
* **Reuse Scope**: module (models layer)

---

### F12: Redundant Read-Modify-Write in Storage Service

* **Category**: I/O / Algorithm
* **Severity**: **Medium**
* **Impact**: 2× prefs reads per save/delete
* **Evidence**:
  - [eds_storage_service.dart L30–L38](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/eds_storage_service.dart#L30-L38) — `saveCustomPoint()` calls `loadCustomPoints()` (1 read), modifies, then `_savePointsToPrefs()` (1 read for getInstance + 1 write).
  - [eds_storage_service.dart L41–L44](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/services/eds_storage_service.dart#L41-L44) — `deleteCustomPoint()` does the same.
* **Why it's inefficient**: Each mutation operation reads the full dataset, deserializes, modifies, re-serializes, and writes. The `SharedPreferences` instance is re-acquired each time.
* **Recommended fix**: Cache the points list in memory. Load once on init, modify in-memory, persist asynchronously.
* **Tradeoffs / Risks**: Must handle cold-start race condition (call `init()` before use).
* **Expected impact**: ~50% reduction in I/O per save/delete.
* **Removal Safety**: Safe
* **Reuse Scope**: service-wide

---

### F13: `Geolocator.distanceBetween()` Called in Both `checkAutomaticStart` AND `checkAutomaticStop` Per Tick

* **Category**: CPU / Algorithm
* **Severity**: **Medium**
* **Impact**: Redundant haversine computation
* **Evidence**: When `_isActive` is true and `_activeEdsPoint != null`, the GPS listener calls both `checkAutomaticStart()` (which computes distance to all points) inside the `!_isActive` branch — wait, actually it doesn't: the `if (!_isActive)` guard prevents this. However, `checkAutomaticStop()` is called ([dashboard_view.dart L186](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L186)) and computes `distanceBetween` twice (to start and end). Additionally, the `Geolocator.distanceBetween` on [dashboard_view.dart L140–L143](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L140-L143) computes distance delta per tick. This is fine and necessary.
* **Why it's inefficient**: The `checkAutomaticStop` distances could be computed alongside the distance-delta calculation to avoid duplicate coordinate lookups, but this is a minor point.
* **Recommended fix**: Consider passing already-computed distances to `checkAutomaticStop` if further points are added.
* **Tradeoffs / Risks**: Coupling between dashboard and geofence service increases.
* **Expected impact**: Low — only 2 extra haversine calls per tick.
* **Removal Safety**: Likely Safe
* **Reuse Scope**: module

---

### F14: No Stream Cancellation Safety for GPS Subscription

* **Category**: Reliability / Memory
* **Severity**: **Medium**
* **Impact**: Potential resource leak
* **Evidence**: [dashboard_view.dart L107](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L107) — `_speedSubscription` is set, and cancelled in `dispose()` ([L74](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L74)). However, `_startListeningToGPS()` does not check if a subscription already exists before creating a new one. If `_initializeLocation()` is called multiple times (e.g., on rapid `resumed` lifecycle events), a second subscription would be created while the first is still active, leading to duplicate processing and a leaked subscription.
* **Why it's inefficient**: The guard `_speedSubscription == null` on [L93](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L93) mitigates this, but if `didChangeAppLifecycleState` fires before `_initializeLocation` completes its async work, a race condition is possible.
* **Recommended fix**: Cancel existing subscription in `_startListeningToGPS()` before creating a new one: `_speedSubscription?.cancel();`
* **Tradeoffs / Risks**: None.
* **Expected impact**: Prevents potential double-subscription bug.
* **Removal Safety**: Safe
* **Reuse Scope**: local file

---

### F15: `MediaQuery.of(context).size.height` Called in Multiple Widgets Per Frame

* **Category**: Frontend
* **Severity**: **Low**
* **Impact**: Minor — MediaQuery is cached per frame
* **Evidence**: Called in [average_speed_card.dart L36](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/widgets/average_speed_card.dart#L36), [metric_card.dart L18](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/widgets/metric_card.dart#L18), [action_button.dart L25](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/widgets/action_button.dart#L25).
* **Why it's inefficient**: While `MediaQuery.of` is O(1), it registers the widget as a dependency of `MediaQuery`, causing rebuilds when MediaQuery data changes (e.g., keyboard appears). For driving apps this is less relevant but worth noting.
* **Recommended fix**: Use `MediaQuery.sizeOf(context)` (Flutter 3.10+) which only subscribes to size changes, not all MediaQuery changes.
* **Tradeoffs / Risks**: None.
* **Expected impact**: Prevents unnecessary rebuilds on keyboard/orientation changes.
* **Removal Safety**: Safe
* **Reuse Scope**: service-wide

---

### F16: `_totalDistance` Hardcoded Default of 10.0 km

* **Category**: Reliability
* **Severity**: **Low**
* **Impact**: Incorrect progress bar display before a corridor is entered
* **Evidence**: [dashboard_view.dart L40](file:///c:/Users/ev/Desktop/EDS%20proje/eds_mobile_app/lib/views/dashboard_view.dart#L40) — `double _totalDistance = 10.0;`
* **Why it's inefficient**: If the user starts manual tracking, the progress bar shows distance relative to a phantom 10 km total. The safe-speed calculation (`remainingDistance / remainingTime`) also uses this.
* **Recommended fix**: Default to `0.0`. When manual tracking, hide or disable the progress bar and safe-speed card.
* **Tradeoffs / Risks**: UI logic change needed.
* **Expected impact**: Correctness improvement.
* **Removal Safety**: Needs Verification
* **Reuse Scope**: local file

---

## 3) Quick Wins (Do First)

| # | Finding | Time Estimate | Impact |
|---|---------|---------------|--------|
| 1 | **F5**: Delete 3 empty dead files (`action_card.dart`, `average_speed_hero_card.dart`, `route_progress_bar.dart`) | 2 min | Clean project |
| 2 | **F7**: Remove unused `eds_data_repository.dart` import from `dashboard_view.dart` | 1 min | Clean analysis |
| 3 | **F6**: Remove unused `metricLarge` / `metricMassive` from `DesignTokens` | 2 min | Clean tokens |
| 4 | **F8**: Change `_permissionMessage` to `static const` | 1 min | Correctness |
| 5 | **F14**: Add `_speedSubscription?.cancel()` at top of `_startListeningToGPS()` | 1 min | Prevents double-sub bug |
| 6 | **F9**: Replace `print()` with `debugPrint()` in storage service | 1 min | Release safety |
| 7 | **F15**: Replace `MediaQuery.of(context).size` with `MediaQuery.sizeOf(context)` in 3 widgets | 3 min | Fewer rebuilds |
| 8 | **F4**: Move audio calls outside `setState` and add `try/catch` | 5 min | Crash prevention |

**Total estimated time: ~15 minutes for all quick wins.**

---

## 4) Deeper Optimizations (Do Next)

### D1: Extract Tracking State from `_DashboardViewState` (Fixes F1 + F10)

**Problem**: The dashboard is a 520-line monolith that mixes GPS processing, geofence logic, audio orchestration, timer management, and UI rendering in a single `StatefulWidget`.

**Solution**: Extract a `TrackingController extends ChangeNotifier` that:
- Owns all tracking state (`_currentLiveSpeed`, `_averageSpeed`, `_currentDistanceMeters`, `_currentStatus`, `_isActive`)
- Subscribes to the GPS stream internally
- Notifies listeners only when displayable values change
- Uses `ListenableBuilder` / `AnimatedBuilder` in the widget tree for granular rebuilds

**Impact**: Solves F1 (excessive setState), F10 (timer rebuilds), and improves testability. This is the single highest-ROI architectural change.

---

### D2: Cache `SharedPreferences` Instance (Fixes F2 + F12)

**Solution**: Create a shared `init()` pattern:
```dart
class EdsStorageService {
  static late final SharedPreferences _prefs;
  
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  // ... use _prefs directly everywhere
}
```
Call `EdsStorageService.init()` in `main()` before `runApp()`. Do the same for `AudioService._prefs`.

Also cache the points list in memory inside `EdsStorageService` to eliminate read-modify-write I/O.

---

### D3: Bounding Box Pre-Filter for Geofence (Fixes F3)

**Solution**: Before calling `Geolocator.distanceBetween()`, check:
```dart
bool _isNearby(double lat1, double lng1, double lat2, double lng2) {
  // ~1.1 km at Turkey's latitude
  return (lat1 - lat2).abs() < 0.01 && (lng1 - lng2).abs() < 0.013;
}
```
Only compute haversine if the bounding box check passes.

---

### D4: Add `copyWith` and `==`/`hashCode` to `EdsPoint` (Fixes F11)

**Solution**: Either manually implement or use `equatable` package. Add `copyWith` method to simplify the edit flow in `saved_eds_view.dart`.

---

## 5) Validation Plan

### Benchmarks

1. **GPS callback duration**: Wrap the GPS listener body in a `Stopwatch` in debug mode and log the p50/p99 execution time per tick before and after optimizations.
2. **Widget rebuild count**: Use Flutter DevTools "Widget rebuild stats" to count rebuilds per second on the dashboard during active driving. Target: ≤ 5 rebuilds/sec (down from current 20+).

### Profiling Strategy

1. Run `flutter run --profile` on a physical device.
2. Use Flutter DevTools → Performance overlay to check for jank frames during highway driving simulation.
3. Use Flutter DevTools → CPU Profiler to identify hot functions.
4. Use `dart:developer Timeline` events to trace geofence check duration.

### Metrics (Before/After)

| Metric | Current (est.) | Target |
|---|---|---|
| `setState` calls/sec during driving | 5–20+ | 1–5 |
| GPS callback execution time | ~2–5ms | < 1ms |
| SharedPreferences reads/save op | 2 | 0 (cached) |
| Haversine calls/tick (no corridor) | 4–8 | 0–2 (with bbox filter) |
| Dead files in project | 3 | 0 |

### Test Cases for Correctness

1. **Average speed calculation**: Verify `distance / time` formula produces correct results with known GPS coordinate sequences.
2. **Geofence auto-start**: Verify corridor detection still triggers within 500m radius after bbox pre-filter is added.
3. **Geofence auto-stop**: Verify stop triggers at endpoint after optimizations.
4. **Audio mode persistence**: Verify mode survives app restart after SharedPreferences caching.
5. **Custom point save/edit/delete**: Full CRUD cycle works after in-memory caching.

---

## 6) Optimized Code / Patches

### Patch 1: Minimal `setState` in GPS Listener (F1)

```dart
// BEFORE (dashboard_view.dart L107-L196)
void _startListeningToGPS() {
  _speedSubscription = _locationService.getLiveSpeedStream().listen((SpeedData data) {
    if (!mounted) return;
    setState(() {
      // ... 85 lines of computation + side effects inside setState ...
    });
  });
}

// AFTER
void _startListeningToGPS() {
  _speedSubscription?.cancel(); // F14 fix
  _speedSubscription = _locationService.getLiveSpeedStream().listen((SpeedData data) {
    if (!mounted) return;

    final newLiveSpeed = data.currentSpeed < 1 ? 0 : data.currentSpeed.round();

    if (!_isActive) {
      final matchedPoint = _geofenceService.checkAutomaticStart(data);
      if (matchedPoint != null) {
        _activateCorridor(matchedPoint, data);
      }
    }

    int newAvgSpeed = _averageSpeed;
    SpeedStatus newStatus = _currentStatus;
    double newDistance = _currentDistanceMeters;

    if (_isActive) {
      // ... all computation here, updating local vars ...
      // ... audio calls here (outside setState) with try/catch ...
    }

    // Only rebuild if display values actually changed
    if (newLiveSpeed != _currentLiveSpeed ||
        newAvgSpeed != _averageSpeed ||
        newStatus != _currentStatus ||
        (newDistance - _currentDistanceMeters).abs() > 10) {
      setState(() {
        _currentLiveSpeed = newLiveSpeed;
        _averageSpeed = newAvgSpeed;
        _currentStatus = newStatus;
        _currentDistanceMeters = newDistance;
      });
    } else {
      // Update internal state without rebuild
      _currentLiveSpeed = newLiveSpeed;
      _currentDistanceMeters = newDistance;
    }
  });
}
```

### Patch 2: Cached SharedPreferences (F2)

```dart
// eds_storage_service.dart
class EdsStorageService {
  static final EdsStorageService _instance = EdsStorageService._internal();
  factory EdsStorageService() => _instance;
  EdsStorageService._internal();

  static const String _storageKey = 'custom_eds_points';
  SharedPreferences? _prefs;
  List<EdsPoint>? _cachedPoints;

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<EdsPoint>> loadCustomPoints() async {
    if (_cachedPoints != null) return List.from(_cachedPoints!);
    
    final prefs = await _preferences;
    final String? jsonString = prefs.getString(_storageKey);
    if (jsonString == null) {
      _cachedPoints = [];
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _cachedPoints = jsonList.map((json) => EdsPoint.fromJson(json)).toList();
      return List.from(_cachedPoints!);
    } catch (e) {
      debugPrint('Error decoding custom EDS points: $e');
      _cachedPoints = [];
      return [];
    }
  }
  
  // ... save/delete update _cachedPoints in-memory and persist async
}
```

### Patch 3: Bounding Box Pre-Filter (F3)

```dart
// eds_geofence_service.dart — add before haversine calls
bool _isWithinBoundingBox(double lat1, double lng1, double lat2, double lng2) {
  // At 38°N latitude (Turkey), 0.005° ≈ 556m for lat, ~440m for lng.
  // Use 0.006° (~670m) as a generous pre-filter for 500m trigger radius.
  const double threshold = 0.006;
  return (lat1 - lat2).abs() < threshold && (lng1 - lng2).abs() < threshold;
}

EdsPoint? checkAutomaticStart(SpeedData currentData) {
  if (currentData.heading < 0) return null;

  for (final point in _activePoints) {
    // Cheap check first
    if (_isWithinBoundingBox(
        currentData.latitude, currentData.longitude,
        point.startLatitude, point.startLongitude)) {
      // Expensive haversine only if bounding box passes
      final distanceToStart = Geolocator.distanceBetween(
        currentData.latitude, currentData.longitude,
        point.startLatitude, point.startLongitude,
      );
      if (distanceToStart <= triggerRadiusMeters) {
        // ... heading check ...
      }
    }
    
    // Same pattern for bidirectional end-point check
    // ...
  }
  return null;
}
```
