import 'package:flutter/widgets.dart';

import '../capture/node_id_registry.dart';
import '../ir/ir_node.dart';
import 'emitted_tree.dart';
import 'event.dart';
import 'serialized_node.dart';

class FullSnapshotBuilder {
  // Fixed ids for the synthetic wrapper, which is the same 7 nodes every
  // frame. Reserved below NodeIdRegistry.contentIdBase (100) so they can
  // never collide with RenderObject-backed content ids. Constant ids keep
  // the wrapper trivially stable across snapshots for diffing.
  static const int _idDocument = 1;
  static const int _idDoctype = 2;
  static const int _idHtml = 3;
  static const int _idHead = 4;
  static const int _idStyle = 5;
  static const int _idStyleText = 6;
  static const int idBody = 7;

  /// Builds the EMITTED (post-flatten) structure for one frame. This is the
  /// single source of truth: [build] materializes the FullSnapshot from it,
  /// and the incremental diff consumes it directly — so the snapshot and the
  /// diff can never drift.
  ///
  /// A node's emitted parent is its nearest bounded ancestor: passthrough
  /// nodes (bounds == null) emit nothing and forward their incoming parent id
  /// unchanged, so their bounded descendants promote up. Coordinates are
  /// parent-local. A paragraph/icon emits a div with its text child first.
  EmittedTree buildEmitted(IRNode irRoot) {
    final tree = EmittedTree(byId: {}, parentOf: {}, rootChildIds: []);
    _emit(irRoot, null, idBody, tree.rootChildIds, tree);
    return tree;
  }

  void _emit(
    IRNode ir,
    IRRect? parentBounds,
    int parentEmittedId,
    List<int> parentChildIds,
    EmittedTree tree,
  ) {
    if (ir.bounds == null) {
      // Passthrough: emit nothing, promote children to the same parent.
      for (final child in ir.children) {
        _emit(child, parentBounds, parentEmittedId, parentChildIds, tree);
      }
      return;
    }

    // Content nodes must be stamped by the walker/registry (>= contentIdBase).
    // An unstamped node (id == 0) would clobber byId and emit a duplicate-id,
    // structurally invalid snapshot — fail loud in debug.
    assert(ir.id >= NodeIdRegistry.contentIdBase,
        'unstamped content node (${ir.renderType}) reached encoder, id=${ir.id}');

    final localBounds = parentBounds == null
        ? ir.bounds!
        : IRRect(
            ir.bounds!.x - parentBounds.x,
            ir.bounds!.y - parentBounds.y,
            ir.bounds!.width,
            ir.bounds!.height,
          );
    final attrs = <String, String>{
      'style': _positionStyle(localBounds) + ir.style.toCss(),
      'data-render': ir.renderType,
    };
    if (ir.type == 'paragraph') attrs['class'] = 'nr-text';
    if (ir.type == 'icon') attrs['class'] = 'nr-icon';

    final childIds = <int>[];
    tree.byId[ir.id] = EmittedNode.element(
      id: ir.id,
      tagName: ir.type == 'image' ? 'img' : 'div',
      attributes: attrs,
      childIds: childIds,
    );
    tree.parentOf[ir.id] = parentEmittedId;
    parentChildIds.add(ir.id);

    final hasText = (ir.type == 'paragraph' || ir.type == 'icon') &&
        ir.text != null &&
        ir.text!.isNotEmpty;
    if (hasText) {
      // A text-bearing node must carry a distinct textId (stamped by the
      // walker from a second Expando). Loud in debug; in release we simply
      // omit the text child rather than risk a byId key clobber.
      assert(ir.textId != null,
          'text-bearing node (${ir.renderType}) reached encoder without a textId');
      final tid = ir.textId;
      if (tid != null) {
        tree.byId[tid] =
            EmittedNode.text(id: tid, textContent: ir.text!);
        tree.parentOf[tid] = ir.id;
        childIds.add(tid); // text child first
      }
    }

    for (final child in ir.children) {
      _emit(child, ir.bounds, ir.id, childIds, tree);
    }
  }

  FullSnapshotEvent build(IRNode irRoot, {required int timestamp}) {
    // Wrapper ids must stay below the content range so they can never collide
    // with RenderObject-backed content ids.
    assert(idBody < NodeIdRegistry.contentIdBase);
    final viewport = _viewportFromIr(irRoot);
    final emitted = buildEmitted(irRoot);

    final root = SerializedNode.documentNode(
      id: _idDocument,
      childNodes: [
        SerializedNode.documentTypeNode(id: _idDoctype, name: 'html'),
        SerializedNode.elementNode(
          id: _idHtml,
          tagName: 'html',
          childNodes: [
            SerializedNode.elementNode(
              id: _idHead,
              tagName: 'head',
              childNodes: [
                SerializedNode.elementNode(
                  id: _idStyle,
                  tagName: 'style',
                  childNodes: [
                    SerializedNode.textNode(
                      id: _idStyleText,
                      textContent: _baseCss(viewport),
                    ),
                  ],
                ),
              ],
            ),
            SerializedNode.elementNode(
              id: idBody,
              tagName: 'body',
              attributes: {'style': 'margin:0;padding:0;'},
              childNodes: emitted.materializeRoots(),
            ),
          ],
        ),
      ],
    );

    return FullSnapshotEvent(timestamp: timestamp, node: root);
  }

  String _positionStyle(IRRect b) =>
      'position:absolute;'
      'left:${b.x.toStringAsFixed(1)}px;'
      'top:${b.y.toStringAsFixed(1)}px;'
      'width:${b.width.toStringAsFixed(1)}px;'
      'height:${b.height.toStringAsFixed(1)}px;';

  String _baseCss(Size viewport) =>
      'html,body{margin:0;padding:0;width:${viewport.width.toInt()}px;height:${viewport.height.toInt()}px;}'
      'body{position:relative;overflow:hidden;background:#fff;}'
      '.nr-text{font-family:-apple-system,BlinkMacSystemFont,sans-serif;color:#000;}'
      '.nr-icon{display:flex;align-items:center;justify-content:center;}';

  Size _viewportFromIr(IRNode root) {
    var node = root;
    while (node.bounds == null && node.children.isNotEmpty) {
      node = node.children.first;
    }
    final b = node.bounds;
    if (b == null) return const Size(0, 0);
    return Size(b.width, b.height);
  }
}
