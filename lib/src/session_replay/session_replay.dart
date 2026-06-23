import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'capture/frame_processor.dart';
import 'capture/node_id_registry.dart';
import 'capture/render_walker.dart';
import 'ir/ir_node.dart';
import 'perf/frame_timings.dart';
import 'rrweb/event.dart';
import 'rrweb/full_snapshot_builder.dart';

class SessionReplay {
  static PointerRoute? _touchHandler;
  static Timer? _liveTimer;
  static FrameProcessor? _frameProcessor;

  static IRNode? captureCurrentFrame({NodeIdRegistry? idRegistry}) {
    final root = WidgetsBinding.instance.rootElement?.renderObject;
    if (root == null) return null;
    return RenderWalker(idRegistry: idRegistry).walk(root);
  }

  static FullSnapshotEvent? buildFullSnapshot({NodeIdRegistry? idRegistry}) {
    final ir = captureCurrentFrame(idRegistry: idRegistry);
    if (ir == null) return null;
    return FullSnapshotBuilder().build(
      ir,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static List<RrwebEvent>? buildEvents({
    String href = 'flutter://app',
    NodeIdRegistry? idRegistry,
  }) {
    final ir = captureCurrentFrame(idRegistry: idRegistry);
    if (ir == null) return null;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final viewport = _viewportFromIr(ir);
    final meta = MetaEvent(
      timestamp: ts,
      href: href,
      width: viewport.width.toInt(),
      height: viewport.height.toInt(),
    );
    final full = FullSnapshotBuilder().build(ir, timestamp: ts + 1);
    return [meta, full];
  }

  static IRRect _viewportFromIr(IRNode root) {
    var node = root;
    while (node.bounds == null && node.children.isNotEmpty) {
      node = node.children.first;
    }
    return node.bounds ?? const IRRect(0, 0, 0, 0);
  }

  static void dumpCurrentFrame() {
    final ir = captureCurrentFrame();
    if (ir == null) {
      debugPrint('[SessionReplay] no frame to capture');
      return;
    }
    debugPrint(
      '[SessionReplay] frame nodes=${ir.countNodes()}\n'
      '${ir.toIndentedString()}',
    );
  }

  static void dumpCurrentFrameAsRrweb() {
    final event = buildFullSnapshot();
    if (event == null) {
      debugPrint('[SessionReplay] no frame to capture');
      return;
    }
    final json = const JsonEncoder.withIndent('  ').convert(event.toJson());
    debugPrint('[SessionReplay] rrweb FullSnapshot:\n$json');
  }

  /// Drives session replay: emits a Meta + FullSnapshot on the first tick,
  /// then an IncrementalSnapshot for each changed frame (nothing for an
  /// unchanged frame), forwarding every rrweb event to [onEvent]. Owns a
  /// persistent FrameProcessor (and thus a persistent id registry) so node
  /// ids stay stable across frames. Default cadence ~1 fps.
  static void startSessionReplay({
    required void Function(RrwebEvent event) onEvent,
    Duration interval = const Duration(seconds: 1),
    String href = 'flutter://app',
  }) {
    stopSessionReplay();
    final fp = FrameProcessor(href: href);
    _frameProcessor = fp;
    void tick() {
      if (_frameProcessor != fp) return; // stopped/replaced
      final ts = DateTime.now().millisecondsSinceEpoch;
      for (final e in fp.processCurrentFrame(timestamp: ts)) {
        onEvent(e);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      tick();
      _liveTimer = Timer.periodic(interval, (_) => tick());
    });
  }

  static void stopSessionReplay() {
    _liveTimer?.cancel();
    _liveTimer = null;
    _frameProcessor = null;
  }

  static void startTouchCapture({
    required void Function(RrwebEvent event) onEvent,
  }) {
    stopTouchCapture();
    void handler(PointerEvent event) {
      int? type;
      if (event is PointerDownEvent) {
        type = MouseInteractions.touchStart;
      } else if (event is PointerUpEvent) {
        type = MouseInteractions.touchEnd;
      } else if (event is PointerCancelEvent) {
        type = MouseInteractions.touchCancel;
      }
      if (type == null) return;
      onEvent(IncrementalSnapshotEvent.mouseInteraction(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: type,
        x: event.position.dx,
        y: event.position.dy,
      ));
    }

    _touchHandler = handler;
    GestureBinding.instance.pointerRouter.addGlobalRoute(handler);
  }

  static void stopTouchCapture() {
    final h = _touchHandler;
    if (h != null) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(h);
    }
    _touchHandler = null;
  }

  static FrameTimingStats? captureFrameTimings({int iterations = 30}) {
    if (captureCurrentFrame() == null) return null;

    final walkMs = <double>[];
    final encodeMs = <double>[];
    final jsonMs = <double>[];
    var nodeCount = 0;

    for (var i = 0; i < iterations; i++) {
      final sw1 = Stopwatch()..start();
      final ir = captureCurrentFrame();
      sw1.stop();
      if (ir == null) continue;

      final sw2 = Stopwatch()..start();
      final event = FullSnapshotBuilder().build(ir, timestamp: 0);
      sw2.stop();

      final sw3 = Stopwatch()..start();
      jsonEncode(event.toJson());
      sw3.stop();

      walkMs.add(sw1.elapsedMicroseconds / 1000.0);
      encodeMs.add(sw2.elapsedMicroseconds / 1000.0);
      jsonMs.add(sw3.elapsedMicroseconds / 1000.0);
      nodeCount = ir.countNodes();
    }

    return FrameTimingStats(
      iterations: walkMs.length,
      nodeCount: nodeCount,
      walkMs: walkMs,
      encodeMs: encodeMs,
      jsonMs: jsonMs,
    );
  }

  static void dumpCurrentFrameTimings({int iterations = 30}) {
    final stats = captureFrameTimings(iterations: iterations);
    if (stats == null) {
      debugPrint('[SessionReplay] no frame to capture');
      return;
    }
    debugPrint(stats.report());
  }

  static void dumpCurrentFrameAsRrwebEvents() {
    final events = buildEvents();
    if (events == null) {
      debugPrint('[SessionReplay] no frame to capture');
      return;
    }
    final payload = events.map((e) => e.toJson()).toList();
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    debugPrint('[SessionReplay] rrweb events array:\n$json\n[SessionReplay] end events array');
  }
}
