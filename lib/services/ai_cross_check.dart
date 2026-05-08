import 'dart:typed_data';
import 'gemini_service.dart';
import 'groq_service.dart';
import 'mistral_service.dart';
import 'ocr_service.dart';

enum AiSource {
  gemini('Gemini'),
  groq('Groq'),
  mistral('Mistral'),
  consensus('Consensus IA'),
  validator('Validation web');

  final String label;
  const AiSource(this.label);
}

/// Champ où plusieurs IA proposent des valeurs différentes non vides
/// (et aucune majorité claire).
class FieldDisagreement {
  final String fieldKey;
  final String label;
  final Map<AiSource, String> values;
  AiSource chosen;

  FieldDisagreement({
    required this.fieldKey,
    required this.label,
    required this.values,
    AiSource? chosen,
  }) : chosen = chosen ??
            (values.isEmpty ? AiSource.gemini : values.keys.first);

  Map<String, dynamic> toJson() => {
        'fieldKey': fieldKey,
        'label': label,
        'values': {for (final e in values.entries) e.key.name: e.value},
        'chosen': chosen.name,
      };

  factory FieldDisagreement.fromJson(Map<String, dynamic> j) {
    final raw = (j['values'] as Map?) ?? const {};
    final values = <AiSource, String>{};
    raw.forEach((k, v) {
      if (k is! String) return;
      AiSource? src;
      for (final s in AiSource.values) {
        if (s.name == k) {
          src = s;
          break;
        }
      }
      if (src != null && v != null) values[src] = v.toString();
    });
    AiSource? chosen;
    final chosenName = j['chosen'] as String?;
    if (chosenName != null) {
      for (final s in AiSource.values) {
        if (s.name == chosenName) {
          chosen = s;
          break;
        }
      }
    }
    return FieldDisagreement(
      fieldKey: j['fieldKey'] ?? '',
      label: j['label'] ?? '',
      values: values,
      chosen: chosen,
    );
  }
}

class CrossCheckResult {
  final GeminiResult merged;
  final List<FieldDisagreement> disagreements;
  final Map<AiSource, GeminiResult> sources;
  final Map<AiSource, String> errors;

  CrossCheckResult({
    required this.merged,
    required this.disagreements,
    required this.sources,
    required this.errors,
  });

  Map<String, dynamic> toJson() => {
        'merged': merged.toJson(),
        'disagreements': disagreements.map((d) => d.toJson()).toList(),
        'sources': {
          for (final e in sources.entries) e.key.name: e.value.toJson(),
        },
        'errors': {
          for (final e in errors.entries) e.key.name: e.value,
        },
      };

  factory CrossCheckResult.fromJson(Map<String, dynamic> j) {
    final mergedMap =
        (j['merged'] as Map?)?.cast<String, dynamic>() ?? {};
    final dList = (j['disagreements'] as List?) ?? const [];
    final sourcesRaw = (j['sources'] as Map?) ?? const {};
    final errorsRaw = (j['errors'] as Map?) ?? const {};
    AiSource? findSrc(String name) {
      for (final s in AiSource.values) {
        if (s.name == name) return s;
      }
      return null;
    }

    final sources = <AiSource, GeminiResult>{};
    sourcesRaw.forEach((k, v) {
      if (k is! String) return;
      final src = findSrc(k);
      if (src == null || v is! Map) return;
      sources[src] = GeminiResult.fromJson(v.cast<String, dynamic>());
    });
    final errors = <AiSource, String>{};
    errorsRaw.forEach((k, v) {
      if (k is! String) return;
      final src = findSrc(k);
      if (src == null) return;
      errors[src] = v?.toString() ?? '';
    });
    return CrossCheckResult(
      merged: GeminiResult.fromJson(mergedMap),
      disagreements: dList
          .whereType<Map>()
          .map((m) =>
              FieldDisagreement.fromJson(m.cast<String, dynamic>()))
          .toList(),
      sources: sources,
      errors: errors,
    );
  }
}

