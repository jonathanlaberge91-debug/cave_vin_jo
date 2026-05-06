import 'dart:typed_data';

Future<String?> recognizeImpl(Uint8List bytes) async {
  // OCR via Tesseract.js disponible uniquement sur web pour l'instant.
  // Sur mobile/desktop, on retourne null et le flux IA fonctionne sans hint.
  return null;
}
