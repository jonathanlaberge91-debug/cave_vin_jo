import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wine.dart';

class GeminiResult {
  final String name;
  final String producer;
  final int? vintage;
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
  final double? marketValue;
  final List<Critique> critiques;

  GeminiResult({
    this.name = '',
    this.producer = '',
    this.vintage,
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
    this.marketValue,
    this.wineDescription = '',
    this.domaineDescription = '',
    this.critiques = const [],
  });

  factory GeminiResult.fromJson(Map<String, dynamic> json) {
    final raw = (json['critiques'] as List?) ?? const [];
    final critiques = raw
        .whereType<Map>()
        .map((c) {
          final m = Map<String, dynamic>.from(c);
          DateTime? date;
          final dateStr = m['date'];
          if (dateStr is String && dateStr.isNotEmpty) {
            date = DateTime.tryParse(dateStr);
          }
          return Critique(
            source: (m['source'] ?? '').toString(),
            score: (m['score'] ?? '').toString(),
            note: (m['note'] ?? '').toString(),
            date: date,
          );
        })
        .where((c) => c.source.isNotEmpty || c.score.isNotEmpty || c.note.isNotEmpty)
        .toList();

    int? parseVintage(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final cleaned = v.trim();
        if (cleaned.isEmpty) return null;
        return int.tryParse(cleaned);
      }
      return null;
    }

    return GeminiResult(
      name: json['name'] ?? '',
      producer: json['producer'] ?? '',
      vintage: parseVintage(json['vintage']),
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
      drinkFrom: parseVintage(json['drinkFrom']),
      drinkPeak: parseVintage(json['drinkPeak']),
      drinkTo: parseVintage(json['drinkTo']),
      marketValue: (json['marketValue'] as num?)?.toDouble(),
      wineDescription: json['wineDescription'] ?? '',
      domaineDescription: json['domaineDescription'] ?? '',
      critiques: critiques,
    );
  }
}

class PairingSuggestion {
  final String wineId;
  final int score;
  final String explanation;
  final List<String> highlights;

  PairingSuggestion({
    required this.wineId,
    required this.score,
    required this.explanation,
    required this.highlights,
  });

