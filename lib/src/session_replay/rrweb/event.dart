import 'mutation_records.dart';
import 'serialized_node.dart';

abstract class RrwebEvent {
  Map<String, dynamic> toJson();
}

class FullSnapshotEvent extends RrwebEvent {
  static const int eventType = 2;

  final int timestamp;
  final SerializedNode node;
  final int initialOffsetLeft;
  final int initialOffsetTop;

  FullSnapshotEvent({
    required this.timestamp,
    required this.node,
    this.initialOffsetLeft = 0,
    this.initialOffsetTop = 0,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': eventType,
        'data': {
          'node': node.toJson(),
          'initialOffset': {
            'left': initialOffsetLeft,
            'top': initialOffsetTop,
          },
        },
        'timestamp': timestamp,
      };
}

class IncrementalSource {
  static const int mutation = 0;
  static const int mouseMove = 1;
  static const int mouseInteraction = 2;
  static const int scroll = 3;
  static const int viewportResize = 4;
  static const int input = 5;
  static const int touchMove = 6;
}

class MouseInteractions {
  static const int mouseUp = 0;
  static const int mouseDown = 1;
  static const int click = 2;
  static const int touchStart = 7;
  static const int touchEnd = 9;
  static const int touchCancel = 10;
}

class IncrementalSnapshotEvent extends RrwebEvent {
  static const int eventType = 3;

  final int timestamp;
  final int source;
  final Map<String, dynamic> sourceData;

  IncrementalSnapshotEvent({
    required this.timestamp,
    required this.source,
    required this.sourceData,
  });

  factory IncrementalSnapshotEvent.mouseInteraction({
    required int timestamp,
    required int type,
    required double x,
    required double y,
    int nodeId = 1,
  }) =>
      IncrementalSnapshotEvent(
        timestamp: timestamp,
        source: IncrementalSource.mouseInteraction,
        sourceData: {
          'type': type,
          'id': nodeId,
          'x': x,
          'y': y,
        },
      );

  factory IncrementalSnapshotEvent.mutation({
    required int timestamp,
    required MutationData data,
  }) =>
      IncrementalSnapshotEvent(
        timestamp: timestamp,
        source: IncrementalSource.mutation,
        sourceData: data.toJson(),
      );

  @override
  Map<String, dynamic> toJson() => {
        'type': eventType,
        'data': {'source': source, ...sourceData},
        'timestamp': timestamp,
      };
}

class MetaEvent extends RrwebEvent {
  static const int eventType = 4;

  final int timestamp;
  final String href;
  final int width;
  final int height;

  MetaEvent({
    required this.timestamp,
    required this.href,
    required this.width,
    required this.height,
  });

  @override
  Map<String, dynamic> toJson() => {
        'type': eventType,
        'data': {'href': href, 'width': width, 'height': height},
        'timestamp': timestamp,
      };
}
