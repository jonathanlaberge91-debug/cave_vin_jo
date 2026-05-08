import 'dart:typed_data';

import 'blob_store_web.dart' if (dart.library.io) 'blob_store_mobile.dart'
    as platform;

class BlobStore {
  static Future<bool> put(String key, Uint8List bytes) =>
      platform.putImpl(key, bytes);
  static Future<Uint8List?> get(String key) => platform.getImpl(key);
  static Future<void> delete(String key) => platform.deleteImpl(key);
}
