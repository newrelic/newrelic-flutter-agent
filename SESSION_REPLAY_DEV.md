# Session Replay — Live Streaming Dev Setup

This file documents the dev-only loop for previewing Flutter session replay
output in real time using the `rrweb-live-streaming` viewer.

The streaming code is **not committed** to this branch — it lives as a git
stash. This mirrors the pattern used by the Android agent team for the same
debug tool. The committed feature on this branch is the capture pipeline
itself (IR walker, rrweb encoder, thingy registry); the websocket transport
that ships frames to a local viewer is intentionally kept out of source so
no debug-only dependency leaks into production builds.

## Pieces involved

- **`feature/session-replay` branch** — contains the SDK plumbing
  (`lib/src/session_replay/**`, debug dump methods, example app debug
  buttons). Commits `f2ae5f3` and `d7ae8e3`.
- **Stash `socketio-streaming-dev`** — the debug-only transport: the
  `socket_io_client` dependency and the example app's
  `_setupSessionReplayStreaming` wiring (two files: `example/lib/main.dart`,
  `example/pubspec.yaml`). The capture engine itself —
  `SessionReplay.startSessionReplay` (Meta + FullSnapshot, then incremental
  mutations) — is now **committed** on the branch, so the stash only holds the
  socket glue.
- **`rrweb-live-streaming` repo** at
  `~/desktop/newrelic/rrweb-live-streaming` — Socket.IO server (`:3000`)
  and Vite viewer (`:5173`). Owned by the AppExp team.

## Running the loop

1. Apply the stash:
   ```sh
   git stash apply 'stash^{/socketio-streaming-dev}'
   ```
2. Get pub deps (only needed once after a clean stash apply):
   ```sh
   cd example && flutter pub get
   ```
3. Start the rrweb server + viewer (concurrent):
   ```sh
   cd ~/desktop/newrelic/rrweb-live-streaming
   npm install     # first time only
   npm run dev
   ```
4. Run the Flutter example app on the iOS simulator:
   ```sh
   cd ~/Desktop/newrelic/newrelic-flutter-agent/example
   flutter run -d <booted-iphone-simulator-id>
   ```
   The app auto-connects to `localhost:3000` on launch (gated behind
   `kDebugMode`) and emits a Meta + FullSnapshot once per second.
5. Open the viewer at <http://localhost:5173>. Every navigation /
   interaction in the simulator updates the viewer within ~1 second.

## Verifying the connection

```sh
curl -s localhost:3000/api/status | jq .hasRecorder    # true
curl -s localhost:3000/api/status | jq .eventCount     # increases over time
```

## Putting changes back in the stash

When you're done iterating, restage the streaming files into the same
stash so the working tree returns to the committed baseline:

```sh
git stash drop 'stash^{/socketio-streaming-dev}'    # if old one still around
git stash push -m socketio-streaming-dev -- \
  lib/src/session_replay/session_replay.dart \
  example/pubspec.yaml \
  example/lib/main.dart
```

## Recreating from scratch if the stash is lost

The capture engine (`SessionReplay.startSessionReplay`) is committed, so the
stash is only the transport glue — two files:

### 1. `example/pubspec.yaml`

```yaml
dependencies:
  ...
  socket_io_client: ^2.0.3
```

### 2. `example/lib/main.dart`

Add the import:

```dart
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
```

Inside `main()`'s `NewrelicMobile.instance.start(config, () { ... })`
callback, after `runApp(...)`:

```dart
if (kDebugMode) _setupSessionReplayStreaming();
```

Then the helper. Two things matter: capture must start ONLY after the socket
connects (the one-time Meta + FullSnapshot base would otherwise be dropped
before the transport is ready, leaving the viewer with incrementals and no
base); and the Android emulator reaches the host at `10.0.2.2`, the iOS
simulator at `localhost`.

```dart
void _setupSessionReplayStreaming() {
  final host =
      PlatformManager.instance.isAndroid() ? '10.0.2.2' : 'localhost';
  final socket = socket_io.io(
    'http://$host:3000',
    socket_io.OptionBuilder()
        .setTransports(['websocket'])
        .setQuery({'type': 'recorder'})
        .build(),
  );

  void emit(RrwebEvent event) {
    if (socket.connected) socket.emit('rrweb-event', event.toJson());
  }

  socket.onConnect((_) {
    socket.emit('recorder-start');
    // (Re)start on each connect so a fresh base snapshot is always sent
    // before any incremental.
    SessionReplay.startSessionReplay(onEvent: emit);
    SessionReplay.startTouchCapture(onEvent: emit);
  });
  socket.onDisconnect((_) => SessionReplay.stopSessionReplay());
}
```

After re-creating: re-stash with the command in the previous section.

## Baseline performance

The plugin exposes `SessionReplay.captureFrameTimings({iterations: 30})`
returning a `FrameTimingStats` with min/p50/p95/max for the three phases
(walk, encode, JSON serialize). A debug button on Page 2 of the example
app calls `dumpCurrentFrameTimings`, printing a one-line report.

### Reference numbers

Captured on **iPhone 17 Pro simulator, M-series Mac, Page 2 of the
example app (~330 widgets, 194 IR nodes)**, plugin commit `1804648` plus
the perf instrumentation. Median of four warm runs (cold first-run
discarded), 30 iterations each:

| phase                   | p50    | p95    | max    |
|-------------------------|--------|--------|--------|
| walk (RenderObject → IR)| 0.36 ms| 0.73 ms| 1.0 ms |
| encode (IR → rrweb)     | 0.13 ms| 0.28 ms| 0.48 ms|
| json serialize          | 0.38 ms| 0.83 ms| 1.03 ms|
| **end-to-end**          | **0.87 ms** | **1.84 ms** | **2.5 ms** |

