import 'package:flutter/material.dart';

class AppText {
  static const serifFamily = 'CormorantGaramond';
  static const sansFamily = 'DMSans';

  static const _emojiFallback = [
    'Noto Color Emoji',
    'Apple Color Emoji',
    'Segoe UI Emoji',
  ];

  static TextStyle serif({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) =>
      TextStyle(
        fontFamily: serifFamily,
        fontFamilyFallback: _emojiFallback,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
      );

  static TextStyle sans({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _emojiFallback,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
      );

  static TextStyle emoji({double fontSize = 16}) => TextStyle(
        fontFamily: _emojiFallback.first,
        fontFamilyFallback: _emojiFallback,
        fontSize: fontSize,
      );
}
