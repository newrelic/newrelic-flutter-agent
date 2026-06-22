import 'package:flutter/widgets.dart';

import '../capture/node_id_registry.dart';
import '../ir/ir_node.dart';
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
  static const int _idBody = 7;

  FullSnapshotEvent build(IRNode irRoot, {required int timestamp}) {
    // Wrapper ids must stay below the content range so they can never collide
    // with RenderObject-backed content ids.
    assert(_idBody < NodeIdRegistry.contentIdBase);
    final viewport = _viewportFromIr(irRoot);
    final bodyChildren = <SerializedNode>[];
    _emit(irRoot, bodyChildren, null);

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
              id: _idBody,
              tagName: 'body',
              attributes: {'style': 'margin:0;padding:0;'},
              childNodes: bodyChildren,
            ),
          ],
        ),
      ],
    );

    return FullSnapshotEvent(timestamp: timestamp, node: root);
  }

  void _emit(IRNode ir, List<SerializedNode> out, IRRect? parentBounds) {
    if (ir.bounds == null) {
      for (final child in ir.children) {
        _emit(child, out, parentBounds);
      }
      return;
    }

    final children = <SerializedNode>[];
    for (final child in ir.children) {
      _emit(child, children, ir.bounds);
    }

    final hasText = (ir.type == 'paragraph' || ir.type == 'icon') &&
        ir.text != null &&
        ir.text!.isNotEmpty;
    if (hasText) {
      // A text-bearing node must carry a distinct textId (the walker stamps it
      // from a second Expando). Loud in debug; the `?? ir.id` fallback keeps
      // release non-crashing if a future IR producer forgets to stamp it.
      assert(ir.textId != null,
          'text-bearing node (${ir.renderType}) reached encoder without a textId');
      children.insert(
        0,
        SerializedNode.textNode(
          id: ir.textId ?? ir.id,
          textContent: ir.text!,
        ),
      );
    }

    final localBounds = parentBounds == null
        ? ir.bounds!
        : IRRect(
            ir.bounds!.x - parentBounds.x,
            ir.bounds!.y - parentBounds.y,
            ir.bounds!.width,
            ir.bounds!.height,
          );
    final style = _positionStyle(localBounds) + ir.style.toCss();
    final attrs = <String, String>{
      'style': style,
      'data-render': ir.renderType,
    };
    if (ir.type == 'paragraph') attrs['class'] = 'nr-text';
    if (ir.type == 'icon') attrs['class'] = 'nr-icon';

    // Content nodes must be stamped by the walker/registry (>= contentIdBase).
    // An unstamped node (id == 0) would emit a duplicate-id, structurally
    // invalid rrweb snapshot — fail loud in debug before the diff producer can
    // trigger it.
    assert(ir.id >= NodeIdRegistry.contentIdBase,
        'unstamped content node (${ir.renderType}) reached encoder, id=${ir.id}');
    out.add(SerializedNode.elementNode(
      id: ir.id,
      tagName: ir.type == 'image' ? 'img' : 'div',
      attributes: attrs,
      childNodes: children,
    ));
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
