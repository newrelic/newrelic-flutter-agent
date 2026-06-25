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

## 2. Decisions already made — alternatives considered & rationale

Two of these were genuine choices among live alternatives (2.1, 2.3); two
were effectively *given/forced* by the goal or by an earlier decision (2.2,
2.4). Recorded here with the rejected options so the team can challenge them.

### 2.1 Dart-side render-tree capture — **genuine choice (3 options)**

How do we capture what's on screen?

- **Native view-tree capture** (what iOS/Android/RN do) — *rejected.* Flutter
  renders its whole UI into a single canvas (`FlutterView`); the native agent
  sees one opaque rectangle. RN can delegate to native only because RN renders
  real native views. This is the blocker that started the investigation.
- **Screenshot per frame** (`RenderRepaintBoundary.toImage()` → `<img>`) —
  *rejected as the base mechanism.* Huge payloads, no semantic DOM (no text,
  no masking granularity, no real incremental diffs — every frame is a full
  image), heavy encode cost. **Not dead**, though: it's the likely fallback
  for opaque subtrees (CustomPaint / PlatformView) — see open question G3.
- **Semantics / accessibility tree** — *rejected.* Too lossy: only accessible
  elements, no precise layout or styling.
- **Render-tree walk** — **chosen.** Semantic rrweb DOM, per-widget masking
  granularity, small diffable payloads. Cost: per-widget mappers ("thingies")
  and blindness inside PlatformViews.

### 2.2 rrweb wire format — **given, not a deliberation**

