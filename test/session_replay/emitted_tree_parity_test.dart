/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

// No-drift gate: the EmittedTree the incremental diff reasons about must
// describe exactly the same structure as the FullSnapshot a player builds.
// For a corpus of real (pumped) widget trees, every content node in the
// snapshot body must match the EmittedTree by id, parent, tag, attributes,
// text, and child order — and vice versa.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/session_replay.dart';
import 'package:newrelic_mobile/src/session_replay/rrweb/full_snapshot_builder.dart';

class _PNode {
  final int parentId;
  final String? tagName;
  final Map<String, String>? attributes;
  final String? textContent;
  final List<int> childIds;
  _PNode(this.parentId, this.tagName, this.attributes, this.textContent,
      this.childIds);
}

/// Flattens a SerializedNode JSON subtree into id -> _PNode, recording each
/// node's parent and ordered child ids.
void _flattenSnapshot(Map<String, dynamic> node, int parentId,
    Map<int, _PNode> out) {
  final id = node['id'] as int;
  final type = node['type'] as int;
  final kids = (node['childNodes'] as List?) ?? const [];
  final childIds = kids.map((c) => (c as Map)['id'] as int).toList();
  if (type == 2) {
    out[id] = _PNode(
      parentId,
      node['tagName'] as String?,
      (node['attributes'] as Map?)?.cast<String, String>() ?? {},
      null,
      childIds,
    );
  } else if (type == 3) {
    out[id] = _PNode(parentId, null, null, node['textContent'] as String?, []);
  }
  for (final c in kids) {
    _flattenSnapshot(c as Map<String, dynamic>, id, out);
  }
}

Widget _ltr(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: Center(child: child));

void main() {
  Future<void> checkParity(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(_ltr(widget));
    final ir = SessionReplay.captureCurrentFrame(idRegistry: NodeIdRegistry())!;
    final builder = FullSnapshotBuilder();
    final tree = builder.buildEmitted(ir);
    final snapshot = builder.build(ir, timestamp: 0).toJson();

    // Flatten the snapshot starting at <body> (its content children are the
    // emitted roots, parented to idBody).
    final body = _findBody(snapshot['data']['node'] as Map<String, dynamic>);
    final fromSnapshot = <int, _PNode>{};
    for (final c in (body['childNodes'] as List)) {
      _flattenSnapshot(
          c as Map<String, dynamic>, FullSnapshotBuilder.idBody, fromSnapshot);
    }

    // Every EmittedTree node must appear identically in the snapshot.
    for (final entry in tree.byId.entries) {
      final id = entry.key;
      final em = entry.value;
      final sn = fromSnapshot[id];
      expect(sn, isNotNull, reason: 'emitted id $id missing from snapshot');
      expect(tree.parentOf[id], sn!.parentId, reason: 'parent mismatch for $id');
      expect(em.tagName, sn.tagName, reason: 'tag mismatch for $id');
      expect(em.attributes, sn.attributes, reason: 'attrs mismatch for $id');
      expect(em.textContent, sn.textContent, reason: 'text mismatch for $id');
      expect(em.childIds, sn.childIds, reason: 'child order mismatch for $id');
    }
    // ...and no snapshot content node is absent from the EmittedTree.
    for (final id in fromSnapshot.keys) {
      expect(tree.byId.containsKey(id), isTrue,
          reason: 'snapshot id $id absent from EmittedTree');
    }
    expect(tree.byId.length, fromSnapshot.length);
  }

  testWidgets('parity: single text', (t) async {
    await checkParity(t, const Text('hello'));
  });

  testWidgets('parity: column of mixed children', (t) async {
    await checkParity(
      t,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('one'),
          DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFF2196F3)),
            child: SizedBox(width: 40, height: 20),
          ),
          Text('two'),
        ],
      ),
    );
  });

  testWidgets('parity: nested containers + image (deep flatten)', (t) async {
    await checkParity(
      t,
      Container(
        padding: const EdgeInsets.all(8),
        color: const Color(0xFFEEEEEE),
        child: Container(
          color: const Color(0xFFCCCCCC),
          child: const SizedBox(
            width: 30,
            height: 30,
            child: RawImage(width: 30, height: 30),
          ),
        ),
      ),
    );
  });
}

Map<String, dynamic> _findBody(Map<String, dynamic> document) {
  Map<String, dynamic>? found;
  void walk(Map<String, dynamic> n) {
    if (n['tagName'] == 'body') found = n;
    for (final c in (n['childNodes'] as List? ?? const [])) {
      walk(c as Map<String, dynamic>);
    }
  }

  walk(document);
  return found!;
}
