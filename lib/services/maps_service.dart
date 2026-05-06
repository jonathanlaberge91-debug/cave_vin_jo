import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeoCoord {
  final double lat;
  final double lng;
  const GeoCoord(this.lat, this.lng);
}

class MapsService {
  static const _keyPref = 'maps_api_key';
  static final _settingsDoc =
      FirebaseFirestore.instance.collection('settings').doc('app');
  static final _geocache =
      FirebaseFirestore.instance.collection('geocache');
  static String? _apiKey;
  static SharedPreferences? _prefs;

  // In-memory cache — persists across navigations within the same session
  static final Map<String, GeoCoord> _memCache = {};

  static String? get apiKey => _apiKey;
  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  static set apiKey(String? key) {
    _apiKey = key;
    _persist(key);
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _apiKey = prefs.getString(_keyPref);
    try {
      final snap = await _settingsDoc.get();
      final remote = snap.data()?['mapsApiKey'] as String?;
      if (remote != null && remote.isNotEmpty) {
        _apiKey = remote;
        await prefs.setString(_keyPref, remote);
      } else if (_apiKey != null && _apiKey!.isNotEmpty) {
        await _settingsDoc
            .set({'mapsApiKey': _apiKey}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  static Future<void> _persist(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_keyPref);
      try {
        await _settingsDoc.set(
            {'mapsApiKey': FieldValue.delete()}, SetOptions(merge: true));
      } catch (_) {}
    } else {
      await prefs.setString(_keyPref, key);
      try {
        await _settingsDoc
            .set({'mapsApiKey': key}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  static Future<GeoCoord?> geocode(String address) async {
    if (!isConfigured) return null;

    final cacheId = _cacheId(address);

    // 1. In-memory cache (instant)
    final inMem = _memCache[cacheId];
    if (inMem != null) return inMem;

    // 2. Local cache via SharedPreferences / localStorage (no network)
    final spKey = 'geocache_$cacheId';
    final spVal = _prefs?.getString(spKey);
    if (spVal != null) {
      try {
        final j = jsonDecode(spVal) as Map<String, dynamic>;
        final coord = GeoCoord(
          (j['lat'] as num).toDouble(),
          (j['lng'] as num).toDouble(),
        );
        _memCache[cacheId] = coord;
        return coord;
      } catch (_) {}
    }

    // 3. Firestore cache
    try {
      final doc = await _geocache.doc(cacheId).get();
      if (doc.exists) {
        final d = doc.data()!;
        final coord = GeoCoord(
          (d['lat'] as num).toDouble(),
          (d['lng'] as num).toDouble(),
        );
        _memCache[cacheId] = coord;
        _prefs?.setString(spKey, jsonEncode({'lat': coord.lat, 'lng': coord.lng}));
        return coord;
      }
    } catch (_) {}

    // 4. HTTP geocoding API
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&key=$_apiKey',
      );
      final resp = await http.get(url);
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final results = data['results'] as List;
      if (results.isEmpty) return null;

      final loc = results[0]['geometry']['location'];
      final lat = (loc['lat'] as num).toDouble();
      final lng = (loc['lng'] as num).toDouble();

      final coord = GeoCoord(lat, lng);
      _memCache[cacheId] = coord;
      _prefs?.setString(spKey, jsonEncode({'lat': lat, 'lng': lng}));

      try {
        await _geocache.doc(cacheId).set({
          'address': address,
          'lat': lat,
          'lng': lng,
        });
      } catch (_) {}

      return coord;
    } catch (_) {
      return null;
    }
  }

  static String _cacheId(String address) {
    final normalized = address.toLowerCase().trim();
    return 'g${normalized.hashCode.abs().toRadixString(36)}';
  }
}
