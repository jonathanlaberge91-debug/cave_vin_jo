import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppText {
  static final _serifBase = GoogleFonts.cormorantGaramond();
  static final _sansBase = GoogleFonts.dmSans();

  static String get serifFamily => _serifBase.fontFamily!;
  static String get sansFamily => _sansBase.fontFamily!;

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
