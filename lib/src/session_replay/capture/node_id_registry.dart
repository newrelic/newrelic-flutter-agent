import 'package:flutter/rendering.dart';

/// Allocates stable rrweb node ids keyed on `RenderObject` identity.
///
/// The same logical UI element keeps the same id across capture frames for
/// the lifetime of its `RenderObject` (and thus of this registry / capture
/// session). That stability is what lets consecutive snapshots be diffed:
/// the diff can emit "node N's text changed" instead of remove-all/add-all,
/// because N refers to the same element in both frames.
///
/// Backed by [Expando], so:
///   * a disposed `RenderObject`'s id entry is reclaimed by GC automatically
///     — the registry never pins render objects and never leaks; and
///   * because the counter is monotonic and never reused, a freshly created
///     `RenderObject` can never inherit a dead one's id (no collisions).
///
/// One registry instance is meant to live for a whole capture session. A
/// throwaway instance per call gives one-shot semantics (ids unique within
/// the single snapshot but not stable across calls), which is all the debug
/// dump / single FullSnapshot paths need.
class NodeIdRegistry {
  /// Ids below this are reserved for the synthetic wrapper nodes
  /// (document / doctype / html / head / style / body) that the encoder
  /// assigns directly. Content node ids start here.
  static const int contentIdBase = 100;

  final Expando<int> _ids = Expando<int>('nr_sr_node_ids');
  final Expando<int> _textIds = Expando<int>('nr_sr_text_node_ids');
  int _counter = contentIdBase;

  /// Stable id for [node]'s element, allocated on first sighting.
  int idFor(RenderObject node) => _ids[node] ??= _counter++;

  /// Stable id for the synthetic text child of a paragraph/icon [node].
  ///
  /// A `RenderParagraph` maps to a `<div>` plus a text child, so it consumes
  /// two ids; both are stable across frames.
  int textIdFor(RenderObject node) => _textIds[node] ??= _counter++;
}
