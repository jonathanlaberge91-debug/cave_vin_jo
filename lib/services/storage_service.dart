import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final _storage = FirebaseStorage.instance;

  static Future<String> uploadWinePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ref = _storage
        .ref()
        .child('wines')
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await ref.getDownloadURL();
  }

  static Future<void> deletePhoto(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
