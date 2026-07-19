# ⚡ Performance & Rendering

> Governs how Car and Pain stays at a jank-free frame budget on low-end OEM hardware by executing Flutter's rendering defaults rigorously — Impeller, const/RepaintBoundary discipline, lazy lists, off-thread compute, and local-image handling — validated by profiling and an automated janky-frame CI gate.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md) · [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md) · [Testing Strategy](./11-testing.md)

## Decision

Do not chase exotic optimizations. We win by executing Flutter's defaults rigorously for **this app's specific hot paths**: (1) keep **Impeller** as-is (mandatory on iOS/Metal, default on Android API 29+/Vulkan with automatic OpenGL fallback) and rely on its build-time shader precompilation to kill first-scroll/first-chart jank; (2) be ruthless about `const` + granular rebuilds + `RepaintBoundary`; (3) render every long fuel/service/log list with `ListView.builder`/`SliverList` and a fixed `itemExtent`; (4) push **every** heavy computation — TCO, economy, statistics/rollups, backup serialization, thumbnail decode, chart downsampling — off the UI thread via `Isolate.run` keyed off a revision counter, and run encrypted-DB queries on Drift's background isolate; (5) treat attachments as **local files** (`Image.file` + `ResizeImage`/`cacheWidth` + pre-baked thumbnails), never `cached_network_image`; (6) keep startup lean by deferring DB open and module init past first frame and subsetting the RTL fonts; and (7) validate by profiling in **PROFILE mode on real low-end devices** with a week-one Impeller check and an automated `integration_test` janky-frame assertion. No new heavyweight rendering packages — only `fl_chart` (validated, wrapped, isolate-downsampled) and built-in Flutter primitives.

## Why

The mental model is the **two-thread pipeline**: the UI/Dart thread builds widgets, the raster thread rasterizes. Any TCO/economy/stats math that runs synchronously in `build()` or a tap handler blocks frame production and janks. The budget is **16 ms/frame at 60 Hz** (8 ms at 120 Hz). For an offline, account-free, no-telemetry app the biggest wins are boring and universal, so we spend our effort there instead of on cleverness.

Alternatives considered and rejected:

- **Rendering engine — Impeller vs opting out to Skia.** Impeller precompiles all shaders at build time, eliminating the runtime shader-compilation stutter that historically hit exactly when a user opens a chart or animates a list. A handful of OEM GPUs/older drivers have had Impeller-specific visual bugs, and custom fragment shaders / backdrop-blur can render subtly differently. **Verdict: keep Impeller** (it is mandatory on iOS and the Android default anyway); treat `EnableImpeller=false` in `AndroidManifest.xml` purely as a per-device escape hatch, and explicitly test the OpenGL-fallback path on a pre-API-29 / non-Vulkan device.
- **Heavy math — `Isolate.run` vs `compute()` vs long-lived isolate vs `worker_manager`.** `Isolate.run` spawns a short-lived isolate, runs one callback, returns via ownership transfer, and auto-exits — ideal for one-shot TCO recompute, stat aggregation, chart downsampling, and backup serialization. `compute()` is only needed for web parity (we are mobile-only). Long-lived workers add lifecycle complexity. **Verdict: default to `Isolate.run`; let Drift run queries on its own background isolate; only add a long-lived worker if profiling shows spawn overhead dominating a frequently-repeated job.**
- **Attachments — local `Image.file`/`ResizeImage`/thumbnails vs `cached_network_image`.** Receipts and odometer photos live in an on-device encrypted store, so decoding is local. `cached_network_image` solves a network-caching problem we don't have. **Verdict: local `Image.file` + `ResizeImage`/`cacheWidth` + pre-generated thumbnails + a tuned `ImageCache`.**
- **Long lists — non-lazy `ListView(children:)`/`Column` vs `.builder`/slivers.** A non-lazy list builds every off-screen row up front and janks. **Verdict: always `ListView.builder` with fixed `itemExtent`; graduate to `CustomScrollView` + `SliverList` + `SliverAppBar` for module dashboards with a collapsing header.**
- **Charts — `fl_chart` vs hand-rolled `CustomPaint` vs Syncfusion.** `fl_chart` is pure-Dart, offline, telemetry-free. Syncfusion is heavier and license-encumbered — wrong for a lean buy-once app. **Verdict: `fl_chart` with isolate-downsampled series and a `RepaintBoundary`; reach for `CustomPaint` only for a bespoke perf-critical viz.**