First (cold) run is ~2-3× slower across all three phases due to JIT
warmup and first-time allocations. After warmup the numbers above are
stable across runs.

### Caveats

- **Simulator on M-series Mac is optimistic.** Real iPhone/Android
  devices will likely be 2-3× slower on the same code. Numbers above
  are for **regression detection**, not for "are we under production
  budget?" — that requires real-device measurement (deferred).
- **Debug build.** Release builds use AOT compilation and tree-shake;
  expect somewhat different numbers (often faster steady-state).
- **194 IR nodes** is a moderately complex screen. A list/grid screen
  with hundreds of cells will have far more nodes, and timings should
  scale roughly linearly with `IR nodes` for walk and encode.

### Targets

For relative comparisons going forward (sim, debug, this code path):

| metric             | green   | yellow  | red          |
|--------------------|---------|---------|--------------|
| walk p95           | < 2 ms  | 2-5 ms  | > 5 ms       |
| encode p95         | < 1 ms  | 1-3 ms  | > 3 ms       |
| json p95           | < 2 ms  | 2-5 ms  | > 5 ms       |
| **end-to-end p95** | < 5 ms  | 5-10 ms | > 10 ms      |

A new thingy or encoder change adding 0.5+ ms to any phase deserves
investigation. We currently have ~3× headroom in the green band.

## Android verification

The capture pipeline is meant to be platform-agnostic (it walks Flutter's
`RenderObject` tree, which is framework-level, above the Skia/Impeller
rasterizer). Verified on an Android emulator (Pixel 8, API 36) by running
the example app and using the debug dump buttons on Page 2 — no streaming,
just `debugPrint`.

Result: **the walker works on Android with no code changes.** Same IR
structure, same thingies fire, valid rrweb JSON, comparable performance.

### iOS sim vs Android emulator (same Page 2 screen)

| metric            | iPhone 17 Pro sim | Pixel 8 emulator (API 36) |
|-------------------|-------------------|---------------------------|
| viewport (logical)| 402 × 874         | 411 × 914                 |
| walk p95          | 0.73 ms           | 1.85 ms                   |
| encode p95        | 0.28 ms           | 0.63 ms                   |
| json p95          | 0.83 ms           | 1.09 ms                   |

Android emulator runs ~2× slower than the iOS sim (different graphics
stack + debug build), still well within budget. Node counts differ only
because the example gained debug buttons between the two captures; the
per-widget node cost is consistent.

### Platform difference found: icon glyphs

Material `Icon`s render via `RenderParagraph` with a single private-use
Unicode codepoint. On **Android** that codepoint comes through
`toPlainText()` intact (e.g. the back arrow captured as ``), so our
icon thingy classifies it as `icon`. On **iOS** the same glyph surfaced as
an empty string, so it was classified as an empty paragraph. The icon-font
embedding work (rendering these glyphs in the browser) needs to account for
both: codepoint-present (Android) and codepoint-absent (iOS).

### Android build issues hit during verification

The example app did not build on Android out of the box with Flutter 3.44;
two unrelated breakages:

1. **Toolchain drift (committed).** Flutter 3.44's embedding pulls
   `androidx.core:core-ktx:1.18.0` (compiled against API 36), which requires
   AGP ≥ 8.9.1 and `compileSdk` ≥ 36. The example pinned AGP 8.6.0 /
   compileSdk 34. Bumped AGP → 8.9.1, Gradle wrapper → 8.11.1, and compileSdk
   → 36 in both the example app and the plugin module. Flutter's Gradle
   migrator also appended `android.builtInKotlin=false` / `android.newDsl=false`
   to `example/android/gradle.properties` during the build; kept.
2. **Missing resource — `network_security_config.xml` (NOT committed).**
   `AndroidManifest.xml` references `@xml/network_security_config`
   unconditionally, but `example/.gitignore` *deliberately ignores* that exact
   path. So a fresh clone has the manifest reference without the resource and
   fails AAPT (`resource xml/network_security_config not found`) — latent since
   2022. For this verification a local file permitting cleartext was created
   (kept out of git, per the existing ignore rule, so it does not appear in any
   commit). **Open decision:** the unconditional-reference-vs-gitignored-file
   mismatch is a real latent bug. Resolving it (commit a checked-in default,
   ship a `network_security_config.xml.template` + copy step, or make the
   manifest attribute conditional / drop it) is left open rather than silently
   overriding the deliberate ignore rule. To build the example on Android
   today, create
   `example/android/app/src/main/res/xml/network_security_config.xml` with a
   `<network-security-config>` permitting cleartext.

### Capture-harness note (Android only)

`debugPrint` output is interleaved in logcat with the native New Relic
agent's own log lines (`I/newrelic(...)`), and Android's `debugPrint` can
throttle/drop lines under a large burst. When extracting the JSON dump from
`flutter run` logs, filter to `^I/flutter` lines first, then strip the
`I/flutter ( PID): ` prefix. The Socket.IO streaming path avoids this
entirely (events go over the socket, not the log).

## Notes & limitations

- iOS simulator reaches `localhost:3000` on the host Mac directly. A real
  iOS device would need the Mac's LAN IP plus a network reachable from
  the device — adjust the `socket_io.io` URL accordingly.
- Each tick emits a fresh Meta + FullSnapshot. Real `IncrementalSnapshot`
  diffing isn't implemented yet — the viewer effectively flips between
  full snapshots once per second. Fine for the dev loop; not what we'd
  ship for production transport.
- Bumping the interval to faster than ~500ms is wasteful right now
  because the encoder rebuilds the whole tree each tick.