  factory PairingSuggestion.fromJson(Map<String, dynamic> json) {
    return PairingSuggestion(
      wineId: (json['wineId'] ?? '').toString(),
      score: (json['score'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] ?? '',
      highlights: (json['highlights'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class PairingResult {
  final String mealAnalysis;
  final List<PairingSuggestion> suggestions;

  PairingResult({
    required this.mealAnalysis,
    required this.suggestions,
  });

  factory PairingResult.fromJson(Map<String, dynamic> json) {
    return PairingResult(
      mealAnalysis: json['mealAnalysis'] ?? '',
      suggestions: (json['suggestions'] as List?)
              ?.map((s) =>
                  PairingSuggestion.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SommelierResult {
  final String temperature;
  final String decantage;
  final String verre;
  final String ouverture;
  final String conseil;

  SommelierResult({
    required this.temperature,
    required this.decantage,
    required this.verre,
    required this.ouverture,
    required this.conseil,
  });

  factory SommelierResult.fromJson(Map<String, dynamic> json) {
    return SommelierResult(
      temperature: json['temperature'] ?? '',
      decantage: json['decantage'] ?? '',
      verre: json['verre'] ?? '',
      ouverture: json['ouverture'] ?? '',
      conseil: json['conseil'] ?? '',
    );
  }
}

class GeminiService {
  static const _keyPref = 'gemini_api_key';
  static final _settingsDoc =
      FirebaseFirestore.instance.collection('settings').doc('app');
  static String? _apiKey;

  static String? get apiKey => _apiKey;

  static set apiKey(String? key) {
    _apiKey = key;
    _persist(key);
  }

  static bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_keyPref);

    try {
      final snap = await _settingsDoc.get();
      final remote = snap.data()?['geminiApiKey'] as String?;
      if (remote != null && remote.isNotEmpty) {
        _apiKey = remote;
        await prefs.setString(_keyPref, remote);
      } else if (_apiKey != null && _apiKey!.isNotEmpty) {
        await _settingsDoc.set({'geminiApiKey': _apiKey}, SetOptions(merge: true));
      }
    } catch (_) {
      // offline ou Firestore indisponible : on garde la valeur locale
    }
  }

  static Future<void> _persist(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_keyPref);
      try {
        await _settingsDoc.set({'geminiApiKey': FieldValue.delete()},
            SetOptions(merge: true));
      } catch (_) {}
    } else {
      await prefs.setString(_keyPref, key);
      try {
        await _settingsDoc.set({'geminiApiKey': key}, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  static const _jsonFormat = '''
{
  "name": "nom complet du vin",
  "producer": "producteur / château",
  "vintage": 2015,
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
  "marketValue": 85.00,
  "wineDescription": "Description du vin en 12 phrases max. Inclure : robe, nez, bouche (structure, acidité, texture), finale, accords mets-vins.",
  "domaineDescription": "Description du domaine en 12 phrases max. Inclure : histoire, philosophie de vinification, terroir, réputation.",
  "critiques": [
    {
      "source": "Nom du critique ou de la publication (ex: Robert Parker / Wine Advocate, James Suckling, Jancis Robinson, Decanter, Vinous, Wine Spectator, La Revue du Vin de France)",
      "score": "Note exacte attribuée avec son barème (ex: 98/100, 19/20, 5/5)",
      "note": "Citation textuelle ou résumé de la note de dégustation du critique en 2 à 4 phrases",
      "date": "AAAA-MM-JJ ou AAAA-MM-01 si seul le mois est connu, ou null"
    }
  ]
}

Pour le champ "vintage" : extrais l'année du millésime (4 chiffres, ex: 2015) visible sur l'étiquette ou déductible du contexte. Si aucune année n'est visible ou identifiable, retourne null.

Pour le champ "marketValue" : estime la valeur marchande actuelle en dollars canadiens (CAD) pour une bouteille 750 ML de ce vin et ce millésime. Base-toi sur les prix moyens observés en SAQ, enchères, ou marchés en ligne. Si aucune estimation fiable n'est possible, retourne null.

Pour le champ "critiques" : retourne 3 à 6 critiques RÉELLES de critiques reconnus pour ce vin et ce millésime spécifique. Si aucune critique vérifiable n'existe, retourne un tableau vide []. N'invente JAMAIS de notes ou de citations.

LANGUE OBLIGATOIRE — TRÈS IMPORTANT : Toutes les valeurs textuelles du JSON doivent être rédigées EXCLUSIVEMENT EN FRANÇAIS, peu importe la langue de l'étiquette ou la nationalité du vin. Cela inclut wineDescription, domaineDescription, country (ex: "Italie" et non "Italy"), region, appellation, grapes (ex: "Sangiovese, Cabernet Sauvignon" — noms de cépages en français), type, et les citations de critiques (note) qui doivent être traduites en français si la source originale est en anglais ou autre langue. JAMAIS UN SEUL MOT EN ANGLAIS dans la réponse.''';

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
        'Tu es un expert sommelier francophone. Donne-moi les informations sur le vin "$name"$domaineStr$vintageStr.\n\nRéponds UNIQUEMENT avec un JSON valide EN FRANÇAIS, sans aucun texte avant ou après, dans ce format exact :\n$_jsonFormat';

    final json = await _callGeminiJson([
      {'text': prompt}
    ]);
    return GeminiResult.fromJson(json);
  }

  static Future<GeminiResult> searchByPhoto(Uint8List imageBytes) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }

    final prompt =
        'Tu es un expert sommelier francophone. Analyse cette photo d\'étiquette de vin et identifie le vin.\n\nRéponds UNIQUEMENT avec un JSON valide EN FRANÇAIS (toutes les valeurs textuelles doivent être traduites en français même si l\'étiquette est dans une autre langue), sans aucun texte avant ou après, dans ce format exact :\n$_jsonFormat';

    final json = await _callGeminiJson([
      {'text': prompt},
      {
        'inlineData': {
          'mimeType': 'image/jpeg',
          'data': base64Encode(imageBytes),
        }
      }
    ]);
    return GeminiResult.fromJson(json);
  }


  static Future<PairingResult> suggestPairings({
    required String meal,
    required List<Wine> wines,
  }) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }
    if (wines.isEmpty) {
      throw Exception('Aucun vin dans la cave.');
    }

    final wineList = wines.map((w) {
      final parts = <String>[
        w.name,
        if (w.vintage != null) '${w.vintage}',
        w.type.name,
        if (w.grapes.isNotEmpty) w.grapes,
        if (w.appellation.isNotEmpty) w.appellation,
        if (w.region.isNotEmpty) w.region,
        if (w.country.isNotEmpty) w.country,
      ];
      return '- [${w.id}] ${parts.join(' · ')}';
    }).join('\n');

    final maxSuggestions = wines.length > 5 ? 5 : wines.length;

    final prompt =
        'Tu es un sommelier expert francophone de renommée mondiale. L\'utilisateur te décrit son repas et tu dois recommander les meilleurs accords parmi les vins disponibles dans sa cave personnelle.\n\nREPAS :\n$meal\n\nVINS DISPONIBLES DANS LA CAVE :\n$wineList\n\nAnalyse le repas en profondeur et recommande les $maxSuggestions meilleurs accords mets-vins. Classe-les du meilleur au moins bon.\n\nRéponds UNIQUEMENT avec un JSON valide EN FRANÇAIS, sans aucun texte avant ou après :\n$_pairingJsonFormat';

    final json = await _callGeminiJson([
      {'text': prompt}
    ]);
    return PairingResult.fromJson(json);
  }

  static const _pairingJsonFormat = '''
{
  "mealAnalysis": "Analyse détaillée du repas en 3-5 phrases : profil gustatif (saveurs dominantes, textures, intensité), méthode de cuisson et ses effets, sauces et accompagnements notables.",
  "suggestions": [
    {
      "wineId": "identifiant exact du vin tel que fourni entre crochets [] dans la liste",
      "score": 95,
      "explanation": "Explication détaillée de l'accord en 3-5 phrases. Décrire les ponts aromatiques entre le plat et le vin, comment les textures se complètent, pourquoi la structure du vin convient à ce plat.",
      "highlights": ["Pont aromatique 1", "Pont aromatique 2", "Pont aromatique 3"]
    }
  ]
}

RÈGLES :
- "wineId" : copier EXACTEMENT l'identifiant entre crochets [] de la liste de vins.
- "score" : harmonie de l'accord de 0 à 100 (90-100 = parfait, 75-89 = excellent, 60-74 = bon). Sois exigeant et réaliste.
- "highlights" : 2 à 4 mots-clés décrivant les ponts de saveurs entre le plat et le vin.
- LANGUE : Toutes les valeurs textuelles en FRANÇAIS.''';

  static Future<SommelierResult> sommelierAdvice(Wine wine) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }

    final parts = <String>[
      wine.name,
      if (wine.producer.isNotEmpty) 'Producteur: ${wine.producer}',
      if (wine.vintage != null) 'Millésime: ${wine.vintage}',
      if (wine.appellation.isNotEmpty) 'Appellation: ${wine.appellation}',
      if (wine.region.isNotEmpty) 'Région: ${wine.region}',
      if (wine.country.isNotEmpty) 'Pays: ${wine.country}',
      if (wine.grapes.isNotEmpty) 'Cépages: ${wine.grapes}',
      if (wine.alcohol != null) 'Alcool: ${wine.alcohol}%',
      'Type: ${wine.type.name}',
    ];

    final prompt =
        'Tu es un sommelier expert de renommée mondiale. Donne-moi tes conseils de service pour ce vin :\n\n${parts.join('\n')}\n\nRéponds UNIQUEMENT avec un JSON valide EN FRANÇAIS, sans aucun texte avant ou après :\n$_sommelierJsonFormat';

    final json = await _callGeminiJson([
      {'text': prompt}
    ]);
    return SommelierResult.fromJson(json);
  }

  static const _sommelierJsonFormat = '''
{
  "temperature": "Température de service recommandée (ex: 16-18°C)",
  "decantage": "Conseil de décantage (ex: Carafer 1h avant le service, ou Pas nécessaire)",
  "verre": "Type de verre recommandé (ex: Verre à Bourgogne, Verre à Bordeaux, Flûte)",
  "ouverture": "Conseil d'ouverture (ex: Ouvrir 30 min avant, Prêt à boire immédiatement)",
  "conseil": "Conseil sommelier détaillé en 3-5 phrases. Inclure des recommandations d'accords mets-vins, le moment idéal pour déguster, et toute particularité à noter pour ce vin."
}

LANGUE OBLIGATOIRE : Toutes les valeurs en FRANÇAIS.''';

  static const _models = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
    'gemini-flash-latest',
  ];

  static Future<Map<String, dynamic>> _callGeminiJson(List<Map<String, dynamic>> parts) async {
    final body = jsonEncode({
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {
        'temperature': 0.3,
        'responseMimeType': 'application/json',
      }
    });

    Object? lastError;
    int? lastStatus;
    String? lastBody;

    for (final model in _models) {
      for (var attempt = 0; attempt < 3; attempt++) {
        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey',
          );
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (text == null) {
              throw Exception('Réponse Gemini vide.');
            }
            return jsonDecode(text) as Map<String, dynamic>;
          }

          lastStatus = response.statusCode;
          lastBody = response.body;

          final retryable = response.statusCode == 503 ||
              response.statusCode == 429 ||
              response.statusCode == 500 ||
              response.statusCode == 502 ||
              response.statusCode == 504;

          if (!retryable) {
            throw Exception('Erreur Gemini (${response.statusCode}): ${response.body}');
          }

          if (attempt < 2) {
            final delayMs = 800 * (1 << attempt);
            await Future.delayed(Duration(milliseconds: delayMs));
          }
        } catch (e) {
          lastError = e;
          if (e.toString().contains('Erreur Gemini (4')) rethrow;
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 800 * (1 << attempt)));
          }
        }
      }
    }

    throw Exception(
      'Gemini est surchargé sur tous les modèles (dernière erreur HTTP $lastStatus). '
      'Réessaie dans quelques minutes. Détail : ${lastBody ?? lastError ?? "inconnu"}',
    );
  }
}