## How we do it

### Package list

```yaml
# apps/car_and_pain / packages/design_system — pubspec.yaml (versions pinned at kickoff)
dependencies:
  fl_chart: ^x.y.z          # validated/wrapped; isolate-downsampled series only
dev_dependencies:
  very_good_analysis: ^x.y.z  # enforces prefer_const_constructors + perf lints
  integration_test:
    sdk: flutter            # traceAction + TimelineSummary jank gate
# Built-in, no package: dart:isolate (Isolate.run), ResizeImage, cacheWidth,
# ImageCache, precacheImage, RepaintBoundary. NO cached_network_image.
# flutter_image_compress ONLY if a decode-in-isolate thumbnail step needs it.
```

### const + granular rebuilds

```dart
// DO: a const StatelessWidget subclass — the instance is reused, build() short-circuits.
class FuelRow extends StatelessWidget {
  const FuelRow({required this.entry, super.key});
  final FuelEntry entry;
  @override
  Widget build(BuildContext context) => const SizedBox(); // ...
}

// DON'T: a widget-returning helper method — reruns on every parent build.
Widget _buildFuelRow(FuelEntry e) => Container(/* rebuilt each frame */);
```

Split the parts that change (a running total, a filter toggle) into their own small widget with a localized `setState` / `ValueListenableBuilder` / Riverpod `select`, so a value change never rebuilds the whole screen. Pass expensive **static** subtrees through the `child:` slot of `AnimatedBuilder`/`ListenableBuilder` so they are built once and reused across ticks.

### RepaintBoundary discipline

```dart
// Each chart and each independently-updating row gets its own boundary,
// so a parent rebuild (e.g. a filter toggle) does not repaint siblings.
RepaintBoundary(
  child: TcoTrendChart(series: downsampledSeries), // fl_chart inside
)
```

Wrap each chart, each animated/independently-updating widget, and expensive list-row content. Do **not** over-apply — every boundary costs GPU memory.

### Lazy lists with fixed extent

```dart
// Common flat history: fixed-height rows skip per-child measurement.
ListView.builder(
  itemExtent: kFuelRowHeight, // or prototypeItem: for uniform rows
  itemCount: entries.length,  // always pass a count so scroll is estimable
  itemBuilder: (context, i) => FuelRow(entry: entries[i]),
);

// Module dashboard: collapsing header + summary cards + list.
CustomScrollView(slivers: [
  const SliverAppBar(pinned: true, /* ... */),
  SliverList(delegate: SliverChildBuilderDelegate(
    (context, i) => FuelRow(entry: entries[i]),
    childCount: entries.length,
  )),
]);
```

### Off-thread heavy math (keyed off a revision counter)

```dart
// Pass plain data IN, return a plain result. No widgets/handles/BuildContext.
final tco = await Isolate.run(() => computeTco(inputsCopy));

// Same pattern for statistics aggregation, chart downsampling, and
// single-file backup export/import serialization.

// If an isolate must touch a plugin or Drift, hand it a RootIsolateToken:
final token = RootIsolateToken.instance!;
await Isolate.run(() {
  BackgroundIsolateBinaryMessenger.ensureInitialized(token);
  // ... plugin/DB work ...
});
```

Recompute is **revision-keyed**: TCO/economy/stats read from the pre-aggregated rollup tables and only re-run the affected slice when the ledger's revision counter changes — never a full-history recompute on the UI thread (see [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)). Encrypted-DB reads do real CPU work for SQLCipher decryption, so they run on Drift's background isolate and never block `build()`.

### Memoize computed and formatted values

```dart
// RTL/calendar/numeral formatting is per-frame expensive: Jalali/Hijri
// conversion + Eastern-Arabic numeral shaping + bidi. Format once, cache.
final _labelCache = <int, String>{}; // keyed by (epochMillis, locale, calendar)
String label(int epochMillis) =>
    _labelCache.putIfAbsent(epochMillis, () => formatJalali(epochMillis));
```

Recompute only when the underlying records change.

### Local image downsizing

```dart
// Decode at DISPLAY resolution, not full 12MP camera resolution.
Image.file(thumbFile, cacheWidth: 96);           // list thumbnails
// or
Image(image: ResizeImage(FileImage(file), width: 96));

// Full-res only on a detail/zoom screen; warm it before navigating:
await precacheImage(FileImage(fullFile), context);

// Tune the cache once at startup for an attachment-heavy app.
PaintingBinding.instance.imageCache
  ..maximumSize = 100
  ..maximumSizeBytes = 100 << 20; // ~100 MB
```

