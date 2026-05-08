import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
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

    final region = (json['region'] as String?) ?? '';
    final regionLower = region.toLowerCase();
    final isBurgundy = regionLower.contains('bourgogne') ||
        regionLower.contains('burgundy') ||
        regionLower.contains('beaujolais');
    final climat = isBurgundy ? (json['climat'] ?? '') : '';

    return GeminiResult(
      name: json['name'] ?? '',
      producer: json['producer'] ?? '',
      vintage: parseVintage(json['vintage']),
      appellation: json['appellation'] ?? '',
      country: json['country'] ?? '',
      region: region,
      climat: climat,
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'producer': producer,
        'vintage': vintage,
        'appellation': appellation,
        'country': country,
        'region': region,
        'climat': climat,
        'domaine': domaine,
        'village': village,
        'domainAddress': domainAddress,
        'grapes': grapes,
        'alcohol': alcohol,
        'type': type,
        'drinkFrom': drinkFrom,
        'drinkPeak': drinkPeak,
        'drinkTo': drinkTo,
        'marketValue': marketValue,
        'wineDescription': wineDescription,
        'domaineDescription': domaineDescription,
        'critiques': critiques.map((c) {
          final m = c.toMap();
          if (m['date'] is Timestamp) {
            m['date'] = (m['date'] as Timestamp).toDate().toIso8601String();
          }
          return m;
        }).toList(),
      };
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
  "name": "nom du vin SANS millésime, SANS année, SANS producteur (ex: Château Margaux, pas Château Margaux 2015)",
  "producer": "producteur / château",
  "vintage": 2015,
  "appellation": "appellation d'origine",
  "country": "pays",
  "region": "région viticole",
  "climat": "UNIQUEMENT pour les vins de Bourgogne : nom du climat / lieu-dit (ex: Les Amoureuses, Aux Murgers, Clos de la Roche). Pour TOUS les autres vins (Bordeaux, Rhône, Loire, Italie, Espagne, Nouveau Monde, etc.), TOUJOURS retourner une chaîne vide.",
  "domaine": "domaine, château, tenuta, bodega ou maison (ex: Domaine de la Romanée-Conti, Château Margaux, Tenuta San Guido)",
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
        'Tu es un expert sommelier francophone. Donne-moi les informations sur le vin "$name"$domaineStr$vintageStr.\n\n'
        'IMPORTANT : Utilise tes outils de recherche web pour vérifier toutes les informations (producteur, appellation, cépages, fenêtre de garde, valeur). '
        'Cite des sources fiables (sites de domaines, SAQ, Wine-Searcher, critiques). Si une info n\'est pas vérifiable, retourne null/chaîne vide plutôt que d\'inventer.\n\n'
        'Réponds UNIQUEMENT avec un JSON valide EN FRANÇAIS, sans aucun texte avant ou après, dans ce format exact :\n$_jsonFormat';

    final json = await _callGeminiJson([
      {'text': prompt}
    ], useGrounding: true);
    return GeminiResult.fromJson(json);
  }

  /// Cross-check unifié : combine validation (vérifier les champs où les 3 IA
  /// sont d'accord) et résolution (choisir parmi les options en conflit) en
  /// un seul appel Gemini grounded. Retourne fieldKey → valeur correcte.
  /// Si un champ est correct ou non vérifiable, il est absent de la réponse.
  static Future<Map<String, String>> crossCheck({
    required String wineIdentity,
    required Map<String, String> consensus,
    required Map<String, Map<String, String>> conflicts,
  }) async {
    if (!isConfigured) return const {};
    if (consensus.isEmpty && conflicts.isEmpty) return const {};

    final prompt = '''
Tu es un sommelier expert et fact-checker. Pour le vin "$wineIdentity", utilise tes outils de recherche web (sites de domaines, SAQ, Wine-Searcher, RVF, Decanter) pour vérifier ces informations.

CHAMPS CONSENSUS (les 3 IA ont la même valeur, à confirmer ou corriger) :
${jsonEncode(consensus)}

CHAMPS EN CONFLIT (plusieurs IA proposent des valeurs différentes, identifier la bonne) :
${jsonEncode(conflicts)}

Pour chaque champ :
- Si un consensus est CORRECT : ne le mentionne PAS dans la réponse.
- Si un consensus est FAUX : retourne la valeur correcte exacte.
- Si un conflit a une bonne option : retourne la valeur exacte de cette option (sans la modifier).
- Si un conflit n'a aucune bonne option : retourne la valeur correcte (qui sera proposée comme alternative).
- Si tu ne peux PAS vérifier un champ : ne le mentionne PAS.

Sois CONSERVATEUR : ne flagge un consensus que si tu trouves une preuve publiée claire qui contredit. Pour les fenêtres (drinkFrom/Peak/To) : tolère ±3 ans.

Réponds UNIQUEMENT avec ce JSON, EN FRANÇAIS pour les valeurs textuelles :
{
  "corrections": {
    "<fieldKey>": "<valeur correcte>"
  }
}
''';

    try {
      final json = await _callGeminiJson([
        {'text': prompt}
      ], useGrounding: true);
      final raw = json['corrections'];
      if (raw is! Map) return const {};
      final result = <String, String>{};
      raw.forEach((k, v) {
        if (k is String && v != null) {
          final str = v.toString().trim();
          if (str.isNotEmpty) result[k] = str;
        }
      });
      return result;
    } catch (_) {
      return const {};
    }
  }

  /// Résolution de conflits : pour chaque champ avec plusieurs valeurs en
  /// conflit, demande à Gemini (recherche web) de choisir la bonne option.
  /// Retourne map fieldKey → nom de la source choisie (ex: 'gemini', 'groq').
  static Future<Map<String, String>> resolveConflicts({
    required String wineIdentity,
    required Map<String, Map<String, String>> conflicts,
  }) async {
    if (!isConfigured || conflicts.isEmpty) return const {};

    final prompt = '''
Tu es un sommelier expert et un fact-checker. Pour le vin "$wineIdentity", plusieurs IA ont proposé des valeurs différentes pour certains champs.

Utilise TES OUTILS DE RECHERCHE WEB (sites de domaines, SAQ, Wine-Searcher, RVF, Decanter) pour identifier la valeur correcte pour chaque champ. Sois rigoureux.

Conflits à résoudre :
${jsonEncode(conflicts)}

Réponds UNIQUEMENT avec un JSON contenant, pour chaque champ, le nom de la source qui a la valeur correcte selon ta vérification web :

{
  "<fieldKey>": "<nom de la source qui a raison>"
}

Le nom de source doit être l'une des clés présentes dans les options du champ (ex: "gemini", "groq", "mistral", "consensus", "validator").
Si tu ne peux pas trancher avec certitude pour un champ, NE LE METS PAS dans la réponse.
''';

    try {
      final json = await _callGeminiJson([
        {'text': prompt}
      ], useGrounding: true);
      final result = <String, String>{};
      json.forEach((k, v) {
        if (v is String && v.isNotEmpty) result[k] = v;
      });
      return result;
    } catch (_) {
      return const {};
    }
  }

  /// Validation pass : reçoit un résultat consensus, demande à Gemini
  /// (en mode recherche web) de vérifier chaque champ. Retourne uniquement
  /// les champs où Gemini trouve une contradiction claire et vérifiable.
  static Future<Map<String, String>> validateWine(GeminiResult merged) async {
    if (!isConfigured) return const {};
    final identity = <String>[
      if (merged.producer.isNotEmpty) merged.producer,
      if (merged.name.isNotEmpty) merged.name,
      if (merged.vintage != null) merged.vintage.toString(),
    ].join(' ');
    if (identity.trim().isEmpty) return const {};

    final fieldsJson = jsonEncode({
      'name': merged.name,
      'producer': merged.producer,
      'vintage': merged.vintage,
      'appellation': merged.appellation,
      'country': merged.country,
      'region': merged.region,
      'climat': merged.climat,
      'domaine': merged.domaine,
      'village': merged.village,
      'domainAddress': merged.domainAddress,
      'grapes': merged.grapes,
      'alcohol': merged.alcohol,
      'type': merged.type,
      'drinkFrom': merged.drinkFrom,
      'drinkPeak': merged.drinkPeak,
      'drinkTo': merged.drinkTo,
      'marketValue': merged.marketValue,
    });

    final prompt = '''
Tu es un sommelier expert et un fact-checker. Voici des informations sur le vin "$identity" obtenues par recoupage de plusieurs sources IA :

$fieldsJson

UTILISE TES OUTILS DE RECHERCHE WEB pour vérifier chaque champ contre des sources fiables (site officiel du domaine, SAQ, Wine-Searcher, RVF, Decanter).

Sois CONSERVATEUR :
- Ne flagge un champ que si tu trouves une PREUVE PUBLIÉE qui contredit clairement la valeur fournie.
- Si tu n'es pas certain, ne retourne PAS le champ.
- Pour les champs textuels (producer, region, appellation...) : tolère les variations d'écriture (accents, ponctuation, ordre).
- Pour drinkFrom/drinkPeak/drinkTo/marketValue : flagge seulement si la valeur fournie est nettement (>3 ans, >30%) hors de la plage publiée.

Réponds UNIQUEMENT avec un JSON contenant SEULEMENT les champs qui ont des erreurs vérifiées, sous cette forme :
{
  "corrections": {
    "<fieldKey>": {"correct": "<valeur correcte>", "reason": "<source ou raison brève>"}
  }
}

Si tout est correct ou non vérifiable : retourne {"corrections": {}}.

Toutes les valeurs textuelles EN FRANÇAIS.
''';

    try {
      final json = await _callGeminiJson([
        {'text': prompt}
      ], useGrounding: true);
      final corrections = json['corrections'];
      if (corrections is! Map) return const {};
      final result = <String, String>{};
      corrections.forEach((k, v) {
        if (k is String && v is Map) {
          final correct = v['correct'];
          if (correct != null) {
            result[k] = correct.toString();
          }
        }
      });
      return result;
    } catch (_) {
      return const {};
    }
  }

  /// Recherche par photo en 2 étapes :
  /// 1. Identification du vin depuis l'image (sans grounding, JSON strict, ~10s)
  /// 2. Recherche complète par texte avec grounding web (comme searchByText, ~20s)
  /// Bien plus fiable qu'un seul appel grounding+image qui dépasse souvent les délais.
  static Future<GeminiResult> searchByPhoto(
    Uint8List imageBytes, {
    String? ocrHint,
    String? vintageHint,
  }) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }

    // Étape 1 : identification rapide depuis la photo
    final identity = await _identifyFromPhoto(imageBytes, ocrHint: ocrHint);

    final name = (identity['name'] as String? ?? '').trim();
    final producer = (identity['producer'] as String? ?? '').trim();
    final identifiedVintage = identity['vintage']?.toString();
    final effectiveVintage = (vintageHint != null && vintageHint.trim().isNotEmpty)
        ? vintageHint.trim()
        : identifiedVintage;

    if (name.isEmpty && producer.isEmpty) {
      throw Exception('Impossible d\'identifier le vin sur cette étiquette.');
    }

    // Étape 2 : recherche complète avec grounding (texte seulement, fiable)
    return searchByText(
      name: name.isNotEmpty ? name : producer,
      domaine: producer.isNotEmpty ? producer : null,
      vintage: effectiveVintage,
    );
  }

  /// Identification minimale depuis une photo : retourne name/producer/vintage.
  /// Sans grounding → JSON strict possible → rapide et fiable.
  static Future<Map<String, dynamic>> _identifyFromPhoto(
    Uint8List imageBytes, {
    String? ocrHint,
  }) async {
    final ocrSection = (ocrHint != null && ocrHint.trim().isNotEmpty)
        ? '\n\nTexte OCR de l\'étiquette (orthographe exacte des noms et millésime) :\n${ocrHint.trim()}'
        : '';

    final prompt =
        'Identifie le vin sur cette étiquette. '
        'Réponds UNIQUEMENT avec ce JSON, sans texte avant ou après :\n'
        '{"name": "nom du vin sans millésime", "producer": "producteur/domaine/château", "vintage": 2018}\n'
        'vintage = null si non visible.$ocrSection';

    final apiBytes = _resizeForApi(imageBytes);
    return _callGeminiJson([
      {'text': prompt},
      {
        'inlineData': {
          'mimeType': 'image/jpeg',
          'data': base64Encode(apiBytes),
        }
      }
    ]).timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw Exception('Identification photo trop lente. Réessaie.'),
    );
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

  static Future<double?> estimateMarketValue({
    required String name,
    String? producer,
    String? vintage,
    String? appellation,
  }) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }
    final parts = [
      'Nom: $name',
      if (producer != null && producer.isNotEmpty) 'Producteur: $producer',
      if (vintage != null && vintage.isNotEmpty) 'Millésime: $vintage',
      if (appellation != null && appellation.isNotEmpty) 'Appellation: $appellation',
    ].join(', ');

    final prompt =
        'Tu es un expert en évaluation de vins. Estime la valeur marchande actuelle en dollars canadiens (CAD) pour une bouteille 750 ML de ce vin :\n\n$parts\n\nBase-toi sur les prix moyens observés en SAQ, enchères, ou marchés en ligne.\n\nRéponds UNIQUEMENT avec un JSON valide, sans aucun texte avant ou après :\n{"marketValue": 85.00}\n\nSi aucune estimation fiable n\'est possible, retourne {"marketValue": null}.';

    final json = await _callGeminiJson([{'text': prompt}]);
    final v = json['marketValue'];
    if (v == null) return null;
    return (v as num).toDouble();
  }

  static Future<({int? drinkFrom, int? drinkPeak, int? drinkTo})> estimateGarde({
    required String name,
    String? producer,
    String? vintage,
    String? appellation,
  }) async {
    if (!isConfigured) {
      throw Exception('Clé API Gemini non configurée. Va dans Paramètres.');
    }
    final parts = [
      'Nom: $name',
      if (producer != null && producer.isNotEmpty) 'Producteur: $producer',
      if (vintage != null && vintage.isNotEmpty) 'Millésime: $vintage',
      if (appellation != null && appellation.isNotEmpty) 'Appellation: $appellation',
    ].join(', ');

    final prompt =
        'Tu es un expert sommelier. Estime la période de garde optimale pour ce vin :\n\n$parts\n\nRéponds UNIQUEMENT avec un JSON valide, sans aucun texte avant ou après :\n{"drinkFrom": 2024, "drinkPeak": 2030, "drinkTo": 2040}\n\nLes valeurs sont des années (4 chiffres). Si tu ne peux pas estimer un champ, mets null.';

    final json = await _callGeminiJson([{'text': prompt}]);
    return (
      drinkFrom: json['drinkFrom'] as int?,
      drinkPeak: json['drinkPeak'] as int?,
      drinkTo: json['drinkTo'] as int?,
    );
  }

  static const _models = [
    'gemini-2.5-flash',
    'gemini-2.5-pro',
    'gemini-2.0-flash',
    'gemini-flash-latest',
  ];

  static Uint8List _resizeForApi(Uint8List bytes, {int maxDim = 1280}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    if (decoded.width <= maxDim && decoded.height <= maxDim) return bytes;
    final resized = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: maxDim)
        : img.copyResize(decoded, height: maxDim);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  static Future<Map<String, dynamic>> _callGeminiJson(
    List<Map<String, dynamic>> parts, {
    bool useGrounding = false,
  }) async {
    // Search Grounding fait chercher Gemini sur le web pendant qu'il répond,
    // ce qui réduit drastiquement les hallucinations. Mais il n'est pas
    // compatible avec responseMimeType=json — on parse manuellement à la place.
    final payload = <String, dynamic>{
      'contents': [
        {'parts': parts}
      ],
      'generationConfig': {
        'temperature': 0.3,
        if (!useGrounding) 'responseMimeType': 'application/json',
      },
      if (useGrounding)
        'tools': [
          {'google_search': <String, dynamic>{}}
        ],
    };
    final body = jsonEncode(payload);

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
          ).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Délai 30s dépassé', const Duration(seconds: 30)),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidate = data['candidates']?[0];
            final partsList = candidate?['content']?['parts'] as List?;
            if (partsList == null || partsList.isEmpty) {
              throw Exception('Réponse Gemini vide.');
            }
            // Concatène les parts text (grounding peut en produire plusieurs).
            final text = partsList
                .map((p) => p['text'] as String? ?? '')
                .where((t) => t.isNotEmpty)
                .join('\n');
            if (text.isEmpty) {
              throw Exception('Réponse Gemini vide.');
            }
            return _extractJson(text);
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
        } on TimeoutException catch (e) {
          lastError = e;
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 800 * (1 << attempt)));
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

  static Map<String, dynamic> _extractJson(String text) {
    var inner = text.trim();
    // Retire les fences markdown ```json ... ```
    if (inner.startsWith('```')) {
      inner = inner.replaceFirst(RegExp(r'^```(json)?\s*'), '');
      final lastFence = inner.lastIndexOf('```');
      if (lastFence != -1) inner = inner.substring(0, lastFence);
      inner = inner.trim();
    }
    // Cherche le 1er { et le dernier } pour extraire l'objet JSON
    final start = inner.indexOf('{');
    final end = inner.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw Exception('Pas de JSON valide dans la réponse Gemini.');
    }
    final jsonStr = inner.substring(start, end + 1);
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('JSON Gemini inattendu (pas un objet).');
    }
    return decoded;
  }
}
