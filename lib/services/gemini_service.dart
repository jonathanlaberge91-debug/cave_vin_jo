import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GeminiResult {
  final String name;
  final String producer;
  final String appellation;
  final String country;
  final String region;
  final String climat;
  final String domaine;
  final String village;
  final String domainAddress;
  final String grapes;
  final double? alcohol;
  final String type;
  final int? drinkFrom;
  final int? drinkPeak;
  final int? drinkTo;
  final String wineDescription;
  final String domaineDescription;

  GeminiResult({
    this.name = '',
    this.producer = '',
    this.appellation = '',
    this.country = '',
    this.region = '',
    this.climat = '',
    this.domaine = '',
    this.village = '',
    this.domainAddress = '',
    this.grapes = '',
    this.alcohol,
    this.type = 'rouge',
    this.drinkFrom,
    this.drinkPeak,
    this.drinkTo,
    this.wineDescription = '',
    this.domaineDescription = '',
  });

  factory GeminiResult.fromJson(Map<String, dynamic> json) {
    return GeminiResult(
      name: json['name'] ?? '',
      producer: json['producer'] ?? '',
      appellation: json['appellation'] ?? '',
      country: json['country'] ?? '',
      region: json['region'] ?? '',
      climat: json['climat'] ?? '',
      domaine: json['domaine'] ?? '',
      village: json['village'] ?? '',
      domainAddress: json['domainAddress'] ?? '',
      grapes: json['grapes'] ?? '',
      alcohol: (json['alcohol'] as num?)?.toDouble(),
      type: json['type'] ?? 'rouge',
      drinkFrom: json['drinkFrom'],
      drinkPeak: json['drinkPeak'],
      drinkTo: json['drinkTo'],
      wineDescription: json['wineDescription'] ?? '',
      domaineDescription: json['domaineDescription'] ?? '',
    );
  }
}

class GeminiService {
  static const _keyPref = 'gemini_api_key';
  static String? _apiKey;

  static String? get apiKey => _apiKey;

  static set apiKey(String? key) {
    _apiKey = key;
    _saveToPrefs(key);
  }

  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_keyPref);
  }

  static Future<void> _saveToPrefs(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_keyPref);
    } else {
      await prefs.setString(_keyPref, key);
    }
  }

  static const _jsonFormat = '''
{
  "name": "nom complet du vin",
  "producer": "producteur / château",
  "appellation": "appellation d'origine",
  "country": "pays",
  "region": "région viticole",
  "climat": "climat ou lieu-dit si applicable, sinon vide",
  "domaine": "domaine ou monopole si applicable, sinon vide",
  "village": "village si applicable, sinon vide",
  "domainAddress": "adresse complète du domaine",
  "grapes": "cépages avec pourcentages si connus",
  "alcohol": 13.5,
  "type": "rouge ou blanc ou rose ou orange ou petillant",
  "drinkFrom": 2024,
  "drinkPeak": 2030,
  "drinkTo": 2040,
  "wineDescription": "Description détaillée du vin en 15 phrases. Inclure : robe, nez (arômes primaires, secondaires, tertiaires), bouche (attaque, milieu, structure tannique, acidité, texture), finale (longueur, saveurs persistantes), potentiel de garde, accords mets-vins recommandés.",
  "domaineDescription": "Description détaillée du domaine en 15 phrases. Inclure : histoire, propriétaire actuel, philosophie de vinification, terroir (sol, exposition, altitude), superficie du vignoble, classement ou distinctions, réputation, particularités."
}''';

  static Future<GeminiResult> searchByText({
    required String name,
    String? domaine,
    String? vintage,
  }) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }

    final vintageStr = vintage != null && vintage.isNotEmpty ? ' millésime $vintage' : '';
    final domaineStr = domaine != null && domaine.isNotEmpty ? ' du domaine $domaine' : '';

    final prompt =
        'Tu es un expert en vin. Donne-moi les informations sur le vin "$name"$domaineStr$vintageStr.\n\nRéponds UNIQUEMENT avec un JSON valide, sans aucun texte avant ou après, dans ce format exact :\n$_jsonFormat';

    return _callGemini([
      {'text': prompt}
    ]);
  }

  static Future<GeminiResult> searchByPhoto(Uint8List imageBytes) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }

    final prompt =
        'Tu es un expert en vin. Analyse cette photo d\'étiquette de vin et identifie le vin.\n\nRéponds UNIQUEMENT avec un JSON valide, sans aucun texte avant ou après, dans ce format exact :\n$_jsonFormat';

    return _callGemini([
      {'text': prompt},
      {
        'inlineData': {
          'mimeType': 'image/jpeg',
          'data': base64Encode(imageBytes),
        }
      }
    ]);
  }

  static Future<GeminiResult> _callGemini(List<Map<String, dynamic>> parts) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {'parts': parts}
        ],
        'generationConfig': {
          'temperature': 0.3,
          'responseMimeType': 'application/json',
        }
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erreur Gemini (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body);
    final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
    if (text == null) {
      throw Exception('Réponse Gemini vide.');
    }

    final json = jsonDecode(text) as Map<String, dynamic>;
    return GeminiResult.fromJson(json);
  }
}
