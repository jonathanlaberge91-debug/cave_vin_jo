import 'package:flutter/material.dart';

Widget buildWebImage({
  required String url,
  required double width,
  required double height,
  required BoxFit fit,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: Image.network(url, width: width, height: height, fit: fit),
  );
}
