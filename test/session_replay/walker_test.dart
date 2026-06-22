/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/session_replay.dart';

/// Depth-first search of an IR tree. Reused by the diff tests later.
IRNode? findNode(IRNode root, bool Function(IRNode) test) {
  if (test(root)) return root;
  for (final c in root.children) {
    final r = findNode(c, test);
    if (r != null) return r;
  }
  return null;
}

/// Collects every node id (wrapper + content + text children) from a
/// SerializedNode JSON document, in document order.
void collectIds(Map<String, dynamic> node, List<int> out) {
  out.add(node['id'] as int);
  for (final c in (node['childNodes'] as List? ?? const [])) {
    collectIds(c as Map<String, dynamic>, out);
  }
}

Widget _ltr(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: Center(child: child));

void main() {
  testWidgets('captures text content with bounds', (tester) async {
    await tester.pumpWidget(_ltr(const Text('Hello SR')));

    final ir = SessionReplay.captureCurrentFrame();
    expect(ir, isNotNull);

    final p = findNode(ir!, (n) => n.type == 'paragraph' && n.text == 'Hello SR');
    expect(p, isNotNull, reason: 'paragraph node for the Text should exist');
    expect(p!.bounds, isNotNull, reason: 'laid-out node should carry bounds');
    expect(p.bounds!.width, greaterThan(0));
  });

  testWidgets('excludes offstage subtrees', (tester) async {
    await tester.pumpWidget(_ltr(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('shown'),
          Offstage(offstage: true, child: Text('hidden')),
        ],
      ),
    ));

    final ir = SessionReplay.captureCurrentFrame()!;
    expect(findNode(ir, (n) => n.text == 'shown'), isNotNull);
    expect(findNode(ir, (n) => n.text == 'hidden'), isNull,
        reason: 'offstage child must not be captured');
  });

  testWidgets('captures DecoratedBox background color', (tester) async {
    await tester.pumpWidget(_ltr(
      const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFFFF0000)),
        child: SizedBox(width: 50, height: 50),
      ),
    ));

    final ir = SessionReplay.captureCurrentFrame()!;
    final box = findNode(ir, (n) => n.style.backgroundColor != null);
    expect(box, isNotNull);
    expect(box!.style.backgroundColor, 'rgb(255,0,0)');
  });

  testWidgets('classifies RenderImage as image', (tester) async {
    // RawImage with a null image still creates a RenderImage laid out to its
    // explicit size — no async decode, no network.
    await tester.pumpWidget(_ltr(
      const SizedBox(
        width: 50,
        height: 50,
        child: RawImage(width: 50, height: 50),
      ),
    ));

    final ir = SessionReplay.captureCurrentFrame()!;
    final img = findNode(ir, (n) => n.type == 'image');
    expect(img, isNotNull);
    expect(img!.bounds, isNotNull);
  });

  testWidgets('captureCurrentFrame returns a tree with a viewport-sized root',
      (tester) async {
    await tester.pumpWidget(_ltr(const Text('viewport')));
    final ir = SessionReplay.captureCurrentFrame()!;

    // Walk down to the first node carrying bounds; it should match the test
    // surface (the default flutter_test view is 800x600).
    IRNode n = ir;
    while (n.bounds == null && n.children.isNotEmpty) {
      n = n.children.first;
    }
    expect(n.bounds, isNotNull);
    expect(n.bounds!.width, 800);
    expect(n.bounds!.height, 600);
  });

  group('stable ids', () {
    testWidgets('a node keeps its id across a text-only rebuild',
        (tester) async {
      final reg = NodeIdRegistry();

      await tester.pumpWidget(_ltr(const Text('count: 1')));
      final p1 = findNode(SessionReplay.captureCurrentFrame(idRegistry: reg)!,
          (n) => n.type == 'paragraph')!;

      // Same widget structure, only the string changes => same RenderParagraph
      // => same id; the diff would see a text mutation, not add/remove.
      await tester.pumpWidget(_ltr(const Text('count: 2')));
      final p2 = findNode(SessionReplay.captureCurrentFrame(idRegistry: reg)!,
          (n) => n.type == 'paragraph')!;

      expect(p1.text, 'count: 1');
      expect(p2.text, 'count: 2');
      expect(p2.id, p1.id, reason: 'stable RenderObject => stable id');
      expect(p1.id, greaterThanOrEqualTo(NodeIdRegistry.contentIdBase));
      // The text child id must also be stable — it (not the element) is what
      // an incremental text mutation targets, and text is what changes most.
      expect(p1.textId, isNotNull);
      expect(p2.textId, p1.textId, reason: 'text child id must be stable too');
    });

    testWidgets('paragraph element and its text child get distinct ids',
        (tester) async {
      final reg = NodeIdRegistry();
      await tester.pumpWidget(_ltr(const Text('hi')));
      final p = findNode(SessionReplay.captureCurrentFrame(idRegistry: reg)!,
          (n) => n.type == 'paragraph')!;
      expect(p.textId, isNotNull);
      expect(p.textId, isNot(p.id));
    });

    testWidgets('a type swap at the same position yields a new id',
        (tester) async {
      final reg = NodeIdRegistry();

      await tester.pumpWidget(_ltr(
        const SizedBox(width: 20, height: 20, child: Text('x')),
      ));
      final pId = findNode(SessionReplay.captureCurrentFrame(idRegistry: reg)!,
          (n) => n.type == 'paragraph')!.id;

      // Text -> RawImage: the child RenderObject is replaced (different type).
      // The meaningful property isn't "img id != old id" (the monotonic
      // counter guarantees that trivially) — it's that the disposed
      // paragraph's id does NOT reappear anywhere in the new tree.
      await tester.pumpWidget(_ltr(
        const SizedBox(width: 20, height: 20, child: RawImage(width: 20, height: 20)),
      ));
      final ir2 = SessionReplay.captureCurrentFrame(idRegistry: reg)!;
      expect(findNode(ir2, (n) => n.type == 'image'), isNotNull);
      expect(findNode(ir2, (n) => n.id == pId), isNull,
          reason: 'a disposed RenderObject id must not resurface');
    });

    testWidgets('removing a sibling keeps the surviving sibling id stable',
        (tester) async {
      final reg = NodeIdRegistry();

      await tester.pumpWidget(_ltr(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: const [Text('keep'), Text('drop')],
        ),
      ));
      final keep1 = findNode(SessionReplay.captureCurrentFrame(idRegistry: reg)!,
          (n) => n.text == 'keep')!.id;

      // Remove the trailing sibling; 'keep' stays at the same position so its
      // Element/RenderObject persists.
      await tester.pumpWidget(_ltr(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: const [Text('keep')],
        ),
      ));
      final ir2 = SessionReplay.captureCurrentFrame(idRegistry: reg)!;
      final keep2 = findNode(ir2, (n) => n.text == 'keep')!.id;

      expect(keep2, keep1);
      expect(findNode(ir2, (n) => n.text == 'drop'), isNull);
    });

    testWidgets('allocation is deterministic for an identical tree',
        (tester) async {
      await tester.pumpWidget(_ltr(const Text('det')));
      // Two fresh (throwaway) registries over the same tree => same
      // post-order allocation => identical ids. This is the one-shot contract.
      final a = findNode(
          SessionReplay.captureCurrentFrame(idRegistry: NodeIdRegistry())!,
          (n) => n.type == 'paragraph')!;
      final b = findNode(
          SessionReplay.captureCurrentFrame(idRegistry: NodeIdRegistry())!,
          (n) => n.type == 'paragraph')!;
      expect(a.id, b.id, reason: 'deterministic allocation for identical trees');
      expect(a.id, greaterThanOrEqualTo(NodeIdRegistry.contentIdBase));
    });

    testWidgets('whole-tree ids are unique and stable across an identical '
        'rebuild (real registry, real post-order)', (tester) async {
      final reg = NodeIdRegistry();
      Widget tree() => _ltr(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('a'),
                DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF00FF00)),
                  child: SizedBox(width: 10, height: 10),
                ),
                SizedBox(width: 10, height: 10, child: RawImage(width: 10, height: 10)),
              ],
            ),
          );

      await tester.pumpWidget(tree());
      final ids1 = <int>[];
      collectIds(
          SessionReplay.buildFullSnapshot(idRegistry: reg)!.toJson()['data']
              ['node'] as Map<String, dynamic>,
          ids1);
      expect(ids1.toSet().length, ids1.length,
          reason: 'every id (wrapper + content + text) is globally unique');

      await tester.pumpWidget(tree());
      final ids2 = <int>[];
      collectIds(
          SessionReplay.buildFullSnapshot(idRegistry: reg)!.toJson()['data']
              ['node'] as Map<String, dynamic>,
          ids2);
      expect(ids2, ids1,
          reason: 'identical rebuild with the same registry => identical ids');
    });
  });
}
