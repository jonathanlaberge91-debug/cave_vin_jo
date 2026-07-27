import 'package:flutter/material.dart';

Widget buildWebImage({
  required String url,
  required double width,
  required double height,
  required BoxFit fit,
  bool eager = false,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: Image.network(url, width: width, height: height, fit: fit),
  );
}

/// Sans objet hors du web : le cache image de Flutter s'en charge.
void precacheWebImage(String url) {}
