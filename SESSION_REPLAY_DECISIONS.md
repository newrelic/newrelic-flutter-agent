# Session Replay (Flutter) — Status & Open Decisions

A snapshot of what's built, what's decided, and the open questions to settle
with the team before going further. Companion docs: `SESSION_REPLAY_DEV.md`
(dev loop), `SESSION_REPLAY_MASKING.md` (masking spec).

---

## 1. What we have today (built, tested, live-validated)

The Flutter agent now produces **real rrweb session replay from the Dart
side** and streams it to a live viewer.

- **Capture**: walks Flutter's `RenderObject` tree → an intermediate rep (IR)
  → rrweb. Per-render-type "thingies" (text, image, box, icon, editable)
  extract content/styles. Offstage + previous-route subtrees are filtered.
- **Stable ids**: same `RenderObject` keeps the same rrweb id across frames
  (Expando-keyed), enabling diffs.
- **Incremental diff**: a Meta + FullSnapshot once, then minimal rrweb
  IncrementalSnapshot mutations per frame (adds/removes/text/attributes,
  per-parent minimal reorder, subtree moves). Validated by an apply-invariant
  test battery + a 1500-seed fuzzer, and **live-validated against the real
  rrweb player** (headless replay confirmed correctness).
- **FrameProcessor**: first-frame full, then incrementals; full resync on
  resize or when a diff is too churny.
- **Touch capture**: pointer events as rrweb interactions.
- **Perf**: ~1.8 ms p95 end-to-end at ~190 nodes (iOS sim; ~2× on Android
  emulator) — well within frame budget at 1 fps.
- **Verified on both iOS and Android.** ~189 tests passing.
- **Dev tooling**: live streaming to the team's `rrweb-live-streaming` viewer
  (kept in a git stash; debug-only).

**Not yet built**: masking/privacy, production transport, image pixels, icon
glyphs, true scroll events.

---

## 2. Decisions already made (rationale)

| decision | why |
|---|---|
| **Dart-side render-tree capture** (not native view capture, not screenshots) | Flutter renders to one canvas; the native agents see only an opaque rectangle. RN can delegate to native because RN renders real native views — Flutter can't. |
| **rrweb wire format** | Matches the iOS/Android agents byte-shape; reuses the same New Relic backend/player. |
| **Capture is transport-agnostic** | `startSessionReplay(onEvent:)` — the callback is the swap point for any transport (socket, native bridge, HTTP). |
| **Masking redacts in Dart, before events leave the device** | Capture is in Dart, so redaction must be too. |

---

## 3. Open decisions — grouped by who needs to weigh in

### A. Product / Strategy

- **A1. Is this targeting a shipped release, and on what timeline?** Drives
  how aggressively to kick off native-team coordination (see C/D).
- **A2. Scope of v1 fidelity.** Minimum bar to ship: is masked-but-correct
  structure enough, or are image pixels + icons required for v1?
- **A3. Web?** Session replay is mobile-only here (Flutter web → browser
  agent). Confirm we're not expected to cover Flutter web.

### B. Transport — **the biggest cross-team dependency**

We produce correct rrweb events in Dart; the open question is how they reach
New Relic.

- **B1. Will the native iOS/Android agents accept and upload
  Flutter-produced rrweb blobs?** This is the pivotal question.
  - **If yes** → add a public native API like `recordSessionReplayEvent(json,
    timestamp)` that feeds the existing native uploader (gzip, batching,
    offline storage, the `sessionreplay` endpoint, retry). Flutter just
    forwards events. Reuses proven infra; **requires native-agent-team work**
    (no such API exists today). Also lets Dart fully defer sampling to native.
  - **If no** → build a **Flutter-side uploader** (gzip + endpoint + batching
    + offline storage in Dart). Unblocks us alone, but duplicates native infra
    **and** means Dart must also honor sampling/recording-mode itself.
  - Our recommendation: **native bridge** (consistent with how every other
    agent ships transport), with an optional interim Dart uploader if we need
    to ship before the native API lands.
- **B2. If a Dart uploader is needed:** what is the exact session-replay
  **ingest endpoint + auth header** format? (Needed to build it.)

### C. Native-agent teams (iOS + Android)

- **C1. Build the masking **config bridge****: a MethodChannel
  `getSessionReplayConfiguration` returning the resolved
  `{enabled, mode, recordingMode, 4 mask booleans, maskedClasses[],
  unmaskedClasses[], maskedKeys[], unmaskedKeys[]}`, plus a harvest-update
  push. The server-driven masking config lives in the native agent; Dart
  needs it. **None of this exists today.**
- **C2. The `recordSessionReplayEvent` ingest API** (same as B1 if we go that
  route).

### D. Recording mode & sampling ownership

- **D1.** Recording mode (`off`/`error`/`full`) and sampling are **owned by
  native** in our plan — Dart just consumes the resolved mode to decide
  whether to run the capture loop. This only holds **if native uploads the
  blobs (B1)**. If Flutter uploads its own, Dart must replicate sampling.
  Confirm alongside B1.

