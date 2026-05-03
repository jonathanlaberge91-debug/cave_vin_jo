import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _nextId = 0;

String _objectFitCss(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
    default:
      return 'cover';
  }
}

Widget buildWebImage({
  required String url,
  required double width,
  required double height,
  required BoxFit fit,
}) {
  final viewType = 'native-img-${_nextId++}';
  final objectFit = _objectFitCss(fit);
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
    final img = web.document.createElement('img') as web.HTMLImageElement;
    img.src = url;
    img.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = objectFit
      ..display = 'block';
    return img;
  });
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(viewType: viewType),
  );
}