class AiCrossCheck {
  /// Recherche par texte : Gemini + Groq + Mistral (selon disponibilité).
  static Future<CrossCheckResult> searchByText({
    required String name,
    String? domaine,
    String? vintage,
  }) async {
    final futures = <AiSource, Future<GeminiResult>>{
      AiSource.gemini: GeminiService.searchByText(
          name: name, domaine: domaine, vintage: vintage),
      if (GroqService.isConfigured)
        AiSource.groq: GroqService.searchByText(
            name: name, domaine: domaine, vintage: vintage),
      if (MistralService.isConfigured)
        AiSource.mistral: MistralService.searchByText(
            name: name, domaine: domaine, vintage: vintage),
    };
    return _runAndMerge(futures);
  }

  /// Recherche par photo : Gemini + Groq + Mistral (Pixtral) selon dispo.
  /// Pré-traite avec OCR Tesseract.js (web) pour fournir un hint texte aux IA.
  /// [ocrFuture] : Future OCR déjà lancé (idéalement dès le crop de la photo
  /// pour qu'il tourne en parallèle des actions utilisateur). Si null, OCR
  /// est démarré ici en bloquant.
  static Future<CrossCheckResult> searchByPhoto(
    Uint8List bytes, {
    Future<String?>? ocrFuture,
    String? vintageHint,
  }) async {
    // Bound le temps d'attente OCR pour ne pas bloquer trop longtemps.
    // Si déjà fini (ocrFuture lancé tôt), on récupère instantanément.
    String? ocrHint;
    try {
      final f = ocrFuture ?? OcrService.recognize(bytes);
      ocrHint = await f.timeout(const Duration(seconds: 6));
    } catch (_) {
      ocrHint = null;
    }

    final futures = <AiSource, Future<GeminiResult>>{
      AiSource.gemini: GeminiService.searchByPhoto(bytes,
          ocrHint: ocrHint, vintageHint: vintageHint),
      if (GroqService.isConfigured)
        AiSource.groq: GroqService.searchByPhoto(bytes,
            ocrHint: ocrHint, vintageHint: vintageHint),
      if (MistralService.isConfigured)
        AiSource.mistral: MistralService.searchByPhoto(bytes,
            ocrHint: ocrHint, vintageHint: vintageHint),
    };
    return _runAndMerge(futures);
  }

  static Future<CrossCheckResult> _runAndMerge(
    Map<AiSource, Future<GeminiResult>> futures,
  ) async {
    final entries = futures.entries.toList();
    final results = await Future.wait(
      entries.map((e) => e.value
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () => throw Exception('Délai dépassé (90s).'),
          )
          .then<Object>((v) => v)
          .catchError((err) => err as Object)),
    );

    final sources = <AiSource, GeminiResult>{};
    final errors = <AiSource, String>{};
    for (var i = 0; i < entries.length; i++) {
      final src = entries[i].key;
      final r = results[i];
      if (r is GeminiResult) {
        sources[src] = r;
      } else {
        errors[src] = r.toString().replaceFirst('Exception: ', '');
      }
    }

    if (sources.isEmpty) {
      throw Exception(
          errors[AiSource.gemini] ?? errors.values.firstOrNull ?? 'Toutes les IA ont échoué');
    }
    if (!sources.containsKey(AiSource.gemini)) {
      // Si Gemini fail, on a quand même un résultat : on prend le 1er dispo.
      // Mais idéalement Gemini reste la source de descriptions/critiques.
      throw Exception(
          'Gemini a échoué : ${errors[AiSource.gemini] ?? "raison inconnue"}');
    }