Generate and store a small thumbnail **at capture time** (decode-in-isolate or `flutter_image_compress`), show thumbnails in lists, full-res only on detail/zoom.

### Avoid save-layer traps

Prefer `color.withValues(alpha:)` over the `Opacity` widget; use `AnimatedOpacity` for animated fades; avoid `ShaderMask`/`ColorFilter`/`Opacity` wrapping large subtrees. Enable `checkerboardOffscreenLayers` while profiling to spot `saveLayer()` calls.

### Startup deferral

```dart
void main() {
  runApp(const SplashGate()); // fast first frame
}
// After first paint: open encrypted DB, load module state, warm caches.
WidgetsBinding.instance.addPostFrameCallback((_) => bootstrapHeavyInit());
```

Keep `main()` tiny; do not parse or migrate the whole DB synchronously before first paint. Ship release builds with `--split-debug-info --obfuscate` and subset the RTL fonts.

## Rules

- **Do** enable `prefer_const_constructors` and `prefer_const_literals_to_create_immutables` (via `very_good_analysis`) and treat their violations as CI failures (`flutter analyze`).
- **Do** prefer `StatelessWidget` subclasses over widget-returning helper methods.
- **Do** wrap every chart and every independently-repainting widget in a `RepaintBoundary` — but never blanket-wrap; each costs GPU memory.
- **Do** use `ListView.builder`/`SliverList` with `itemExtent` (or `prototypeItem`) and an explicit `itemCount`/`childCount` for every list. **Don't** ship a non-lazy `ListView(children:)`/`Column` for any list that can grow.
- **Don't** run any non-trivial loop over records (TCO, economy, stats, aggregation, serialization) synchronously in `build()` or an event handler — route it through `Isolate.run`.
- **Don't** decode full-resolution attachment photos into list rows — always `cacheWidth`/`ResizeImage` + a pre-baked thumbnail.
- **Don't** add `cached_network_image`, Syncfusion, or `google_fonts` (network fetch — violates offline/no-telemetry).
- **Don't** wrap large subtrees in `Opacity` or override `operator==` on widgets to skip rebuilds (O(N²) diffing) — use `const` and `withValues(alpha:)`.
- **Do** cache/memoize RTL/calendar/numeral-formatted strings; **don't** reformat Jalali/Hijri dates or Eastern-Arabic numerals on every rebuild/scroll.
- **Do** profile only in `--profile` mode on real low-end hardware; **never** benchmark in debug or on an emulator.
- **Do** keep the automated `integration_test` janky-frame gate green in CI (see [Testing](#testing)).

## For Car and Pain specifically

- **Offline-first / encrypted DB reshapes the profile.** Attachments are local files (so `ResizeImage`/thumbnails, not `cached_network_image`), and encrypted-DB reads do real decryption CPU work — they run on Drift's background isolate and never block `build()`. The signature heavy math (TCO, fuel-economy, on-device statistics) is routed through `Isolate.run`, memoized, and recomputed only when the underlying rollup revision changes, so charts and TCO screens don't recompute on every rebuild.
- **RTL / i18n add per-frame text cost.** Full RTL (Persian/Arabic/Sorani), bidi isolation, layout mirroring, multi-calendar conversion (Gregorian/Jalali/Hijri), and Eastern-Arabic numeral shaping are genuinely expensive per frame — cache formatted strings and verify complex-script glyph rendering under Impeller on real Android OEM devices, because Impeller's text path differs from Skia's and the OpenGL fallback on pre-API-29 hardware must be tested explicitly.
- **No-telemetry is a perf asset.** No analytics/ad SDKs steal frames or slow cold start — keep it that way, ship `--split-debug-info --obfuscate`, and subset the RTL fonts to control both binary size and first-paint time.
- **~25 feature modules** argue for deferring per-module init and DB open past the first frame behind a splash gate.
- **Impeller's build-time shader compilation is especially valuable here** because the first chart render and first list/page transition won't stutter the way they did under Skia's runtime shader warm-up.

## Testing

- **Profile in `--profile` on the slowest real target** — a budget Android OEM phone (where battery-killers, Doze, and the OpenGL Impeller-fallback live) and an older iPhone. Never debug mode, never an emulator.
- **DevTools timeline + performance overlay:** bottom graph = UI/Dart thread, top = raster/GPU, white line = 16 ms, red bars = dropped frames. If the bottom graph is red, open the CPU Profiler to find the expensive (likely un-isolated) Dart function; if the top graph is red, set `debugRepaintRainbowEnabled` + `checkerboardOffscreenLayers` to spot needless repaints and `saveLayer()` calls.
- **Track Widget Rebuilds** (Flutter Inspector / IDE rebuild profiler) to confirm `const`/`RepaintBoundary`/selective-`setState` work is actually pruning rebuilds.
- **Automated jank regression gate** — an `integration_test` that scrolls the long fuel/service list and opens a chart, wrapped in `traceAction`, asserting on `TimelineSummary` janky-frame count and worst build+raster times so regressions fail CI:

```dart
await binding.traceAction(() async {
  await tester.fling(find.byType(ListView), const Offset(0, -3000), 5000);
  await tester.pumpAndSettle();
}, reportKey: 'scroll_timeline');
final summary = TimelineSummary.summarize(timeline);
expect(summary.countFrames(), greaterThan(0));
// assert janky-frame count / worst frame under budget
```

- **RTL/i18n goldens** for layout mirroring and bidi correctness across the three calendars/numeral systems, plus `fl_chart` RTL and chart `Semantics` (see [Testing Strategy](./11-testing.md) and [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)).
- **Cold-start-to-first-frame** measured explicitly, confirming DB open/module init happen after first paint.
- **Binary size** tracked via `flutter build appbundle --analyze-size` and the iOS App Thinning report.
- **Attachment memory** — profile attachment-heavy screens to confirm thumbnails, not full-res photos, are being decoded.

## Pitfalls

- Running TCO/economy/stats compute synchronously in `build()` or a tap handler — blocks the UI thread and janks. Any non-trivial loop over records must be isolated.
- Decoding full-resolution attachment photos into list thumbnails — a few 12 MP decodes overflow the default `ImageCache` (100 images / ~100 MB) and spike raster memory. Always downsample + cache thumbnails.
- Non-lazy `ListView(children:)`/`Column` for long histories — builds every off-screen row up front.
- Wrapping large subtrees in `Opacity` or using it in animations — triggers `saveLayer` offscreen passes; use `withValues(alpha:)` / `AnimatedOpacity`.
- Overriding `operator==` on widgets to skip rebuilds — O(N²) diffing; use `const`.
- `setState` at the top of the tree rebuilding a whole screen on one value change — localize state to the smallest widget.
- Profiling in debug or on an emulator — debug is 10–20× slower with asserts/JIT; results mislead. Also skipping the low-end Android OEM device where Doze/battery-killers and OpenGL fallback live.
- Reformatting Jalali/Hijri dates and Eastern-Arabic numerals on every rebuild/scroll — format once and cache.
- Assuming Impeller matches Skia for custom shaders/blur — verify any `BackdropFilter`/`ShaderMask`/custom fragment shader on real devices including the OpenGL-fallback path.
- Forgetting `RepaintBoundary` around `fl_chart` — a parent rebuild repaints the whole painter needlessly.
- Skipping `--split-debug-info`/`--obfuscate` — larger binary, slower cold start, lost symbolication.
- Bundling full unsubsetted Persian/Arabic/Kurdish font families — inflates size and slows first paint; subset to used glyphs.

## Decisions to confirm

- **Impeller week-one validation:** run the real low-end OEM device matrix (old Adreno/Mali, Arabic/Persian shaping + jank) in week one and record a decision on the Skia-fallback removal timeline before it becomes unavoidable.
- **Font asset-bundling & size budget:** the offline map layer, bundled datasets, and subsetted Vazirmatn/Noto fonts have significant binary-size implications; decide the asset-bundling and size-budget strategy separately, since it affects startup performance and store download limits.

## Related

- [Local Database, Schema, Indexing & Migrations](./03-data-persistence.md) — Drift background isolate, rollup tables, revision-keyed recompute.
- [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md) — the per-frame text cost we memoize; RTL goldens.
- [Testing Strategy](./11-testing.md) — the automated janky-frame gate and golden matrix.
- [Build, Tooling, Release & CI/CD](./12-build-ci-release.md) — `--split-debug-info --obfuscate`, size analysis, font subsetting.
- [Backup, Export & Disaster Recovery](./13-backup-export-recovery.md) — export/import serialization offloaded via `Isolate.run`.
- [Reminders & Notifications (product)](../features/04-reminders-notifications.md) — projection compute that must stay off the UI thread.
