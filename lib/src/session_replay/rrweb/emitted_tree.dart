import 'serialized_node.dart';

/// One node in the EMITTED (post-flatten) structure — i.e. exactly the nodes
/// that become rrweb SerializedNodes. Passthrough IR nodes (no bounds) do not
/// appear; their bounded descendants are promoted to the nearest bounded
/// ancestor. This is the level the incremental diff operates on.
class EmittedNode {
  /// SerializedNode type: element (2) or text (3).
  final int type;
  final int id;

  // Element fields (null for text nodes).
  final String? tagName;
  final Map<String, String>? attributes;

  // Text field (null for elements).
  final String? textContent;

  /// Emitted children in document order. For a paragraph/icon div, the text
  /// child id is first (mirrors children.insert(0, ...) in the encoder).
  final List<int> childIds;

  EmittedNode.element({
    required this.id,
    required String this.tagName,
    required Map<String, String> this.attributes,
    List<int>? childIds,
  })  : type = SerializedNode.element,
        textContent = null,
        childIds = childIds ?? [];

  EmittedNode.text({required this.id, required String this.textContent})
      : type = SerializedNode.text,
        tagName = null,
        attributes = null,
        childIds = const [];

  bool get isElement => type == SerializedNode.element;
  bool get isText => type == SerializedNode.text;
}

/// The emitted structure for one frame: node-by-id, parent-by-id, and the
/// top-level (body) child order. Built once by [FullSnapshotBuilder.buildEmitted]
/// and used both to materialize the FullSnapshot and as diff input — a single
/// source of truth so the snapshot and the diff can never drift.
class EmittedTree {
  final Map<int, EmittedNode> byId;
  final Map<int, int> parentOf;
  final List<int> rootChildIds;

  EmittedTree({
    required this.byId,
    required this.parentOf,
    required this.rootChildIds,
  });

  /// Rebuilds the nested SerializedNode for [id] (element with its children
  /// nested recursively, or a text node).
  SerializedNode materializeNode(int id) {
    final n = byId[id]!;
    if (n.isText) {
      return SerializedNode.textNode(id: n.id, textContent: n.textContent!);
    }
    return SerializedNode.elementNode(
      id: n.id,
      tagName: n.tagName!,
      attributes: n.attributes!,
      childNodes: n.childIds.map(materializeNode).toList(),
    );
  }

  /// Materializes the top-level emitted nodes (body's children), nested.
  List<SerializedNode> materializeRoots() =>
      rootChildIds.map(materializeNode).toList();
}
