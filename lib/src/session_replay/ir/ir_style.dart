// ignore_for_file: deprecated_member_use

import 'package:flutter/painting.dart';

class IRStyle {
  final String? color;
  final String? backgroundColor;
  final String? border;
  final String? borderRadius;
  final String? fontSize;
  final String? fontFamily;
  final String? fontWeight;

  /// CSS overflow ('hidden') for clipping render objects (scroll viewports,
  /// clip rects) — without it, scrolled content paints outside its box (e.g.
  /// a list over the app bar).
  final String? overflow;

  const IRStyle({
    this.color,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.fontSize,
    this.fontFamily,
    this.fontWeight,
    this.overflow,
  });

  static const empty = IRStyle();

  bool get isEmpty =>
      color == null &&
      backgroundColor == null &&
      border == null &&
      borderRadius == null &&
      fontSize == null &&
      fontFamily == null &&
      fontWeight == null &&
      overflow == null;

  IRStyle copyWith({String? overflow}) => IRStyle(
        color: color,
        backgroundColor: backgroundColor,
        border: border,
        borderRadius: borderRadius,
        fontSize: fontSize,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
        overflow: overflow ?? this.overflow,
      );

  String toCss() {
    final buf = StringBuffer();
    if (backgroundColor != null) buf.write('background-color:$backgroundColor;');
    if (border != null) buf.write('border:$border;');
    if (borderRadius != null) buf.write('border-radius:$borderRadius;');
    if (color != null) buf.write('color:$color;');
    if (fontSize != null) buf.write('font-size:$fontSize;');
    if (fontFamily != null) buf.write("font-family:'$fontFamily';");
    if (fontWeight != null) buf.write('font-weight:$fontWeight;');
    if (overflow != null) buf.write('overflow:$overflow;');
    return buf.toString();
  }

  static String? colorToCss(Color? c) {
    if (c == null || c.alpha == 0) return null;
    if (c.alpha == 255) return 'rgb(${c.red},${c.green},${c.blue})';
    final a = (c.alpha / 255.0).toStringAsFixed(2);
    return 'rgba(${c.red},${c.green},${c.blue},$a)';
  }
}
