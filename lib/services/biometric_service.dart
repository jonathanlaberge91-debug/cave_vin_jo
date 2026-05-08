import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'biometric_platform.dart' as platform;

class BiometricService {
  static const _enabledKey = 'biometric_enabled';
  static final LocalAuthentication _auth = LocalAuthentication();

  /// True si le verrouillage est activé sur cet appareil (réglage local).
  static final ValueNotifier<bool> enabled = ValueNotifier(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_enabledKey) ?? false;
  }

  static Future<bool> isSupported() async {
    if (kIsWeb) return platform.webIsSupported();
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck && supported;
    } catch (_) {
      return false;
    }
  }

  static CollectionReference<Map<String, dynamic>>? _passkeysCol() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('passkeys');
  }

  static Future<List<String>> _fetchUserCredIds() async {
    final col = _passkeysCol();
    if (col == null) return const [];
    try {
      final snap = await col.get();
      return snap.docs
          .map((d) => d.data()['credId'] as String?)
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> _addCredId(String credId) async {
    final col = _passkeysCol();
    if (col == null) return;
    try {
      await col.add({
        'credId': credId,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.toString(),
      });
    } catch (_) {}
  }

  /// Supprime toutes les passkeys de l'utilisateur courant (toutes plateformes).
  static Future<void> clearAllPasskeys() async {
    final col = _passkeysCol();
    if (col == null) return;
    try {
      final snap = await col.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  static Future<bool> authenticate({
    String reason = 'Authentifie-toi pour ouvrir la cave',
  }) async {
    if (kIsWeb) {
      final credIds = await _fetchUserCredIds();
      if (credIds.isEmpty) return false;
      return platform.webAuthenticate(credIds);
    }
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Active ou désactive le verrouillage. Sur web, l'activation tente
  /// d'abord d'utiliser une passkey existante (potentiellement synchronisée
  /// via iCloud / Google Password Manager) ; sinon, en enregistre une nouvelle
  /// et la sauve dans Firestore.
  static Future<bool> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!value) {
      enabled.value = false;
      await prefs.setBool(_enabledKey, false);
      return true;
    }

    if (kIsWeb) {
      final existing = await _fetchUserCredIds();
      if (existing.isNotEmpty) {
        final ok = await platform.webAuthenticate(existing);
        if (ok) {
          enabled.value = true;
          await prefs.setBool(_enabledKey, true);
          return true;
        }
      }
      final newCredId = await platform.webRegister();
      if (newCredId == null || newCredId.isEmpty) return false;
      await _addCredId(newCredId);
      enabled.value = true;
      await prefs.setBool(_enabledKey, true);
      return true;
    }

    final ok = await authenticate(reason: 'Active le verrouillage biométrique');
    if (!ok) return false;
    enabled.value = true;
    await prefs.setBool(_enabledKey, true);
    return true;
  }
}