    final cc = _merge(sources, errors);
    return _crossCheckPass(cc);
  }

  /// Pass unifié : un seul appel Gemini grounded qui à la fois
  /// (a) vérifie les valeurs consensus contre des sources web et
  /// (b) choisit la meilleure option parmi les conflits existants.
  static Future<CrossCheckResult> _crossCheckPass(CrossCheckResult cc) async {
    final m = cc.merged;

    // Champs en conflit (déjà dans disagreements)
    final conflictKeys = <String>{for (final d in cc.disagreements) d.fieldKey};
    final conflicts = <String, Map<String, String>>{};
    for (final d in cc.disagreements) {
      conflicts[d.fieldKey] = {
        for (final e in d.values.entries) e.key.name: e.value,
      };
    }

    // Construire l'identité du vin : si producer/name/vintage sont en
    // conflit, lister tous les candidats au lieu de prendre la valeur
    // Gemini par défaut (qui peut être fausse).
    String identityFor(
        String key, String? singleValue, String label) {
      if (conflictKeys.contains(key)) {
        final candidates = conflicts[key]!
            .values
            .where((v) => v.trim().isNotEmpty)
            .toSet()
            .join(' / ');
        return candidates.isEmpty ? '' : '[$label candidats : $candidates]';
      }
      return singleValue ?? '';
    }

    final identityParts = <String>[
      identityFor('producer', m.producer, 'producteur'),
      identityFor('name', m.name, 'nom'),
      identityFor('vintage', m.vintage?.toString(), 'millésime'),
    ].where((s) => s.isNotEmpty).toList();
    final identity = identityParts.join(' ');
    if (identity.trim().isEmpty) return cc;

    // Champs consensus = tous les autres champs vérifiables
    final consensusFields = <(String, String, String, bool, bool)>[
      ('name', 'Nom', m.name, false, false),
      ('producer', 'Producteur', m.producer, false, false),
      ('vintage', 'Millésime', m.vintage?.toString() ?? '', false, false),
      ('appellation', 'Appellation', m.appellation, false, false),
      ('country', 'Pays', m.country, false, false),
      ('region', 'Région', m.region, false, false),
      ('climat', 'Climat', m.climat, false, false),
      ('domaine', 'Domaine', m.domaine, false, false),
      ('village', 'Village', m.village, false, false),
      ('domainAddress', 'Adresse domaine', m.domainAddress, true, false),
      ('grapes', 'Cépages', m.grapes, true, true),
      ('alcohol', 'Alcool %', m.alcohol?.toString() ?? '', false, false),
      ('type', 'Type', m.type, false, false),
      ('drinkFrom', 'À boire dès', m.drinkFrom?.toString() ?? '', false, false),
      ('drinkPeak', 'Apogée', m.drinkPeak?.toString() ?? '', false, false),
      ('drinkTo', 'Fin de garde', m.drinkTo?.toString() ?? '', false, false),
      ('marketValue', 'Valeur marchande', m.marketValue?.toString() ?? '',
          false, false),
    ];

    final consensus = <String, String>{};
    final labels = <String, String>{};
    final modes = <String, (bool, bool)>{};
    for (final f in consensusFields) {
      labels[f.$1] = f.$2;
      modes[f.$1] = (f.$4, f.$5);
      if (conflictKeys.contains(f.$1)) continue;
      if (f.$3.trim().isEmpty) continue;
      consensus[f.$1] = f.$3;
    }

    Map<String, String> corrections;
    try {
      corrections = await GeminiService.crossCheck(
        wineIdentity: identity,
        consensus: consensus,
        conflicts: conflicts,
      );
    } catch (_) {
      return cc;
    }

    if (corrections.isEmpty) return cc;

    final disagreements = List<FieldDisagreement>.from(cc.disagreements);

    String norm(String v, String key) {
      final mode = modes[key] ?? (false, false);
      return mode.$1
          ? _normalizeUnordered(v, stripNumbers: mode.$2)
          : _normalize(v);
    }

    for (final entry in corrections.entries) {
      final key = entry.key;
      final corrected = entry.value;

      // Trouver disagreement existant ?
      FieldDisagreement? existing;
      for (final d in disagreements) {
        if (d.fieldKey == key) {
          existing = d;
          break;
        }
      }

      if (existing != null) {
        // C'est un conflit. Voir si la valeur du validator matche une option.
        AiSource? matched;
        for (final e in existing.values.entries) {
          if (norm(e.value, key) == norm(corrected, key)) {
            matched = e.key;
            break;
          }
        }
        if (matched != null) {
          existing.chosen = matched;
        } else {
          existing.values[AiSource.validator] = corrected;
          existing.chosen = AiSource.validator;
        }
      } else {
        // C'est un consensus : la validation propose une correction.
        final currentValue = consensus[key] ?? '';
        if (currentValue.isEmpty) continue;
        if (norm(corrected, key) == norm(currentValue, key)) continue;
        disagreements.add(FieldDisagreement(
          fieldKey: key,
          label: labels[key] ?? key,
          values: {
            AiSource.consensus: currentValue,
            AiSource.validator: corrected,
          },
          chosen: AiSource.validator,
        ));
      }
    }

    return CrossCheckResult(
      merged: cc.merged,
      disagreements: disagreements,
      sources: cc.sources,
      errors: cc.errors,
    );
  }

  static CrossCheckResult _merge(
    Map<AiSource, GeminiResult> sources,
    Map<AiSource, String> errors,
  ) {
    final disagreements = <FieldDisagreement>[];
    final gemini = sources[AiSource.gemini]!;

    String pickStr(String key, String label, String Function(GeminiResult) get,
        {bool unordered = false, bool stripNumbers = false}) {
      return _voteString(
        key: key,
        label: label,
        values: {for (final e in sources.entries) e.key: get(e.value)},
        disagreements: disagreements,
        unordered: unordered,
        stripNumbers: stripNumbers,
      );
    }

    int? pickInt(String key, String label, int? Function(GeminiResult) get) {
      return _voteInt(
        key: key,
        label: label,
        values: {for (final e in sources.entries) e.key: get(e.value)},
        disagreements: disagreements,
      );
    }

    double? pickDouble(
        String key, String label, double? Function(GeminiResult) get) {
      return _voteDouble(
        key: key,
        label: label,
        values: {for (final e in sources.entries) e.key: get(e.value)},
        disagreements: disagreements,
      );
    }

    final merged = GeminiResult(
      name: pickStr('name', 'Nom', (r) => r.name),
      producer: pickStr('producer', 'Producteur', (r) => r.producer),
      vintage: pickInt('vintage', 'Millésime', (r) => r.vintage),
      appellation:
          pickStr('appellation', 'Appellation', (r) => r.appellation),
      country: pickStr('country', 'Pays', (r) => r.country),
      region: pickStr('region', 'Région', (r) => r.region),
      climat: pickStr('climat', 'Climat', (r) => r.climat),
      domaine: pickStr('domaine', 'Domaine', (r) => r.domaine),
      village: pickStr('village', 'Village', (r) => r.village),
      domainAddress: pickStr(
          'domainAddress', 'Adresse domaine', (r) => r.domainAddress,
          unordered: true),
      grapes: pickStr('grapes', 'Cépages', (r) => r.grapes,
          unordered: true, stripNumbers: true),
      alcohol: pickDouble('alcohol', 'Alcool %', (r) => r.alcohol),
      type: pickStr('type', 'Type', (r) => r.type),
      drinkFrom:
          pickInt('drinkFrom', 'À boire dès', (r) => r.drinkFrom),
      drinkPeak: pickInt('drinkPeak', 'Apogée', (r) => r.drinkPeak),
      drinkTo: pickInt('drinkTo', 'Fin de garde', (r) => r.drinkTo),
      marketValue: pickDouble(
          'marketValue', 'Valeur marchande', (r) => r.marketValue),
      // Toujours Gemini :
      wineDescription: gemini.wineDescription,
      domaineDescription: gemini.domaineDescription,
      critiques: gemini.critiques,
    );

    return CrossCheckResult(
      merged: merged,
      disagreements: disagreements,
      sources: sources,
      errors: errors,
    );
  }

  /// Vote majoritaire pour les chaînes : si N-1 sources sur N sont d'accord
  /// (ou empty), on prend la majorité. Sinon disagreement.
  /// [unordered] : compare les tokens triés (utile pour cépages, adresses
  /// où l'ordre des éléments ne change pas le sens).
  static String _voteString({
    required String key,
    required String label,
    required Map<AiSource, String> values,
    required List<FieldDisagreement> disagreements,
    bool unordered = false,
    bool stripNumbers = false,
  }) {
    // On garde uniquement les valeurs non vides pour le vote.
    final nonEmpty = <AiSource, String>{
      for (final e in values.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value,
    };

    if (nonEmpty.isEmpty) return '';
    if (nonEmpty.length == 1) return nonEmpty.values.first;

    // Group par valeur normalisée.
    String norm(String v) => unordered
        ? _normalizeUnordered(v, stripNumbers: stripNumbers)
        : _normalize(v);
    final groups = <String, List<AiSource>>{};
    nonEmpty.forEach((src, v) {
      groups.putIfAbsent(norm(v), () => []).add(src);
    });

    if (groups.length == 1) {
      // Tous d'accord (sur les non-vides)
      return nonEmpty.values.first;
    }

    // Trouve le groupe majoritaire.
    final sorted = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    final top = sorted[0];
    final second = sorted[1];

    if (top.value.length > second.value.length) {
      // Majorité claire (2 vs 1, ou 3 vs 1, etc.)
      final pickedSrc = top.value.first;
      return nonEmpty[pickedSrc]!;
    }

    // Égalité : désaccord à confirmer par l'utilisateur.
    disagreements.add(FieldDisagreement(
      fieldKey: key,
      label: label,
      values: nonEmpty,
      chosen: nonEmpty.containsKey(AiSource.gemini)
          ? AiSource.gemini
          : nonEmpty.keys.first,
    ));
    return nonEmpty[AiSource.gemini] ?? nonEmpty.values.first;
  }

  static int? _voteInt({
    required String key,
    required String label,
    required Map<AiSource, int?> values,
    required List<FieldDisagreement> disagreements,
  }) {
    final nonNull = <AiSource, int>{
      for (final e in values.entries)
        if (e.value != null) e.key: e.value!,
    };
    if (nonNull.isEmpty) return null;
    if (nonNull.length == 1) return nonNull.values.first;

    final groups = <int, List<AiSource>>{};
    nonNull.forEach((src, v) {
      groups.putIfAbsent(v, () => []).add(src);
    });
    if (groups.length == 1) return nonNull.values.first;

    final sorted = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (sorted[0].value.length > sorted[1].value.length) {
      return sorted[0].key;
    }

    disagreements.add(FieldDisagreement(
      fieldKey: key,
      label: label,
      values: {for (final e in nonNull.entries) e.key: e.value.toString()},
      chosen: nonNull.containsKey(AiSource.gemini)
          ? AiSource.gemini
          : nonNull.keys.first,
    ));
    return nonNull[AiSource.gemini] ?? nonNull.values.first;
  }

  static double? _voteDouble({
    required String key,
    required String label,
    required Map<AiSource, double?> values,
    required List<FieldDisagreement> disagreements,
  }) {
    final nonNull = <AiSource, double>{
      for (final e in values.entries)
        if (e.value != null) e.key: e.value!,
    };
    if (nonNull.isEmpty) return null;
    if (nonNull.length == 1) return nonNull.values.first;

    // On groupe par valeur arrondie (tolérance pour le vote)
    final groups = <num, List<AiSource>>{};
    nonNull.forEach((src, v) {
      // arrondi à 1 décimale pour les votes
      final rounded = (v * 10).round() / 10;
      groups.putIfAbsent(rounded, () => []).add(src);
    });
    if (groups.length == 1) return nonNull.values.first;

    final sorted = groups.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
    if (sorted[0].value.length > sorted[1].value.length) {
      // Majorité — on prend la valeur exacte de la 1re source du groupe.
      return nonNull[sorted[0].value.first]!;
    }

    disagreements.add(FieldDisagreement(
      fieldKey: key,
      label: label,
      values: {for (final e in nonNull.entries) e.key: e.value.toString()},
      chosen: nonNull.containsKey(AiSource.gemini)
          ? AiSource.gemini
          : nonNull.keys.first,
    ));
    return nonNull[AiSource.gemini] ?? nonNull.values.first;
  }

  static String _normalize(String s) {
    // 1) Retire les caractères invisibles (zero-width, bidi marks, etc.)
    var n = s.replaceAll(
        RegExp(r'[​-‍﻿­⁠؜‎‏]'), '');
    // 2) Remplace tous les types d'espaces par un espace normal.
    n = n.replaceAll(
        RegExp(r'[      - 　]'), ' ');
    // 3) Lowercase + trim.
    n = n.toLowerCase().trim();
    // 4) Map des caractères spéciaux vers leur équivalent ASCII.
    final repl = <String, String>{
      'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
      'ā': 'a', 'ă': 'a', 'ą': 'a',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e',
      'ę': 'e', 'ě': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i',
      'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o',
      'ō': 'o', 'ő': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u',
      'ű': 'u', 'ų': 'u',
      'ý': 'y', 'ÿ': 'y',
      'ç': 'c', 'ć': 'c', 'č': 'c',
      'ñ': 'n', 'ń': 'n', 'ň': 'n',
      'œ': 'oe', 'æ': 'ae', 'ß': 'ss',
      'š': 's', 'ś': 's', 'ş': 's',
      'ž': 'z', 'ź': 'z', 'ż': 'z',
      'ł': 'l', 'ľ': 'l',
      'ř': 'r', 'ť': 't', 'ð': 'd', 'þ': 'th',
    };
    repl.forEach((k, v) => n = n.replaceAll(k, v));
    // 5) Retire les marques diacritiques combinantes (NFD residuelles) et
    //    autres caractères de catégorie Mn / Mc.
    n = n.replaceAll(RegExp(r'[̀-ͯ҃-҉]'), '');
    // 6) Remplace tout caractère non-alphanumérique par un espace.
    n = n.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    // 7) Compresse les espaces multiples.
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    return n;
  }

  /// Normalisation insensible à l'ordre des mots et aux mots vides courants
  /// (de, la, et, etc.). Utilisé pour cépages et adresses.
  /// [stripNumbers] : retire les nombres (utile pour cépages avec/sans %).
  static String _normalizeUnordered(String s, {bool stripNumbers = false}) {
    var base = _normalize(s);
    if (base.isEmpty) return '';
    if (stripNumbers) {
      base = base.replaceAll(RegExp(r'\b\d+\b'), ' ');
    }
    const stopWords = {
      'de', 'du', 'des', 'la', 'le', 'les', 'l', 'd',
      'et', 'a', 'au', 'aux', 'en', 'sur', 'pres', 'rue',
    };
    final tokens = base
        .split(' ')
        .where((t) => t.isNotEmpty && !stopWords.contains(t))
        .toList()
      ..sort();
    return tokens.join(' ');
  }

  /// Applique les choix utilisateur sur le merged.
  static GeminiResult applyChoices(
    CrossCheckResult cc,
    List<FieldDisagreement> chosen,
  ) {
    final m = cc.merged;
    final byKey = {for (final d in chosen) d.fieldKey: d};

    String pickStr(String key, String fallback) {
      final d = byKey[key];
      if (d == null) return fallback;
      return d.values[d.chosen] ?? fallback;
    }

    int? pickInt(String key, int? fallback) {
      final d = byKey[key];
      if (d == null) return fallback;
      final v = d.values[d.chosen];
      if (v == null) return fallback;
      return int.tryParse(v.trim()) ?? fallback;
    }

    double? pickDouble(String key, double? fallback) {
      final d = byKey[key];
      if (d == null) return fallback;
      final v = d.values[d.chosen];
      if (v == null) return fallback;
      return double.tryParse(v.trim()) ?? fallback;
    }

    return GeminiResult(
      name: pickStr('name', m.name),
      producer: pickStr('producer', m.producer),
      vintage: pickInt('vintage', m.vintage),
      appellation: pickStr('appellation', m.appellation),
      country: pickStr('country', m.country),
      region: pickStr('region', m.region),
      climat: pickStr('climat', m.climat),
      domaine: pickStr('domaine', m.domaine),
      village: pickStr('village', m.village),
      domainAddress: pickStr('domainAddress', m.domainAddress),
      grapes: pickStr('grapes', m.grapes),
      alcohol: pickDouble('alcohol', m.alcohol),
      type: pickStr('type', m.type),
      drinkFrom: pickInt('drinkFrom', m.drinkFrom),
      drinkPeak: pickInt('drinkPeak', m.drinkPeak),
      drinkTo: pickInt('drinkTo', m.drinkTo),
      marketValue: pickDouble('marketValue', m.marketValue),
      wineDescription: m.wineDescription,
      domaineDescription: m.domaineDescription,
      critiques: m.critiques,
    );
  }
}
