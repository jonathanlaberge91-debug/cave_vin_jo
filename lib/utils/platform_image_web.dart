import 'dart:typed_data';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _nextId = 0;

String? createBlobUrl(Uint8List bytes) {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/jpeg'),
  );
  return web.URL.createObjectURL(blob);
}

void revokeBlobUrl(String? url) {
  if (url != null) web.URL.revokeObjectURL(url);
}

Widget buildBlobPreview(String blobUrl, {double? width, double? height}) {
  final viewType = 'blob-preview-${_nextId++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
    final img = web.document.createElement('img') as web.HTMLImageElement;
    img.src = blobUrl;
    img.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover'
      ..display = 'block';
    return img;
  });
  return HtmlElementView(viewType: viewType);
}
