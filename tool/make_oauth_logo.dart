// Génère un logo 512x512 carré avec fond foncé pour la page OAuth Google.
// Lance : dart run tool/make_oauth_logo.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = File('assets/images/logo.png').readAsBytesSync();
  final original = img.decodeImage(src);
  if (original == null) {
    print('Impossible de décoder logo.png');
    exit(1);
  }

  const targetSize = 512;
  const padding = 64; // marge autour du logo
  const inner = targetSize - 2 * padding;

  // Redimensionne en gardant ratio pour tenir dans inner x inner
  final ratio = original.width / original.height;
  int w, h;
  if (ratio > 1) {
    w = inner;
    h = (inner / ratio).round();
  } else {
    h = inner;
    w = (inner * ratio).round();
  }
  final resized = img.copyResize(original,
      width: w, height: h, interpolation: img.Interpolation.cubic);

  // Crée canvas carré avec fond bg2 (#171410) du thème
  final canvas = img.Image(width: targetSize, height: targetSize);
  img.fill(canvas, color: img.ColorRgba8(23, 20, 16, 255));

  // Centre le logo
  final dx = (targetSize - w) ~/ 2;
  final dy = (targetSize - h) ~/ 2;
  img.compositeImage(canvas, resized, dstX: dx, dstY: dy);

  // Sauvegarde JPG (plus petit, sans transparence — Google préfère)
  final jpg = img.encodeJpg(canvas, quality: 92);
  File('assets/images/logo_oauth_512.jpg').writeAsBytesSync(jpg);
  print('✓ Créé assets/images/logo_oauth_512.jpg (${jpg.length ~/ 1024} KB)');

  // Aussi version PNG transparente au cas où
  final canvasTransparent = img.Image(width: targetSize, height: targetSize);
  img.compositeImage(canvasTransparent, resized, dstX: dx, dstY: dy);
  final png = img.encodePng(canvasTransparent);
  File('assets/images/logo_oauth_512.png').writeAsBytesSync(png);
  print('✓ Créé assets/images/logo_oauth_512.png (${png.length ~/ 1024} KB)');
}
