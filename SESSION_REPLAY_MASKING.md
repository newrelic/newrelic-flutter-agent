# Session Replay — Masking / Privacy Spec

How the native iOS/Android agents implement session-replay masking, and the
plan to mirror it in the Flutter agent. Derived from reading the native
sources (iOS `newrelic-ios-agent`, Android `newrelic-android-agent`, plus the
React Native widget pattern). This is the gathered spec; implementation
follows the sequenced plan at the end.

## Two orthogonal "modes" — don't conflate

- **Recording mode** = `off | error | full`, computed from sampling rates.
  **Owned entirely by the native agent.** Flutter does not recompute it; it
  consumes the native-resolved mode to decide *whether to run the capture
  loop at all*. Governs WHEN frames are sent.
- **Masking mode** = `"default" | "custom"` (config string). Governs WHAT is
  redacted. This is the subject of this doc.

## Two-layer architecture

- **Native owns**: server-config resolution (from the `/connect` harvest
  response), sampling + recording-mode, and blob upload.
- **Dart owns**: the RenderObject-tree walk and per-widget masking
  application (redaction happens in Dart before events leave the device).
- **Bridge**: carries the native-resolved masking config + recording mode
  from native → Dart at `startAgent` and on each harvest update.

## Server-driven config (resolved natively, delivered to Dart)

All of these come from `configuration.session_replay` in the harvest
response (iOS `NRMAHarvesterConfiguration`; Android
`SessionReplayConfiguration`). Until the first `/connect` response, replay is
**off**.

| field | default | meaning |
|---|---|---|
| `enabled` | `false` | master on/off; gates everything |
| `sampling_rate` | 100 (iOS) / 10 (Android) | % of sessions in FULL mode (native-owned) |
| `error_sampling_rate` | 100 | % eligible for ERROR mode (native-owned) |
| `mode` | `custom` (std.) | masking mode: `default` vs `custom` |
| `mask_application_text` | `true` | mask static text (RenderParagraph) |
| `mask_user_input_text` | `true` | mask input text (RenderEditable) |
| `mask_all_images` | `true` | mask images (RenderImage) |
| `mask_all_user_touches` | `false` (std.) | suppress touch points |
| `custom_masking_rules` | `[]` | server class/key mask/unmask rules → expanded to four sets |

The native bridge returns, in one map: the four booleans, `enabled`, `mode`,
`recordingMode`, and the four resolved sets `maskedClasses` /
`unmaskedClasses` / `maskedKeys` / `unmaskedKeys` (custom rules already
expanded and unioned with the local programmatic lists).

## Programmatic API (native → Flutter mapping)

| native | Flutter |
|---|---|
| `addSessionReplayMaskViewClass(String)` | `NewrelicMobile.instance.addSessionReplayMaskViewClass(widgetTypeName)` — forwards to native + Dart-local `maskedClasses` |
| `addSessionReplayUnmaskViewClass(String)` | `addSessionReplayUnmaskViewClass(...)` (custom mode only) |
| `addSessionReplayMaskedAccessibilityIdentifier` / Android `addSessionReplayMaskViewTag` | `addSessionReplayMaskViewKey(String)` |
| `addSessionReplayUnmaskedAccessibilityIdentifier` / `addSessionReplayUnmaskViewTag` | `addSessionReplayUnmaskViewKey(String)` |
| `recordReplay` / `pauseReplay` | passthrough to native (recording control, not masking) |
| iOS per-view `maskApplicationText`/… associated objects (inherit from superview) | `NRMaskedRegion(maskApplicationText:, maskUserInputText:, maskAllImages:, maskAllUserTouches:, block:, nrKey:, child:)` |
| `nr-mask` / `nr-unmask` / `nr-block` view tag (Android) / accessibilityIdentifier (iOS) / Compose modifier; RN `NewRelicMask`/`Unmask`/`Block` | widgets `NRMaskedRegion` / `NRUnmaskedRegion` / `NRBlock` / `NRMaskKey` |

**Cross-platform adaptation:** RN can tag a real native view because RN
renders to native views; Flutter renders to a canvas with no per-widget
native view to tag, so the marker must propagate **in the Dart tree**. The
marker widgets insert a private `NRPrivacyMarker` that the RenderObject
walker detects.

## Precedence model (per node, during the walk)

```
BLOCK (any mode)                              ← node/ancestor nr-block
> PASSWORD/obscureText (any mode)             ← always masked
> [MODE GATE: if "default", skip the rest;    ← privacy-by-default
   mask purely by forced type globals:
   text=true, input=true, image=true, touch=false]
> nr-mask marker            (custom mode)
> masked key  (local ∪ server)
> masked class (local ∪ server)
> nr-unmask marker
> unmasked key
> unmasked class
> inherited ancestor mask state
> per-widget type bool (own, else inherited NRMaskedRegion)
> global server type bool
> true (mask)                                 ← safe fallback
```

Mask beats unmask at the same tier (first-match, mask checked first).
Local + server lists **union** (standardized — Android-style).

## Masked rendering (rrweb output)

- **Text**: replace content char-for-char with `'*' * length` (preserves
  length + layout); the div keeps its real font/color CSS. No
  `data-nr-masked` on text nodes. Empty stays empty.
