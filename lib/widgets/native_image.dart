import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'native_image_web.dart' if (dart.library.io) 'native_image_mobile.dart'
    as platform;

class NativeNetworkImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BoxFit fit;

  const NativeNetworkImage({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return platform.buildWebImage(
        url: url,
        width: width,
        height: height,
        fit: fit,
      );
    }
    // Décode l'image à la taille réellement affichée (× densité de pixels)
    // au lieu de la pleine résolution : une vignette de 64 px n'a pas besoin
    // de décoder une photo de 3000 px, ce qui économise énormément de
    // mémoire et supprime les saccades quand la liste contient beaucoup de
    // bouteilles.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheW = width.isFinite ? (width * dpr).ceil() : null;
    final cacheH = height.isFinite ? (height * dpr).ceil() : null;
    return SizedBox(
      width: width,
      height: height,
      child: Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheW,
        cacheHeight: cacheW == null ? cacheH : null,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1A1814),
          child: const Icon(Icons.broken_image, color: Color(0xFF555555)),
        ),
      ),
    );
  }
}
