import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final _storage = FirebaseStorage.instance;
  static const _uploadTimeout = Duration(seconds: 45);

  static Future<String> uploadWinePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final ref = _storage
        .ref()
        .child('wines')
        .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');
    try {
      await ref
          .putData(bytes, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(_uploadTimeout, onTimeout: () {
        throw TimeoutException(
          'Upload de la photo trop long. Vérifie les règles Firebase Storage et le CORS du bucket.',
        );
      });
      return await ref.getDownloadURL().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Récupération de l\'URL de la photo trop longue.',
            ),
          );
    } on FirebaseException catch (e) {
      throw Exception(
        'Erreur Firebase Storage (${e.code}) : ${e.message ?? "voir console Firebase"}',
      );
    }
  }

  static Future<void> deletePhoto(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }
}
