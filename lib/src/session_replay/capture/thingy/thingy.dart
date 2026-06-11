import 'package:flutter/rendering.dart';

import '../../ir/ir_style.dart';

class ThingyResult {
  final String type;
  final String? text;
  final IRStyle style;

  const ThingyResult({
    required this.type,
    this.text,
    this.style = IRStyle.empty,
  });
}

abstract class Thingy {
  bool matches(RenderObject node);
  ThingyResult mapTo(RenderObject node);
}
