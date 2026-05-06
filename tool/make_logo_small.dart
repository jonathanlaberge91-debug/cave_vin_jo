import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/images/logo.png').readAsBytesSync();
  final src = img.decodePng(bytes)!;
  print('Source: ${src.width}x${src.height}');

  // Create a version at 3x the display size (48px * 3 = 144px height)
  // This gives sharp rendering on high-DPI screens without massive decode overhead
  final targetH = 144;
  final targetW = (src.width * targetH / src.height).round();

  final resized = img.copyResize(
    src,
    width: targetW,
    height: targetH,
    interpolation: img.Interpolation.average,
  );
  print('Output: ${resized.width}x${resized.height}');

  File('assets/images/logo_small.png').writeAsBytesSync(img.encodePng(resized, level: 6));
  print('Done → assets/images/logo_small.png');
}
