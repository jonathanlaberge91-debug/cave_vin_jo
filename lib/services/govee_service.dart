import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GoveeSensor {
  final String device;
  final String sku;
  final String name;
  final double? temperature;
  final double? humidity;
  final bool online;

  GoveeSensor({
    required this.device,
    required this.sku,
    required this.name,
    this.temperature,
    this.humidity,
    this.online = false,
  });
}

class GoveeReading {
  final DateTime timestamp;
  final double? temperature;
  final double? humidity;
  GoveeReading({required this.timestamp, this.temperature, this.humidity});
}

class GoveeService {
  static const _keyPref = 'govee_api_key';
  static const _cachePref = 'govee_sensors_cache';
  static const _cloudUrl = 'https://us-east1-cave-vin-jo.cloudfunctions.net/tuyaProxy';
  static final _settingsDoc =
      FirebaseFirestore.instance.collection('settings').doc('app');
  static final _readings =
      FirebaseFirestore.instance.collection('goveeReadings');
  static String? _apiKey;
  static final Map<String, DateTime> _lastWriteAt = {};

  static String? get apiKey => _apiKey;
  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  static set apiKey(String? key) {
    _apiKey = key;
    _persist(key);
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_keyPref);
    try {
      final snap = await _settingsDoc.get();
      final remote = snap.data()?['goveeApiKey'] as String?;
      if (remote != null && remote.isNotEmpty) {
        _apiKey = remote;
        await prefs.setString(_keyPref, remote);
      } else if (_apiKey != null && _apiKey!.isNotEmpty) {
        await _settingsDoc
            .set({'goveeApiKey': _apiKey}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  static Future<void> _persist(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_keyPref);
      try {
        await _settingsDoc.set(
            {'goveeApiKey': FieldValue.delete()}, SetOptions(merge: true));
      } catch (_) {}
    } else {
      await prefs.setString(_keyPref, key);
      try {
        await _settingsDoc
            .set({'goveeApiKey': key}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  static Future<List<GoveeSensor>> loadCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachePref);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => GoveeSensor(
        device: e['device'] ?? '',
        sku: e['sku'] ?? '',
        name: e['name'] ?? '',
        temperature: (e['temperature'] as num?)?.toDouble(),
        humidity: (e['humidity'] as num?)?.toDouble(),
        online: e['online'] == true,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCache(List<GoveeSensor> sensors) async {
    final prefs = await SharedPreferences.getInstance();
    final json = sensors.map((s) => {
      'device': s.device,
      'sku': s.sku,
      'name': s.name,
      'temperature': s.temperature,
      'humidity': s.humidity,
      'online': s.online,
    }).toList();
    await prefs.setString(_cachePref, jsonEncode(json));
  }

  static Future<List<GoveeSensor>> fetchDevices() async {
    if (!isConfigured) return [];
    try {
      final res = await http.get(
        Uri.parse('$_cloudUrl/govee/devices'),
        headers: {'X-Govee-Key': _apiKey!},
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List;
      return list.map((e) => GoveeSensor(
        device: e['device'] ?? '',
        sku: e['sku'] ?? '',
        name: e['name'] ?? '',
      )).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> recordReading(GoveeSensor s) async {
    if (s.temperature == null && s.humidity == null) return;
    final last = _lastWriteAt[s.device];
    final now = DateTime.now();
    if (last != null && now.difference(last).inMinutes < 5) return;
    _lastWriteAt[s.device] = now;
    try {
      await _readings.add({
        'device': s.device,
        'timestamp': Timestamp.fromDate(now),
        'temperature': s.temperature,
        'humidity': s.humidity,
      });
    } catch (_) {}
  }

  static Future<List<GoveeReading>> getHistory(
    String device, {
    required Duration window,
  }) async {
    final since = DateTime.now().subtract(window);
    try {
      final snap = await _readings
          .where('device', isEqualTo: device)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('timestamp')
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        return GoveeReading(
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          temperature: (data['temperature'] as num?)?.toDouble(),
          humidity: (data['humidity'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<GoveeSensor?> fetchStatus(String device, String sku, String name) async {
    if (!isConfigured) return null;
    try {
      final res = await http.post(
        Uri.parse('$_cloudUrl/govee/status'),
        headers: {
          'Content-Type': 'application/json',
          'X-Govee-Key': _apiKey!,
        },
        body: jsonEncode({'device': device, 'sku': sku}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return GoveeSensor(
        device: device,
        sku: sku,
        name: name,
        temperature: (data['temperature'] as num?)?.toDouble(),
        humidity: (data['humidity'] as num?)?.toDouble(),
        online: data['online'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}
