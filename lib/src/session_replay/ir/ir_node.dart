import 'ir_style.dart';

class IRRect {
  final double x;
  final double y;
  final double width;
  final double height;

  const IRRect(this.x, this.y, this.width, this.height);

  String toCompact() =>
      'x=${x.toStringAsFixed(1)} y=${y.toStringAsFixed(1)} '
      'w=${width.toStringAsFixed(1)} h=${height.toStringAsFixed(1)}';
}

class IRNode {
  final String type;
  final String renderType;
  final IRRect? bounds;
  final String? text;
  final IRStyle style;
  final List<IRNode> children;

  /// Stable rrweb id for this node's element, assigned by the walker from a
  /// [NodeIdRegistry] keyed on the backing `RenderObject`. 0 means unassigned
  /// (e.g. hand-built test IR before `assignIds`). Mutable so a registry/test
  /// helper can stamp it after the tree is built.
  int id;

  /// Stable id for the synthetic text child emitted for paragraph/icon nodes.
  int? textId;

  IRNode({
    required this.type,
    required this.renderType,
    this.bounds,
    this.text,
    this.style = IRStyle.empty,
    this.children = const [],
    this.id = 0,
    this.textId,
  });

  String toIndentedString([int depth = 0]) {
    final pad = '  ' * depth;
    final boundsStr = bounds == null ? 'no-bounds' : bounds!.toCompact();
    final textStr = text != null ? ' text="${_truncate(text!, 60)}"' : '';
    final styleStr = style.isEmpty ? '' : ' style="${style.toCss()}"';
    final buf = StringBuffer()
      ..writeln('$pad<$type $boundsStr render=$renderType$textStr$styleStr>');
    for (final child in children) {
      buf.write(child.toIndentedString(depth + 1));
    }
    return buf.toString();
  }

  int countNodes() {
    var n = 1;
    for (final c in children) {
      n += c.countNodes();
    }
    return n;
  }

  static String _truncate(String s, int max) {
    final oneLine = s.replaceAll('\n', ' ');
    return oneLine.length <= max ? oneLine : '${oneLine.substring(0, max)}…';
  }
}
