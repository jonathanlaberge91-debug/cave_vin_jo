import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  static final _storage = FirebaseStorage.instance;
  static const _uploadTimeout = Duration(seconds: 45);

  static String _mimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  static Future<String> uploadWinePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path = 'wines/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    // ignore: avoid_print
    print('[Storage] START upload bytes=${bytes.length} (${(bytes.length / 1024).toStringAsFixed(0)} Ko) path=$path');
    final ref = _storage.ref().child(path);
    try {
      final task = await ref
          .putData(bytes, SettableMetadata(contentType: _mimeType(fileName)))
          .timeout(_uploadTimeout, onTimeout: () {
        throw TimeoutException(
          'Upload de la photo trop long. Vérifie les règles Firebase Storage et le CORS du bucket.',
        );
      });
      // ignore: avoid_print
      print('[Storage] putData OK bytesTransferred=${task.bytesTransferred}');
      final url = await ref.getDownloadURL().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Récupération de l\'URL de la photo trop longue.',
            ),
          );
      // ignore: avoid_print
      print('[Storage] URL=$url');
      return url;
    } on FirebaseException catch (e, st) {
      developer.log(
        '[Storage] FirebaseException code=${e.code} msg=${e.message}',
        name: 'cave_vin_jo',
        error: e,
        stackTrace: st,
      );
      throw Exception(
        'Erreur Firebase Storage (${e.code}) : ${e.message ?? "voir console Firebase"}',
      );
    } catch (e, st) {
      developer.log(
        '[Storage] OTHER exception: $e',
        name: 'cave_vin_jo',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

}
