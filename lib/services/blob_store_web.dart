import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('cvIdb.put')
external JSPromise<JSAny?> _put(String key, String b64);
@JS('cvIdb.get')
external JSPromise<JSAny?> _get(String key);
@JS('cvIdb.del')
external JSPromise<JSAny?> _del(String key);

Future<bool> putImpl(String key, Uint8List bytes) async {
  try {
    final b64 = base64Encode(bytes);
    await _put(key, b64).toDart;
    return true;
  } catch (_) {
    return false;
  }
}

Future<Uint8List?> getImpl(String key) async {
  try {
    final result = await _get(key).toDart;
    if (result == null) return null;
    final s = (result as JSString).toDart;
    if (s.isEmpty) return null;
    return base64Decode(s);
  } catch (_) {
    return null;
  }
}

Future<void> deleteImpl(String key) async {
  try {
    await _del(key).toDart;
  } catch (_) {}
}
