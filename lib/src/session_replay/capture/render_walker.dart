import 'package:flutter/rendering.dart';

import '../ir/ir_node.dart';
import '../ir/ir_style.dart';
import 'node_id_registry.dart';
import 'thingy/thingy_registry.dart';

class RenderWalker {
  final ThingyRegistry registry;
  final NodeIdRegistry idRegistry;

  RenderWalker({ThingyRegistry? registry, NodeIdRegistry? idRegistry})
      : registry = registry ?? ThingyRegistry.defaults(),
        idRegistry = idRegistry ?? NodeIdRegistry();

  IRNode? walk(RenderObject root) => _walk(root);

  IRNode? _walk(RenderObject node) {
    if (node is RenderOffstage && node.offstage) return null;

    final children = <IRNode>[];
    if (_isNavigatorOverlay(node)) {
      // Navigator's overlay stack — keep only the topmost entry. Avoids
      // capturing previous routes still alive in the stack (e.g., kept on
      // for Cupertino back-swipe parallax). Misses transparent-barrier
      // overlays and snackbars layered above the top route; revisit when
      // those cases appear.
      RenderObject? topmost;
      node.visitChildren((c) {
        topmost = c;
      });
      if (topmost != null) {
        final ir = _walk(topmost!);
        if (ir != null) children.add(ir);
      }
    } else {
      node.visitChildren((child) {
        final ir = _walk(child);
        if (ir != null) children.add(ir);
      });
    }

    final bounds = _boundsOf(node);
    final result = registry.classify(node);

    if (bounds == null && children.isEmpty) return null;

    // Mirror the encoder's text-emit condition exactly (paragraph/icon with
    // non-empty text) so a textId is allocated iff a text child is emitted —
    // keeping "has a textId" <=> "has a text node" a stable invariant.
    // 'editable' (TextField) is intentionally excluded: its text is user
    // input, and emitting it is deferred until masking (maskUserInputText)
    // exists, to avoid leaking input into snapshots.
    final isTextBearing = bounds != null &&
        (result.type == 'paragraph' || result.type == 'icon') &&
        (result.text?.isNotEmpty ?? false);

    // Clipping render objects (scroll viewports, clip rects) must emit
    // overflow:hidden so their content can't paint outside the box — e.g. a
    // scrolled list over the app bar.
    final style = bounds == null
        ? IRStyle.empty
        : (_clips(node) ? result.style.copyWith(overflow: 'hidden') : result.style);

    // An id is allocated for every walked node, including passthroughs the
    // encoder later flattens away; the content id space is deliberately
    // sparse and traversal-ordered, not output-contiguous.
    return IRNode(
      type: bounds == null ? 'passthrough' : result.type,
      renderType: node.runtimeType.toString(),
      bounds: bounds,
      text: result.text,
      style: style,
      children: children,
      id: idRegistry.idFor(node),
      textId: isTextBearing ? idRegistry.textIdFor(node) : null,
    );
  }

  bool _clips(RenderObject node) =>
      node is RenderClipRect ||
      node is RenderClipRRect ||
      node is RenderClipOval ||
      node is RenderClipPath ||
      node is RenderViewport;

  bool _isNavigatorOverlay(RenderObject node) {
    final name = node.runtimeType.toString();
    return name == '_RenderTheater' || name == '_RenderTheatre';
  }

  IRRect? _boundsOf(RenderObject node) {
    if (node is! RenderBox) return null;
    if (!node.hasSize || !node.attached) return null;
    try {
      final origin = node.localToGlobal(Offset.zero);
      return IRRect(origin.dx, origin.dy, node.size.width, node.size.height);
    } catch (_) {
      return null;
    }
  }
}
