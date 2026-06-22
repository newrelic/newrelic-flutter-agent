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
}
