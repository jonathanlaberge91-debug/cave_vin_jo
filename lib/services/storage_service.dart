import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/image_utils.dart';

/// URL de la photo d'un vin : l'originale HD (fiche + agrandissement) et une
/// miniature légère (grilles cave/cellier/accueil où plusieurs bouteilles
/// s'affichent d'un coup).
class WinePhotoUrls {
  final String photoUrl; // originale, pleine qualité
  final String thumbUrl; // miniature ~400px, quelques dizaines de Ko

  const WinePhotoUrls({required this.photoUrl, required this.thumbUrl});
}

class StorageService {
  static final _storage = FirebaseStorage.instance;
  static const _uploadTimeout = Duration(seconds: 45);

  // Cache long : chaque upload a une URL unique horodatée, l'image ne change
  // jamais → le navigateur/app peut la garder ~1 an.
  static const _cacheControl = 'public, max-age=31536000, immutable';

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

  static Future<String> _putAndUrl(
    String path,
    Uint8List data,
    String contentType,
  ) async {
    final ref = _storage.ref().child(path);
    final task = await ref
        .putData(
          data,
          SettableMetadata(
            contentType: contentType,
            cacheControl: _cacheControl,
          ),
        )
        .timeout(_uploadTimeout, onTimeout: () {
      throw TimeoutException(
        'Upload de la photo trop long. Vérifie les règles Firebase Storage et le CORS du bucket.',
      );
    });
    // ignore: avoid_print
    print('[Storage] putData OK $path bytesTransferred=${task.bytesTransferred}');
    return ref.getDownloadURL().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'Récupération de l\'URL de la photo trop longue.',
          ),
        );
  }

  /// Téléverse la photo d'un vin : l'originale HD est conservée telle quelle,
  /// et une miniature compressée est générée à côté pour les grilles.
  static Future<WinePhotoUrls> uploadWinePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final origPath = 'wines/${stamp}_$fileName';
    final thumbPath = 'wines/thumbs/${stamp}_$baseName.jpg';

    // Miniature (max 400px, JPEG q80) → quelques dizaines de Ko.
    final thumbBytes = compressForUpload(bytes, maxDim: 400, quality: 80);
    // ignore: avoid_print
    print('[Storage] START upload orig=${(bytes.length / 1024).toStringAsFixed(0)} Ko, thumb=${(thumbBytes.length / 1024).toStringAsFixed(0)} Ko');

    try {
      // Originale HD en premier (c'est la plus importante) puis miniature.
      final photoUrl = await _putAndUrl(origPath, bytes, _mimeType(fileName));
      String thumbUrl;
      try {
        thumbUrl = await _putAndUrl(thumbPath, thumbBytes, 'image/jpeg');
      } catch (e) {
        // Si la miniature échoue, on retombe sur l'originale : rien n'est cassé.
        developer.log('[Storage] thumb upload failed, fallback HD: $e',
            name: 'cave_vin_jo');
        thumbUrl = photoUrl;
      }
      // ignore: avoid_print
      print('[Storage] URL=$photoUrl THUMB=$thumbUrl');
      return WinePhotoUrls(photoUrl: photoUrl, thumbUrl: thumbUrl);
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
