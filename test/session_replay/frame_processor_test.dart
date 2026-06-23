/*
 * Copyright (c) 2022-present New Relic Corporation. All rights reserved.
 * SPDX-License-Identifier: Apache-2.0
 */

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:newrelic_mobile/session_replay.dart';

Widget _ltr(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: Center(child: child));

int _typeOf(RrwebEvent e) => e.toJson()['type'] as int;

void main() {
  testWidgets('first frame emits Meta + FullSnapshot', (tester) async {
    await tester.pumpWidget(_ltr(const Text('hello')));
    final fp = FrameProcessor();
    final ir = SessionReplay.captureCurrentFrame()!;
    final events = fp.processFrame(ir, timestamp: 1);

    expect(events.length, 2);
    expect(_typeOf(events[0]), 4); // Meta
    expect(_typeOf(events[1]), 2); // FullSnapshot
    final meta = events[0].toJson();
    expect(meta['data']['width'], 800);
    expect(meta['data']['height'], 600);
  });

  testWidgets('an unchanged second frame emits nothing', (tester) async {
    await tester.pumpWidget(_ltr(const Text('steady')));
    final fp = FrameProcessor();
    final reg = NodeIdRegistry();
    fp.processFrame(SessionReplay.captureCurrentFrame(idRegistry: reg)!,
        timestamp: 1);
    // Re-capture the identical tree with the SAME registry => identical ids.
    final events = fp.processFrame(
        SessionReplay.captureCurrentFrame(idRegistry: reg)!,
        timestamp: 2);
    expect(events, isEmpty);
  });

  testWidgets('a changed second frame emits a single IncrementalSnapshot',
      (tester) async {
    final fp = FrameProcessor();
    final reg = NodeIdRegistry();

    await tester.pumpWidget(_ltr(const Text('count: 1')));
    final first = fp.processFrame(
        SessionReplay.captureCurrentFrame(idRegistry: reg)!,
        timestamp: 1);
    expect(first.length, 2); // Meta + Full

    await tester.pumpWidget(_ltr(const Text('count: 2')));
    final second = fp.processFrame(
        SessionReplay.captureCurrentFrame(idRegistry: reg)!,
        timestamp: 2);

    expect(second.length, 1);
    expect(_typeOf(second.first), 3); // IncrementalSnapshot
    final data = second.first.toJson()['data'];
    expect(data['source'], 0); // mutation
    // A text-only change => exactly one text record, no structural churn.
    expect((data['texts'] as List).length, 1);
    expect((data['adds'] as List), isEmpty);
    expect((data['removes'] as List), isEmpty);
  });

  testWidgets('a viewport resize forces a fresh FullSnapshot (with Meta)',
      (tester) async {
    final fp = FrameProcessor();
    final reg = NodeIdRegistry();

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_ltr(const Text('resize me')));
    final first = fp.processFrame(
        SessionReplay.captureCurrentFrame(idRegistry: reg)!,
        timestamp: 1);
    expect(first.length, 2);

    tester.view.physicalSize = const Size(1000, 700);
    await tester.pumpWidget(_ltr(const Text('resize me')));
    final second = fp.processFrame(
        SessionReplay.captureCurrentFrame(idRegistry: reg)!,
        timestamp: 2);

    expect(second.length, 2, reason: 'resize => Meta + FullSnapshot');
    expect(_typeOf(second[0]), 4);
    expect(_typeOf(second[1]), 2);
  });

  testWidgets('processCurrentFrame uses the owned registry => stable ids',
      (tester) async {
    await tester.pumpWidget(_ltr(const Text('a')));
    final fp = FrameProcessor();
    final first = fp.processCurrentFrame(timestamp: 1);
    expect(first.length, 2); // Meta + FullSnapshot

    await tester.pumpWidget(_ltr(const Text('b')));
    final second = fp.processCurrentFrame(timestamp: 2);
    // A single incremental (NOT another full) proves ids stayed stable across
    // frames via the processor's own persistent registry.
    expect(second.length, 1);
    expect(_typeOf(second.first), 3);
    expect((second.first.toJson()['data']['texts'] as List).length, 1);
  });

  testWidgets('reset() makes the next frame a fresh FullSnapshot',
      (tester) async {
    await tester.pumpWidget(_ltr(const Text('x')));
    final fp = FrameProcessor();
    final reg = NodeIdRegistry();
    fp.processFrame(SessionReplay.captureCurrentFrame(idRegistry: reg)!,
        timestamp: 1);
    fp.reset();
    final events = fp.processFrame(
        SessionReplay.captureCurrentFrame(idRegistry: reg)!,
        timestamp: 2);
    expect(events.length, 2); // full again, not an empty/incremental
  });
}