The original goal was parity with the native agents ("send it in rrweb like
the other agents"), and the New Relic backend + NR1 player already speak
rrweb. A custom/proprietary format would require new ingest + a new player —
never realistic. The only real sub-choices were rrweb *event-shape* details
(e.g. inline vs standalone text nodes on incremental adds — which we initially
got wrong and fixed during live validation).

### 2.3 Transport-agnostic capture — **genuine (low-controversy) choice**

- **Hardcode the transport into the capture layer** — *rejected.* The
  transport decision (B1) is still open; coupling to it would block progress.
- **Callback/sink abstraction** — **chosen.** `startSessionReplay(onEvent:)`
  injects the transport, so socket / native-bridge / HTTP swap freely with no
  change to capture. Separation of concerns; lets us build before transport
  is decided.

### 2.4 Redact (mask) in Dart — **forced by 2.1**

- **Redact natively / at the bridge** — *rejected.* Raw PII (unmasked text and
  pixels) would cross the Dart→native boundary and sit in native memory before
  redaction — a worse privacy posture — and native lacks the Flutter widget
  context to decide what to mask.
- **Redact at the backend / ingest** — *rejected.* Sending raw PII off-device
  defeats the purpose of masking.
- **Redact in Dart** — **chosen (forced).** Capture is in Dart, so the raw
  content is in Dart; redaction must happen there, before serialization, so
  nothing sensitive ever leaves the device.

---

## 3. Open decisions — grouped by who needs to weigh in

### 3.0 The one axis that drives most of this

Masking and transport look like two questions but **collapse into a single
strategic axis: how much does Flutter lean on the native agent vs. stand
alone?** The reasoning:

- **Masking is always done in Flutter** — fixed in every option (native can't
  see the views). Not a decision. What's pluggable is the two *edges* around
  it: where the masking **config** comes from, and how events **get out**
  (transport).
- **Transport choice cascades into config + sampling ownership:**
  - If **native uploads our events** → native also owns sampling +
    recording-mode, and Flutter just *reads* the resolved masking config.
  - If **Flutter uploads its own events** → Flutter must *also* own
    sampling/recording-mode, and either fetch config itself or run on
    app-provided config only.

So the two coherent end-states:

| | **Native-backed** (lean on native) | **Flutter-standalone** |
|---|---|---|
| Masking config | read native-resolved via a bridge | app-provided flags (± own fetch) |
| Transport | native `recordSessionReplayEvent()` → native uploader | Flutter gzip/endpoint/offline/retry |
| Sampling / recording mode | native owns it | Flutter must replicate |
| Reuses proven infra | yes (all of it) | no (rebuild it) |
| Cross-team dependency | yes (esp. iOS) | no (ships solo) |

**The single pivotal question that resolves the axis:** *will the native
iOS/Android agents accept and upload Flutter-produced rrweb blobs?* (B1)
- **Yes** → native-backed is the clear path (consistent with every other
  agent); the work is two native additions — a config *getter* and an event
  *ingest* API.
- **No** → Flutter-standalone is forced; we also need the ingest endpoint/auth
  and must own sampling.

**This does not block starting.** The masking *engine* (Flutter-side
redaction — widgets, marker, resolver, redaction rendering, touch-drop, tests)
is required identically in **both** end-states and depends on **neither** the
config source nor the transport. It can be built now on app-provided
`Config` flags + the programmatic APIs (privacy-on by default); the config
source and transport are wired in later as two pluggable inputs. See §4.

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

- **C1. Masking **config bridge****: a MethodChannel
  `getSessionReplayConfiguration` returning the resolved
  `{enabled, mode, recordingMode, 4 mask booleans, maskedClasses[],
  unmaskedClasses[], maskedKeys[], unmaskedKeys[]}`, plus a harvest-update
  push. No such bridge exists in the Flutter plugin today. **Readability is
  asymmetric** (verified in source):
  - **Android — self-serviceable now.** `AgentConfiguration.getSessionReplayConfiguration()`
    is `public` on a public class (`AgentConfiguration.java:436`), returning
    the resolved `SessionReplayConfiguration`. The plugin already depends on
    the android-agent, so this is a **plugin-only addition, no agent-team
    work** (one detail to confirm: obtaining the live `AgentConfiguration`
    instance). Prototypable immediately.
  - **iOS — blocked on the agent team.** The public `NewRelic.h` exposes only
    the mask/record APIs — **no config getter.** The resolved config lives in
    `NRMAHarvesterConfiguration` / `NRMAHarvestController`, which are **not in
    the public umbrella header**, so a released-framework consumer can't reach
    them. iOS needs a new public getter (e.g. `+ (NSDictionary*) sessionReplayConfiguration`).
  - So C1 is the real iOS long-lead item, while Android can validate
    end-to-end server config early.
- **C2. The `recordSessionReplayEvent` ingest API** (the transport half of the
  axis; same as B1). Required only on the native-backed path; needed on both
  platforms.

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

### F. Backend team — confirm intended *defaults*

Important framing (verified in source): **these disagreements are
default-only.** When the server's `session_replay` block *contains* a field,
both platforms use the server value (iOS reads it at
`NRMAHarvesterConfiguration.m:209/242/196`; Android deserializes present keys
via GSON) — so they **converge once the server speaks.** The defaults bite
only in two windows: before the first `/connect` response, or when a server
response omits a specific field. Worth pinning the intended value anyway,
because each platform is **internally inconsistent**:

- **F1. Masking `mode` default.** iOS: present-block-without-`mode` →
  `"default"` (`m:212`); no-config / hardcoded-default paths → `"custom"`
  (`m:303`, `m:354`). Android: `SessionReplayConfiguration.java:75` = `"default"`
  but `MobileSessionReplayConfiguration.java:77` = `"custom"`. Both platforms
  split.
- **F2. `maskAllUserTouches` default.** iOS: present-block-without-key →
  `false` (`m:246`); no-config/default paths → `true` (`m:306/358`). Android:
  `SessionReplayConfiguration.java:78` = `false` vs
  `MobileSessionReplayConfiguration.java:80` = `true`. Both platforms split.
- **F3. `error_sampling_rate` default.** All config objects default `100.0`;
  the divergence is iOS-only at *read* time — `isSessionReplayErrorSampled`
  starts `0.0` and overwrites only if config isn't nil
  (`NewRelicAgentInternal.m:1486-1488`), so error sampling is effectively 0
  before the first harvest. (Related: full `samplingRate` defaults also differ
  — Android `10.0` vs `0.0` across its two config classes.)

*Our plan standardizes Flutter to: mode=`custom`, touches=`false`. Confirm.*

**Note for Flutter specifically:** because Flutter *reads* the
native-resolved config (C1) rather than resolving the server response itself,
for an *omitted* field it would **inherit whichever default the underlying
native agent picked** — i.e. it would reproduce the per-platform split, not
fix it. To be consistent across platforms regardless, Flutter must apply its
*own* standardized default for those fields instead of trusting the
native-resolved value when the field was absent.

*(Removed from an earlier draft after source verification: a claimed
"union vs replace" unmask divergence — iOS's `addUnmasked*` actually appends
with dedup, seeded from local, so both platforms effectively **union**; the
iOS "replace" code comment is stale. And a claimed `unmask` vs legacy
`un-mask` typo — no such literal exists; the research conflated the
`"nr-unmask"` view-tag with the `"unmask"` rule-type key.)*

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
