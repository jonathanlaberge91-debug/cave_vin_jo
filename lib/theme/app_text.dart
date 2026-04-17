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
  }) =>
      TextStyle(
        fontFamily: serifFamily,
        fontFamilyFallback: _emojiFallback,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle sans({
    double? fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: sansFamily,
        fontFamilyFallback: _emojiFallback,
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle emoji({double fontSize = 16}) => TextStyle(
        fontFamily: _emojiFallback.first,
        fontFamilyFallback: _emojiFallback,
        fontSize: fontSize,
      );
}
