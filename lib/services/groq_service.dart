import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'gemini_service.dart' show GeminiResult;

/// Client Groq (API OpenAI-compatible). On utilise Groq comme 2e IA pour
/// faire un recoupage avec Gemini sur les fiches de vin.
class GroqService {
  static const _keyPref = 'groq_api_key';
  static const _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  // Modèles : Llama 4 Scout pour photo (vision), Llama 3.3 70B pour texte.
  static const _visionModel = 'meta-llama/llama-4-scout-17b-16e-instruct';
  static const _textModel = 'llama-3.3-70b-versatile';

  static final _settingsDoc =
      FirebaseFirestore.instance.collection('settings').doc('app');
  static String? _apiKey;

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
      final remote = snap.data()?['groqApiKey'] as String?;
      if (remote != null && remote.isNotEmpty) {
        _apiKey = remote;
        await prefs.setString(_keyPref, remote);
      } else if (_apiKey != null && _apiKey!.isNotEmpty) {
        await _settingsDoc
            .set({'groqApiKey': _apiKey}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  static Future<void> _persist(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_keyPref);
      try {
        await _settingsDoc.set(
            {'groqApiKey': FieldValue.delete()}, SetOptions(merge: true));
      } catch (_) {}
    } else {
      await prefs.setString(_keyPref, key);
      try {
        await _settingsDoc
            .set({'groqApiKey': key}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  static const _jsonFormat = '''
{
  "name": "nom du vin SANS millésime, SANS année, SANS producteur",
  "producer": "producteur / château",
  "vintage": 2015,
  "appellation": "appellation",
  "country": "pays en français",
  "region": "région viticole en français",
  "climat": "UNIQUEMENT pour vins de Bourgogne (climat / lieu-dit). Sinon chaîne vide.",
  "domaine": "domaine, château, tenuta, bodega ou maison",
  "village": "village si applicable, sinon vide",
  "domainAddress": "adresse complète du domaine",
  "grapes": "cépages avec pourcentages si connus, en français",
  "alcohol": 13.5,
  "type": "rouge ou blanc ou rose ou orange ou petillant",
  "drinkFrom": 2024,
  "drinkPeak": 2030,
  "drinkTo": 2040,
  "marketValue": 85.00
}

Toutes les valeurs textuelles EN FRANÇAIS. marketValue = valeur marchande en CAD pour 750 ml. Si une info n'est pas connue : null pour les nombres, "" pour les textes.''';

  static Future<GeminiResult> searchByText({
    required String name,
    String? domaine,
    String? vintage,
  }) async {
    if (!isConfigured) {
      throw Exception('Clé API Groq non configurée. Va dans Paramètres.');
    }
    final vintageStr =
        vintage != null && vintage.isNotEmpty ? ' millésime $vintage' : '';
    final domaineStr = domaine != null && domaine.isNotEmpty
        ? ' du domaine $domaine'
        : '';

    final prompt =
        'Tu es un expert sommelier francophone. Donne les informations sur le vin "$name"$domaineStr$vintageStr. '
        'Réponds UNIQUEMENT avec un JSON valide EN FRANÇAIS, sans aucun texte avant ou après, dans ce format exact :\n$_jsonFormat';

    final json = await _callJson(
      model: _textModel,
      messages: [
        {'role': 'user', 'content': prompt}
      ],
      asJsonObject: true,
    );
    return _enrichWithEmptyDescriptions(GeminiResult.fromJson(json));
  }

  static Future<GeminiResult> searchByPhoto(
    Uint8List imageBytes, {
    String? ocrHint,
  }) async {
    if (!isConfigured) {
      throw Exception('Clé API Groq non configurée. Va dans Paramètres.');
    }
    final ocrSection = (ocrHint != null && ocrHint.trim().isNotEmpty)
        ? '\n\nTexte OCR extrait de l\'étiquette (utilise-le pour confirmer l\'orthographe exacte des noms et chiffres) :\n---\n${ocrHint.trim()}\n---'
        : '';
    final prompt =
        'Tu es un expert sommelier francophone. Analyse cette photo d\'étiquette de vin et identifie le vin.$ocrSection '
        'Réponds UNIQUEMENT avec un JSON valide EN FRANÇAIS (toutes les valeurs textuelles en français même si l\'étiquette est dans une autre langue), '
        'sans aucun texte avant ou après, dans ce format exact :\n$_jsonFormat';

    final dataUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
    final json = await _callJson(
      model: _visionModel,
      messages: [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': dataUrl}
            }
          ]
        }
      ],
      // Vision sur Llama 4 Scout : pas tjrs de json mode → on parse manuellement.
      asJsonObject: false,
    );
    return _enrichWithEmptyDescriptions(GeminiResult.fromJson(json));
  }

  /// Groq ne fournit ni descriptions longues ni critiques → on garde Gemini
  /// pour ces champs. Ici on retourne juste le résultat tel quel ; le merge
  /// s'occupe d'ignorer ces champs côté Groq.
  static GeminiResult _enrichWithEmptyDescriptions(GeminiResult r) => r;

  static Future<Map<String, dynamic>> _callJson({
    required String model,
    required List<Map<String, dynamic>> messages,
    bool asJsonObject = true,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'temperature': 0.2,
    };
    if (asJsonObject) {
      body['response_format'] = {'type': 'json_object'};
    }

    final res = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      throw Exception('Groq erreur ${res.statusCode} : ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq : réponse vide');
    }
    final content = choices.first['message']?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('Groq : contenu vide');
    }

    return _parseJson(content);
  }

  static Map<String, dynamic> _parseJson(String content) {
    final cleaned = content.trim();
    String inner = cleaned;
    // Strip markdown fences si présent.
    if (inner.startsWith('```')) {
      inner = inner.replaceFirst(RegExp(r'^```(json)?\s*', multiLine: false), '');
      final lastFence = inner.lastIndexOf('```');
      if (lastFence != -1) inner = inner.substring(0, lastFence);
      inner = inner.trim();
    }
    // Cherche le premier { et dernier }
    final start = inner.indexOf('{');
    final end = inner.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw Exception('Groq : pas de JSON valide dans la réponse');
    }
    final jsonStr = inner.substring(start, end + 1);
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Groq : JSON inattendu');
    }
    return decoded;
  }
}
