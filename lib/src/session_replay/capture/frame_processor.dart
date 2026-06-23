import 'package:flutter/widgets.dart';

import '../ir/ir_node.dart';
import '../rrweb/emitted_tree.dart';
import '../rrweb/event.dart';
import '../rrweb/full_snapshot_builder.dart';
import '../rrweb/incremental_diff_generator.dart';
import '../session_replay.dart';
import 'node_id_registry.dart';

/// Turns a stream of captured IR frames into rrweb events: a Meta +
/// FullSnapshot on the first frame, then IncrementalSnapshot mutations for
/// each subsequent frame. Mirrors the native agents' SessionReplayFrameProcessor.
///
/// Re-emits a fresh FullSnapshot (rather than a diff) when the viewport size
/// changes, or when a diff would be so churny that a full resync is cheaper
/// and safer (the op-amplification escape hatch — bounds the cost of large
/// subtree moves, which rrweb has no reparent primitive for).
class FrameProcessor {
  final FullSnapshotBuilder _builder = FullSnapshotBuilder();
  final IncrementalDiffGenerator _diff = IncrementalDiffGenerator();

  final String href;

  /// If a diff's total mutation count exceeds this fraction of the frame's
  /// node count, emit a FullSnapshot instead.
  final double fullSnapshotOpRatio;

  EmittedTree? _last;
  Size? _lastViewport;

  /// Persistent across frames — owned here so callers cannot accidentally pass
  /// a fresh per-frame registry (which would make every node look new every
  /// frame). Use [idRegistry] when capturing for this processor.
  NodeIdRegistry _registry = NodeIdRegistry();
  NodeIdRegistry get idRegistry => _registry;

  FrameProcessor({this.href = 'flutter://app', this.fullSnapshotOpRatio = 0.5});

  /// Captures the live frame through the owned persistent registry and
  /// processes it. This is the intended driver — it makes the stable-id
  /// contract automatic.
  List<RrwebEvent> processCurrentFrame({required int timestamp}) {
    final ir = SessionReplay.captureCurrentFrame(idRegistry: _registry);
    if (ir == null) return const [];
    return processFrame(ir, timestamp: timestamp);
  }

  /// Processes one captured frame. Returns the events to emit:
  /// `[Meta, FullSnapshot]` on a full frame, `[IncrementalSnapshot]` on a
  /// diff, or `[]` when nothing changed.
  List<RrwebEvent> processFrame(IRNode ir, {required int timestamp}) {
    final emitted = _builder.buildEmitted(ir);
    final viewport = _builder.viewportOf(ir);

    final isFirst = _last == null;
    // Compare at integer-pixel resolution to match the Meta/CSS dimensions
    // (which are emitted via toInt()); sub-pixel jitter shouldn't force a
    // full resync.
    final resized = _lastViewport != null && !_sameViewport(_lastViewport!, viewport);
    if (isFirst || resized) {
      _last = emitted;
      _lastViewport = viewport;
      return [
        MetaEvent(
          timestamp: timestamp,
          href: href,
          width: viewport.width.toInt(),
          height: viewport.height.toInt(),
        ),
        _builder.assemble(emitted, viewport, timestamp: timestamp),
      ];
    }

    final mut = _diff.generateMutations(_last!, emitted);
    _last = emitted;
    _lastViewport = viewport;
    if (mut == null) return const [];

    final ops = mut.adds.length +
        mut.removes.length +
        mut.texts.length +
        mut.attributes.length;
    if (ops > emitted.byId.length * fullSnapshotOpRatio) {
      // Too churny to be worth an incremental — resync with a full snapshot.
      // Viewport is unchanged, so no Meta needed.
      return [_builder.assemble(emitted, viewport, timestamp: timestamp)];
    }

    return [IncrementalSnapshotEvent.mutation(timestamp: timestamp, data: mut)];
  }

  /// Forget all state — the next frame becomes a fresh FullSnapshot with a
  /// fresh id namespace. Call when a new session begins.
  void reset() {
    _last = null;
    _lastViewport = null;
    _registry = NodeIdRegistry();
  }

  bool _sameViewport(Size a, Size b) =>
      a.width.toInt() == b.width.toInt() && a.height.toInt() == b.height.toInt();
}
