import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('web/icons/logo JL aucun fond.png').readAsBytesSync();
  final src = img.decodePng(bytes)!;
  print('Source: ${src.width}x${src.height} channels=${src.numChannels}');

  final out = img.Image(width: src.width, height: src.height, numChannels: 4);

  for (int y = 0; y < src.height; y++) {
    for (int x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();

      final maxC = max(r, max(g, b));
      final minC = min(r, min(g, b));
      final lum = (r + g + b) / 3.0;
      final sat = maxC > 0 ? (maxC - minC) / maxC : 0.0;

      if (sat < 0.12 && lum > 200) {
        // White/near-white background → fully transparent
        out.setPixelRgba(x, y, 0, 0, 0, 0);
      } else if (sat < 0.12 && lum > 160) {
        // Transition zone → partial transparency for smooth edges
        final alpha = ((200 - lum) / 40.0 * 255).round().clamp(0, 255);
        out.setPixelRgba(x, y, r, g, b, alpha);
      } else {
        // Gold/colored pixel → fully opaque
        out.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  // Auto-crop transparent edges
  int top = 0, bottom = out.height - 1, left = 0, right = out.width - 1;

  bool rowEmpty(int y) {
    for (int x = 0; x < out.width; x++) {
      if (out.getPixel(x, y).a > 0) return false;
    }
    return true;
  }
  bool colEmpty(int x) {
    for (int y = 0; y < out.height; y++) {
      if (out.getPixel(x, y).a > 0) return false;
    }
    return true;
  }

  while (top < bottom && rowEmpty(top)) top++;
  while (bottom > top && rowEmpty(bottom)) bottom--;
  while (left < right && colEmpty(left)) left++;
  while (right > left && colEmpty(right)) right--;

  // Add small padding
  const pad = 4;
  top = (top - pad).clamp(0, out.height - 1);
  bottom = (bottom + pad).clamp(0, out.height - 1);
  left = (left - pad).clamp(0, out.width - 1);
  right = (right + pad).clamp(0, out.width - 1);

  final cropped = img.copyCrop(out, x: left, y: top, width: right - left + 1, height: bottom - top + 1);
  print('Output: ${cropped.width}x${cropped.height}');

  File('assets/images/logo.png').writeAsBytesSync(img.encodePng(cropped, level: 6));
  print('Done → assets/images/logo.png');
}
