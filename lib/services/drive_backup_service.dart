import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'drive_oauth_web.dart' if (dart.library.io) 'drive_oauth_mobile.dart';

class DriveBackupService {
  static const _clientIdKey = 'drive_oauth_client_id';
  static const _scope = 'https://www.googleapis.com/auth/drive.file';
  static const _backupFolder = 'Cave a Vin Backups';

  static String? _clientId;
  static String? _folderId;

  static final ValueNotifier<String?> currentEmail =
      ValueNotifier<String?>(null);
  static final ValueNotifier<bool> isConfigured = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  static final ValueNotifier<String?> lastError =
      ValueNotifier<String?>(null);

  static String? get clientId => _clientId;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getString(_clientIdKey);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app')
          .get();
      final remote = snap.data()?['driveOAuthClientId'] as String?;
      if (remote != null && remote.isNotEmpty) {
        _clientId = remote;
        await prefs.setString(_clientIdKey, remote);
      } else if (_clientId != null && _clientId!.isNotEmpty) {
        await snap.reference
            .set({'driveOAuthClientId': _clientId}, SetOptions(merge: true));
      }
    } catch (_) {}

    _setup();
  }

  static void _setup() {
    if (_clientId == null || _clientId!.isEmpty) {
      isConfigured.value = false;
      isConnected.value = false;
      currentEmail.value = null;
      return;
    }
    isConfigured.value = true;
  }

  static Future<void> setClientId(String? id) async {
    final trimmed = id?.trim();
    _clientId = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final prefs = await SharedPreferences.getInstance();
    if (_clientId == null) {
      await prefs.remove(_clientIdKey);
    } else {
      await prefs.setString(_clientIdKey, _clientId!);
    }
    try {
      final doc = FirebaseFirestore.instance.collection('settings').doc('app');
      if (_clientId == null) {
        await doc.set({'driveOAuthClientId': FieldValue.delete()},
            SetOptions(merge: true));
      } else {
        await doc.set({'driveOAuthClientId': _clientId},
            SetOptions(merge: true));
      }
    } catch (_) {}

    await DriveOAuthWeb.revoke();
    _folderId = null;
    _setup();
  }

  static Future<bool> connect() async {
    lastError.value = null;
    if (_clientId == null || _clientId!.isEmpty) {
      lastError.value = 'Client ID non configuré';
      return false;
    }
    if (kIsWeb && !DriveOAuthWeb.isGisLoaded) {
      lastError.value =
          'Le SDK Google n\'est pas chargé (recharge la page avec Ctrl+F5)';
      return false;
    }
    try {
      developer.log('requesting GIS token with clientId=$_clientId',
          name: 'drive_backup');
      final token = await DriveOAuthWeb.requestToken(
        clientId: _clientId!,
        scope: _scope,
      );
      if (token == null) {
        lastError.value = 'Aucun access token reçu';
        return false;
      }
      developer.log('got token (len=${token.length}), fetching email',
          name: 'drive_backup');
      final email = await DriveOAuthWeb.fetchEmail(token);
      currentEmail.value = email ?? 'connecté';
      isConnected.value = true;
      return true;
    } catch (e, st) {
      developer.log('connect() exception: $e\n$st', name: 'drive_backup');
      lastError.value = e.toString().replaceFirst('Exception: ', '');
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await DriveOAuthWeb.revoke();
    } catch (_) {}
    isConnected.value = false;
    currentEmail.value = null;
    _folderId = null;
  }

  static Future<String?> _getToken() async {
    if (_clientId == null || _clientId!.isEmpty) return null;
    final cached = DriveOAuthWeb.cachedToken;
    if (cached != null) return cached;
    try {
      final t = await DriveOAuthWeb.requestToken(
        clientId: _clientId!,
        scope: _scope,
        silent: true,
      );
      if (t != null) {
        isConnected.value = true;
      }
      return t;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _ensureFolder(String token) async {
    if (_folderId != null) return _folderId;
    final q = "name='$_backupFolder' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final searchRes = await http.get(
      Uri.parse(
          'https://www.googleapis.com/drive/v3/files?q=${Uri.encodeQueryComponent(q)}&fields=files(id,name)'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (searchRes.statusCode == 200) {
      final data = jsonDecode(searchRes.body) as Map<String, dynamic>;
      final files = data['files'] as List?;
      if (files != null && files.isNotEmpty) {
        _folderId = files.first['id'] as String;
        return _folderId;
      }
    }
    final createRes = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': _backupFolder,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );
    if (createRes.statusCode == 200) {
      final data = jsonDecode(createRes.body) as Map<String, dynamic>;
      _folderId = data['id'] as String;
      return _folderId;
    }
    return null;
  }

  static Future<bool> uploadJson(String json, String filename) async {
    final token = await _getToken();
    if (token == null) return false;
    final folderId = await _ensureFolder(token);
    final metadata = {
      'name': filename,
      if (folderId != null) 'parents': [folderId],
    };
    final boundary = 'cavevinjo${DateTime.now().millisecondsSinceEpoch}';
    final body = '--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '${jsonEncode(metadata)}\r\n'
        '--$boundary\r\n'
        'Content-Type: application/json\r\n\r\n'
        '$json\r\n'
        '--$boundary--';
    final res = await http.post(
      Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
    return res.statusCode == 200;
  }
}
