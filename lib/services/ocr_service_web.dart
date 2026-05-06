import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('cvOcrRecognize')
external JSPromise<JSAny?> _cvOcrRecognize(String base64);

Future<String?> recognizeImpl(Uint8List bytes) async {
  final base64Str = base64Encode(bytes);
  try {
    final result = await _cvOcrRecognize(base64Str).toDart;
    if (result == null) return null;
    final s = result as JSString;
    final text = s.toDart;
    if (text.trim().isEmpty) return null;
    return text;
  } catch (_) {
    return null;
  }
}