- **Image**: no `src`, append `background:#CCCCCC;` to style, attribute
  `data-nr-masked="image"`. On unmask transition, clear to
  `data-nr-masked=""`.
- **Block**: childless `div`, `background-color:#000000`,
  `data-nr-masked="block"`, no children captured.
- **Touch**: masked/blocked touch is **dropped** (not emitted), not redacted.

## Flutter application plan

`MaskResolver` runs **during** `RenderWalker._walk`, producing a
`MaskDecision { masked, blocked }` per node that the thingies + encoder
consume.

- **Marker detection** — the recommended approach (resolves the "no
  RenderObject→Element back-pointer in release" problem): `NRMaskedRegion`
  /`NRUnmaskedRegion`/`NRBlock`/`NRMaskKey` are backed by a **custom
  `RenderObject`** (a `RenderProxyBox` subclass, e.g. `RenderNRPrivacy`)
  carrying the privacy flags. The walker detects it **by type** directly in
  the tree and threads an accumulated `PrivacyContext` down the recursive
  `_walk` — giving ancestor inheritance for free (mirrors iOS superview /
  Android ancestor walks) with no Element lookups.
- **Class matching** uses the node's backing widget runtimeType string
  (concrete type only — Flutter has no cheap runtime supertype chain;
  documented limitation vs native's superclass walk).
- **Apply**: add `IRNode.masked` + `IRNode.blocked`; masked paragraph/icon →
  `'*'×len` (keeps the textId invariant); masked editable → `'*'×len` (real
  text only when explicitly unmasked); masked image → `#CCCCCC` +
  `data-nr-masked`; block → leaf node type `'block'`.
- **Incremental diff**: a mask-state flip is just a text/attribute change (or
  a `forceReplace` for box→block) — handled by the existing diff phases, no
  diff changes needed.
- **Touch**: in `startTouchCapture`, hit-test `event.position` against the
  latest EmittedTree; drop the event when the resolved node/ancestor is
  touch-masked or blocked.

## Native bridge (the prerequisite gap — none exists today)

1. MethodChannel `getSessionReplayConfiguration` on `newrelic_mobile`:
   iOS → `[NRMAHarvestController configuration]`; Android →
   `AgentConfiguration.getSessionReplayConfiguration()` +
   `processCustomMaskingRules()` + local config. Returns the unified map.
2. Native → Dart push `onSessionReplayConfigurationChanged` on each harvest
   update (config is only valid after the first `/connect`).
3. `SessionReplay.startSessionReplay` gated on `enabled && recordingMode != off`.
4. The four `add*` APIs forward to native AND populate Dart-local sets
   immediately (no round-trip needed for the Dart walker).

## Cross-platform inconsistencies — standardized for Flutter

- Masking mode default → **`custom`** (iOS default; Android's `default` is the outlier).
- Unmask list semantics → **union** (Android-style; iOS replaces).
- `mask_all_user_touches` default → **`false`** (touches recorded unless opted in).
- Custom-rule type string → **`unmask`** (avoid the legacy Android `un-mask` typo).

Each deviation documented in code where it applies.

## Open questions (need product / design / native-team input)

1. **Will the native agents upload Flutter-produced rrweb blobs?** If yes,
   Dart fully defers sampling to native. If Flutter uploads its own blobs,
   Dart must also honor sampling. (Ties into the transport decision.)
2. **Marker mechanism**: confirm the custom-RenderObject approach (recommended)
   vs an Element-walk side-map.
3. **`nrKey`** should be a dedicated NR field, not Flutter's `Widget.key`
   (avoid clobbering app keys) — confirm in API review.
4. **Editable when explicitly unmasked**: emit real input text (matches native
   unmask) or keep withholding input for safety?
5. **Config push vs poll**: native→Dart push (cleaner, more native plumbing)
   vs query-at-startAgent + timer.
6. Confirm the intended single defaults for `mask_all_user_touches` /
   `error_sampling_rate` with the backend team (native code paths disagree).

## Sequenced implementation plan

1. **Native bridge** — `getSessionReplayConfiguration` + push + `Config` SR
   startup-hint fields forwarded in `startAgent`.
2. **Dart config models** — `SessionReplayConfig` (resolved),
   `SessionReplayLocalConfig` (programmatic lists), `SessionReplayMaskingMode`.
3. **Privacy widgets + marker** — `NRPrivacyMarker` (custom RenderObject) +
   `NRMaskedRegion`/`NRUnmaskedRegion`/`NRBlock`/`NRMaskKey`.
4. **MaskResolver + PrivacyContext** threaded through `RenderWalker._walk`.
5. **Apply masking** in IR/encoder (`IRNode.masked`/`blocked`, `'*'×len`,
   `#CCCCCC`, block node).
6. **Touch masking** — drop events over masked/blocked subtrees.
7. **Tests** — precedence, default-mode short-circuit, redaction rendering,
   touch-drop, incremental mask-flip.
8. **Reconcile** the standardized cross-platform deviations in code + docs.

### Decoupling note

Steps 2–7 (the **masking engine**: widgets, resolver, redaction, tests) are
**pure Dart** and can be built/tested now, driven by `Config` startup-hint
flags + the programmatic APIs, defaulting to privacy-on. Step 1 (the native
**server-config bridge**) can land after — it swaps the config *source* from
startup-hints to native-resolved. This unblocks privacy-by-default without
waiting on native-team coordination.
