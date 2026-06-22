import 'serialized_node.dart';

/// rrweb IncrementalSnapshot mutation payload (source = 0).
///
/// Wire shape (matches the iOS/Android agents, validated against the New
/// Relic backend):
/// ```
/// { source: 0,
///   texts:      [{ id, value }],
///   attributes: [{ id, attributes: { style, ... } }],
///   removes:    [{ parentId, id }],
///   adds:       [{ parentId, nextId, node }] }
/// ```
class MutationData {
  final List<AddRecord> adds;
  final List<RemoveRecord> removes;
  final List<TextRecord> texts;
  final List<AttributeRecord> attributes;

  MutationData({
    List<AddRecord>? adds,
    List<RemoveRecord>? removes,
    List<TextRecord>? texts,
    List<AttributeRecord>? attributes,
  })  : adds = adds ?? [],
        removes = removes ?? [],
        texts = texts ?? [],
        attributes = attributes ?? [];

  bool get isEmpty =>
      adds.isEmpty && removes.isEmpty && texts.isEmpty && attributes.isEmpty;

  /// Body of the IncrementalSnapshot `data` minus `source` — the
  /// IncrementalSnapshotEvent envelope adds `source: 0`.
  Map<String, dynamic> toJson() => {
        'texts': texts.map((t) => t.toJson()).toList(),
        'attributes': attributes.map((a) => a.toJson()).toList(),
        'removes': removes.map((r) => r.toJson()).toList(),
        'adds': adds.map((a) => a.toJson()).toList(),
      };
}

/// A node added to the mirror. [nextId] is the id of the sibling to insert
/// before (under [parentId]); null appends. [node] is a SerializedNode whose
/// element child list is shallow — descendants arrive as their own AddRecords
/// — except a paragraph/icon div, which inlines its stable text child.
class AddRecord {
  final int parentId;
  final int? nextId;
  final SerializedNode node;

  AddRecord({required this.parentId, this.nextId, required this.node});

  Map<String, dynamic> toJson() => {
        'parentId': parentId,
        'nextId': nextId,
        'node': node.toJson(),
      };
}

class RemoveRecord {
  final int parentId;
  final int id;

  RemoveRecord({required this.parentId, required this.id});

  Map<String, dynamic> toJson() => {'parentId': parentId, 'id': id};
}

class TextRecord {
  final int id;
  final String value;

  TextRecord({required this.id, required this.value});

  Map<String, dynamic> toJson() => {'id': id, 'value': value};
}

class AttributeRecord {
  final int id;
  final Map<String, String> attributes;

  AttributeRecord({required this.id, required this.attributes});

  Map<String, dynamic> toJson() => {'id': id, 'attributes': attributes};
}
