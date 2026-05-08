import 'dart:typed_data';

// Stockage de blob pas implémenté hors web pour l'instant.
// Les jobs photo lancés sur mobile/desktop ne survivront pas au redémarrage.
Future<bool> putImpl(String key, Uint8List bytes) async => false;
Future<Uint8List?> getImpl(String key) async => null;
Future<void> deleteImpl(String key) async {}
