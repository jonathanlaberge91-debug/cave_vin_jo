import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Réduit et recompresse une photo avant l'envoi vers Firebase Storage.
///
/// Les photos de bouteilles étaient stockées en pleine résolution (plusieurs
/// Mo) puis affichées en vignettes de quelques dizaines de pixels : le
/// téléchargement et le décodage plein format rendaient la cave lente. On
/// borne donc la plus grande dimension à [maxDim] et on encode en JPEG
/// [quality]. Une photo passe typiquement de ~2-4 Mo à ~150-250 Ko sans
/// différence visible à l'écran ni sur la fiche détaillée.
///
/// Si le décodage échoue (format non supporté, ex. HEIC) ou si l'image est
/// déjà plus petite que [maxDim], on renvoie les octets d'origine.
Uint8List compressForUpload(
  Uint8List bytes, {
  int maxDim = 1400,
  int quality = 82,
}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final longest = decoded.width >= decoded.height
        ? decoded.width
        : decoded.height;

    final img.Image work;
    if (longest > maxDim) {
      work = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxDim)
          : img.copyResize(decoded, height: maxDim);
    } else {
      work = decoded;
    }

    final out = Uint8List.fromList(img.encodeJpg(work, quality: quality));

    // Si la recompression n'a rien gagné (petite image déjà optimisée),
    // garder l'original pour ne pas dégrader inutilement.
    if (work == decoded && out.length >= bytes.length) return bytes;
    return out;
  } catch (_) {
    return bytes;
  }
}
