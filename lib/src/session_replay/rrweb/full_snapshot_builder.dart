import 'package:flutter/widgets.dart';

import '../ir/ir_node.dart';
import 'event.dart';
import 'serialized_node.dart';

class FullSnapshotBuilder {
  int _nextId = 1;

  int _id() => _nextId++;

  FullSnapshotEvent build(IRNode irRoot, {required int timestamp}) {
    final viewport = _viewportFromIr(irRoot);
    final bodyChildren = <SerializedNode>[];
    _emit(irRoot, bodyChildren, null);

    final root = SerializedNode.documentNode(
      id: _id(),
      childNodes: [
        SerializedNode.documentTypeNode(id: _id(), name: 'html'),
        SerializedNode.elementNode(
          id: _id(),
          tagName: 'html',
          childNodes: [
            SerializedNode.elementNode(
              id: _id(),
              tagName: 'head',
              childNodes: [
                SerializedNode.elementNode(
                  id: _id(),
                  tagName: 'style',
                  childNodes: [
                    SerializedNode.textNode(
                      id: _id(),
                      textContent: _baseCss(viewport),
                    ),
                  ],
                ),
              ],
            ),
            SerializedNode.elementNode(
              id: _id(),
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
      children.insert(0, SerializedNode.textNode(id: _id(), textContent: ir.text!));
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

    out.add(SerializedNode.elementNode(
      id: _id(),
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
