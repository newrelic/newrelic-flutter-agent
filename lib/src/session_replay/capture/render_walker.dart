import 'package:flutter/rendering.dart';

import '../ir/ir_node.dart';
import '../ir/ir_style.dart';
import 'thingy/thingy_registry.dart';

class RenderWalker {
  final ThingyRegistry registry;

  RenderWalker({ThingyRegistry? registry})
      : registry = registry ?? ThingyRegistry.defaults();

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

    return IRNode(
      type: bounds == null ? 'passthrough' : result.type,
      renderType: node.runtimeType.toString(),
      bounds: bounds,
      text: result.text,
      style: bounds == null ? IRStyle.empty : result.style,
      children: children,
    );
  }

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