### E. Masking / privacy (detail in `SESSION_REPLAY_MASKING.md`)

- **E1. Build order:** build the **Dart masking engine first**
  (widgets + resolver + redaction + tests, driven by startup-config flags,
  **privacy-on by default**) and wire the native server-config bridge (C1)
  after? Or require the bridge up front? *Recommendation: Dart engine first —
  it's pure Dart, fully testable now, and unblocks privacy-by-default without
  waiting on native.*
- **E2. TextField (input) when explicitly *unmasked* in custom mode:** emit
  the real typed text (matches native), or always withhold user input for
  safety? *Recommendation: withhold unless explicitly unmasked.*
- **E3. Marker mechanism:** back the `NRMaskedRegion`/`NRUnmaskedRegion`/
  `NRBlock`/`NRMaskKey` widgets with a **custom `RenderObject`** the walker
  detects by type (vs an Element-tree side-map). *Recommendation: custom
  RenderObject — robust, no Element back-pointer needed.*
- **E4. `nrKey`** = a dedicated NR field, **not** Flutter's `Widget.key`
  (avoid clobbering app keys). Confirm in API review.
- **E5. Class matching** can only match the **concrete widget runtimeType**
  (Flutter has no cheap runtime supertype chain). Native walks the superclass
  chain. Acceptable limitation? Document it.
- **E6. Config delivery:** native→Dart **push** on harvest update (cleaner,
  more native plumbing) vs Dart **polls** at startAgent + timer.

### F. Backend team — confirm intended defaults

The native code paths disagree on several defaults; we need the single
intended value before hardcoding Flutter:

- **F1.** Masking **mode** default — iOS `custom` vs Android `default`.
- **F2.** `mask_all_user_touches` default — `false` (parse) vs `true`
  (fallbacks).
- **F3.** `error_sampling_rate` default — `100` (parse) vs `0` (iOS runtime
  fallback).
- **F4.** Unmask-list semantics — union (Android) vs replace (iOS).
- **F5.** Custom-rule `type` string — `unmask` vs legacy Android `un-mask`.

*(Our current plan standardizes to: mode=`custom`, touches=`false`,
union, `unmask`. Confirm.)*

### G. Visual fidelity (design choices, deferrable)

- **G1. Images**: rasterize `RenderImage` → PNG → base64 `<img src>` (exactly
  how native does it), default-masked, hash-cached. Accept the "blank for one
  frame while the async encode completes" tradeoff?
- **G2. Icons**: native **rasterizes** icon glyphs (treats them as images)
  rather than embedding fonts. Do the same (rasterize the glyph), or embed the
  Material/Cupertino font? *Recommendation: rasterize — font-agnostic, matches
  native, generalizes to CustomPaint.*
- **G3. PlatformViews** (maps, webviews, native ads) and **CustomPaint**
  (charts, custom drawing): rasterize the subtree, or leave as a placeholder
  box? Rasterizing arbitrary subtrees needs a `RepaintBoundary`/`PictureRecorder`
  pass (more work).

### H. Interaction fidelity (deferrable)

- **H1. True scroll (rrweb `source=3`)**: today a scroll churns many
  adds/removes and trips the full-snapshot resync repeatedly. Emit real scroll
  events instead for cheap, faithful scrolling? (Larger change.)

### I. Player conformance (low risk, worth confirming)

- **I1.** We validated incremental mutations against the live rrweb player
  (headless). Confirm the production **NR1 session-replay player** renders our
  mutations identically (it should — same rrweb engine). Specific assumptions
  to spot-check: mid-list `nextId` inserts, add-of-existing-id-as-move,
  top-of-subtree-only removes.

### J. Upstream build fixes (FYI — may warrant separate PRs)

While getting the example app to run we fixed real, pre-existing build
breakages (not session-replay-specific):

- iOS: duplicate plugin folder reference in `Runner.xcodeproj` (broke SPM);
  Pods `IPHONEOS_DEPLOYMENT_TARGET` below the supported floor.
- Android: AGP/Gradle/`compileSdk` too old for Flutter 3.44
  (`androidx.core:1.18` needs AGP ≥ 8.9.1 / compileSdk 36); a **gitignored
  `network_security_config.xml`** referenced unconditionally by the manifest
  (fresh clones fail AAPT — latent since 2022).

These are committed on the branch; the team may want them as standalone PRs
to `main`.

---

## 4. Suggested immediate path (pending the above)

1. **Build the Dart masking engine now** (E1) — privacy-on by default, fully
   testable, no native dependency.
2. **In parallel, open the native-team conversation** on B1/C1/C2 (transport
   + config bridge) — the long-lead cross-team items.
3. **Defer** image/icon rasterization (G) and true scroll (H) until after
   masking + a transport decision.
