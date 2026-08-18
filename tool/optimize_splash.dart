// Genere le logo du splash (ecran de demarrage web) a partir de l'original
// conserve dans assets/images/logo.png.
//
// Hauteur 900 px = plus du double de la taille d'affichage maximale (40vmin),
// donc net meme sur ecran retina. Sortie en JPEG aplati sur le fond exact du
// splash (#0E0C0A) : invisible a l'oeil, mais bien plus leger qu'un PNG.
//   dart run tool/optimize_splash.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/images/logo.png').readAsBytesSync())!;
  stdout.writeln('Source : ${src.width}x${src.height}');

  const targetH = 900;
  final resized = img.copyResize(
    src,
    height: targetH,
    width: (src.width * targetH / src.height).round(),
    interpolation: img.Interpolation.cubic,
  );

  // Aplatit la transparence sur le fond du splash.
  final flat = img.Image(width: resized.width, height: resized.height);
  img.fill(flat, color: img.ColorRgb8(0x0E, 0x0C, 0x0A));
  img.compositeImage(flat, resized);

  final png = File('web/splash-logo.png');
  final jpg = File('web/splash-logo.jpg');
  final before = png.existsSync() ? png.lengthSync() : 0;
  jpg.writeAsBytesSync(img.encodeJpg(flat, quality: 92));
  stdout.writeln('Sortie : ${flat.width}x${flat.height} — '
      'PNG ${(before / 1024).round()} Ko -> JPEG '
      '${(jpg.lengthSync() / 1024).round()} Ko');
}
