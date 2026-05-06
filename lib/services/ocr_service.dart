import 'dart:typed_data';

import 'ocr_service_web.dart' if (dart.library.io) 'ocr_service_mobile.dart'
    as platform;

class OcrService {
  /// Extrait le texte d'une image via Tesseract.js (web only).
  /// Retourne `null` si OCR indisponible ou échoue.
  static Future<String?> recognize(Uint8List bytes) async {
    try {
      return await platform.recognizeImpl(bytes);
    } catch (_) {
      return null;
    }
  }
}
