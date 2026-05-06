import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_service_web.dart' if (dart.library.io) 'backup_service_mobile.dart'
    as platform;
import 'drive_backup_service.dart';

enum BackupResult { driveUploaded, downloaded, failed }

class BackupService {
  static const _lastBackupKey = 'backup_last_at';
  static const _autoBackupKey = 'backup_auto_enabled';

  static final ValueNotifier<DateTime?> lastBackupAt =
      ValueNotifier<DateTime?>(null);
  static final ValueNotifier<bool> autoBackupEnabled =
      ValueNotifier<bool>(false);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_lastBackupKey);
    if (ts != null) {
      lastBackupAt.value = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    autoBackupEnabled.value = prefs.getBool(_autoBackupKey) ?? false;
  }

  static Future<void> setAutoBackup(bool enabled) async {
    autoBackupEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoBackupKey, enabled);
  }

  static Future<void> _saveLastBackup(DateTime t) async {
    lastBackupAt.value = t;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastBackupKey, t.millisecondsSinceEpoch);
  }

  static Future<Map<String, dynamic>> exportToJson() async {
    final db = FirebaseFirestore.instance;

    Future<List<Map<String, dynamic>>> dump(String coll) async {
      final snap = await db.collection(coll).get();
      return snap.docs
          .map((d) => {'id': d.id, ..._sanitize(d.data())})
          .toList();
    }

    final wines = await dump('wines');
    for (final w in wines) {
      final id = w['id'] as String;
      final mh = await db
          .collection('wines')
          .doc(id)
          .collection('marketHistory')
          .get();
      final gh = await db
          .collection('wines')
          .doc(id)
          .collection('gardeHistory')
          .get();
      w['_marketHistory'] = mh.docs
          .map((d) => {'id': d.id, ..._sanitize(d.data())})
          .toList();
      w['_gardeHistory'] = gh.docs
          .map((d) => {'id': d.id, ..._sanitize(d.data())})
          .toList();
    }

    final bottles = await dump('bottles');
    final cellars = await dump('cellars');
    final wishlist = await dump('wishlist');

    final settingsSnap = await db.collection('settings').doc('app').get();
    final settings = settingsSnap.exists ? _sanitize(settingsSnap.data()!) : {};

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'cave_vin_jo',
      'collections': {
        'wines': wines,
        'bottles': bottles,
        'cellars': cellars,
        'wishlist': wishlist,
      },
      'settings': settings,
    };
  }

  static Map<String, dynamic> _sanitize(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    for (final e in m.entries) {
      out[e.key] = _sanitizeValue(e.value);
    }
    return out;
  }

  static dynamic _sanitizeValue(dynamic v) {
    if (v is Timestamp) {
      return {'__type': 'timestamp', 'value': v.toDate().toIso8601String()};
    }
    if (v is GeoPoint) {
      return {'__type': 'geopoint', 'lat': v.latitude, 'lng': v.longitude};
    }
    if (v is DocumentReference) {
      return {'__type': 'ref', 'path': v.path};
    }
    if (v is Map) {
      return {for (final e in v.entries) e.key.toString(): _sanitizeValue(e.value)};
    }
    if (v is List) {
      return v.map(_sanitizeValue).toList();
    }
    return v;
  }

  static Future<void> downloadBackup() async {
    final data = await exportToJson();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final stamp = _stamp();
    platform.downloadJsonImpl(json, 'cave_backup_$stamp.json');
    await _saveLastBackup(DateTime.now());
  }

  /// Tente Drive si connecté, sinon download local.
  static Future<BackupResult> performBackup() async {
    final data = await exportToJson();
    final json = const JsonEncoder.withIndent('  ').convert(data);
    final stamp = _stamp();
    final filename = 'cave_backup_$stamp.json';

    if (DriveBackupService.isConnected.value) {
      try {
        final ok = await DriveBackupService.uploadJson(json, filename);
        if (ok) {
          await _saveLastBackup(DateTime.now());
          return BackupResult.driveUploaded;
        }
      } catch (_) {}
    }

    try {
      platform.downloadJsonImpl(json, filename);
      await _saveLastBackup(DateTime.now());
      return BackupResult.downloaded;
    } catch (_) {
      return BackupResult.failed;
    }
  }

  static String _stamp() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}_${n.hour.toString().padLeft(2, '0')}${n.minute.toString().padLeft(2, '0')}';
  }

  static Future<bool> tryAutoBackup() async {
    if (!autoBackupEnabled.value) return false;
    final last = lastBackupAt.value;
    final now = DateTime.now();
    if (last != null && now.difference(last).inHours < 24) return false;

    // Si Drive connecté → upload silencieux. Sinon, on saute (pas de
    // download surprise auto). L'utilisateur peut toujours backup manuel.
    if (!DriveBackupService.isConnected.value) return false;

    try {
      final result = await performBackup();
      return result == BackupResult.driveUploaded;
    } catch (_) {
      return false;
    }
  }
}
