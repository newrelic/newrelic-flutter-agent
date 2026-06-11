import 'package:flutter/rendering.dart';

import '../../ir/ir_style.dart';
import 'thingy.dart';

class ThingyRegistry {
  final List<Thingy> _thingies;

  ThingyRegistry(this._thingies);

  factory ThingyRegistry.defaults() => ThingyRegistry(const [
        _ParagraphThingy(),
        _DecoratedBoxThingy(),
        _PhysicalShapeThingy(),
        _ImageThingy(),
        _EditableThingy(),
      ]);

  ThingyResult classify(RenderObject node) {
    for (final t in _thingies) {
      if (t.matches(node)) return t.mapTo(node);
    }
    return const ThingyResult(type: 'box');
  }
}

class _ParagraphThingy implements Thingy {
  const _ParagraphThingy();

  @override
  bool matches(RenderObject node) => node is RenderParagraph;

  @override
  ThingyResult mapTo(RenderObject node) {
    final p = node as RenderParagraph;
    final text = p.text.toPlainText();
    final rootStyle = _rootStyle(p.text);
    final isIcon = _looksLikeIcon(text, rootStyle);

    return ThingyResult(
      type: isIcon ? 'icon' : 'paragraph',
      text: text,
      style: IRStyle(
        color: IRStyle.colorToCss(rootStyle?.color),
        fontSize: rootStyle?.fontSize != null
            ? '${rootStyle!.fontSize!.toStringAsFixed(1)}px'
            : null,
        fontFamily: rootStyle?.fontFamily,
        fontWeight: rootStyle?.fontWeight?.value.toString(),
      ),
    );
  }

  TextStyle? _rootStyle(InlineSpan span) =>
      span is TextSpan ? span.style : null;

  bool _looksLikeIcon(String text, TextStyle? style) {
    if (text.length != 1) return false;
    final code = text.codeUnitAt(0);
    final inPua = code >= 0xE000 && code <= 0xF8FF;
    final fam = style?.fontFamily ?? '';
    return inPua || fam.contains('Icons') || fam.contains('icons');
  }
}

class _DecoratedBoxThingy implements Thingy {
  const _DecoratedBoxThingy();

  @override
  bool matches(RenderObject node) => node is RenderDecoratedBox;

  @override
  ThingyResult mapTo(RenderObject node) {
    final dec = (node as RenderDecoratedBox).decoration;
    if (dec is! BoxDecoration) return const ThingyResult(type: 'box');
    return ThingyResult(
      type: 'box',
      style: IRStyle(
        backgroundColor: IRStyle.colorToCss(dec.color),
        border: _border(dec.border),
        borderRadius: _radius(dec.borderRadius),
      ),
    );
  }

  String? _border(BoxBorder? b) {
    if (b is! Border) return null;
    final t = b.top;
    if (t.style != BorderStyle.solid || t.width == 0) return null;
    final color = IRStyle.colorToCss(t.color) ?? 'currentColor';
    return '${t.width.toStringAsFixed(1)}px solid $color';
  }

  String? _radius(BorderRadiusGeometry? r) {
    if (r is! BorderRadius) return null;
    final tl = r.topLeft.x;
    final tr = r.topRight.x;
    final bl = r.bottomLeft.x;
    final br = r.bottomRight.x;
    if (tl == tr && tr == bl && bl == br) {
      return tl == 0 ? null : '${tl.toStringAsFixed(1)}px';
    }
    return '${tl.toStringAsFixed(1)}px ${tr.toStringAsFixed(1)}px '
        '${br.toStringAsFixed(1)}px ${bl.toStringAsFixed(1)}px';
  }
}

class _PhysicalShapeThingy implements Thingy {
  const _PhysicalShapeThingy();

  @override
  bool matches(RenderObject node) => node is RenderPhysicalShape;

  @override
  ThingyResult mapTo(RenderObject node) {
    final n = node as RenderPhysicalShape;
    return ThingyResult(
      type: 'box',
      style: IRStyle(
        backgroundColor: IRStyle.colorToCss(n.color),
      ),
    );
  }
}

class _ImageThingy implements Thingy {
  const _ImageThingy();

  @override
  bool matches(RenderObject node) => node is RenderImage;

  @override
  ThingyResult mapTo(RenderObject node) => const ThingyResult(type: 'image');
}

class _EditableThingy implements Thingy {
  const _EditableThingy();

  @override
  bool matches(RenderObject node) => node is RenderEditable;

  @override
  ThingyResult mapTo(RenderObject node) {
    final e = node as RenderEditable;
    return ThingyResult(
      type: 'editable',
      text: e.text?.toPlainText(),
    );
  }
}
