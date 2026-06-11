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
