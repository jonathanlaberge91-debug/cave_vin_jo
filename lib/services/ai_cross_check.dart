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
  static Future<CrossCheckResult> searchByPhoto(Uint8List bytes) async {
    // OCR en arrière-plan pour fournir un hint texte aux IA. Si OCR échoue
    // ou n'est pas dispo (mobile), on continue sans hint.
    final ocrHint = await OcrService.recognize(bytes);

    final futures = <AiSource, Future<GeminiResult>>{
      AiSource.gemini:
          GeminiService.searchByPhoto(bytes, ocrHint: ocrHint),
      if (GroqService.isConfigured)
        AiSource.groq:
            GroqService.searchByPhoto(bytes, ocrHint: ocrHint),
      if (MistralService.isConfigured)
        AiSource.mistral:
            MistralService.searchByPhoto(bytes, ocrHint: ocrHint),
    };
    return _runAndMerge(futures);
  }

  static Future<CrossCheckResult> _runAndMerge(
    Map<AiSource, Future<GeminiResult>> futures,
  ) async {
    final entries = futures.entries.toList();
    final results = await Future.wait(
      entries.map((e) => e.value
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
    final ccValidated = await _validatePass(cc);
    return _resolveRemainingConflicts(ccValidated);
  }

  /// Pour chaque conflit restant (3 IA divergentes ou validation), demande
  /// à Gemini grounded de pré-choisir la bonne option par recherche web.
  /// Le dialog s'ouvre quand même mais avec le choix IA pré-sélectionné.
  static Future<CrossCheckResult> _resolveRemainingConflicts(
      CrossCheckResult cc) async {
    if (cc.disagreements.isEmpty) return cc;

    final m = cc.merged;
    final identity = <String>[
      if (m.producer.isNotEmpty) m.producer,
      if (m.name.isNotEmpty) m.name,
      if (m.vintage != null) m.vintage.toString(),
    ].join(' ');
    if (identity.trim().isEmpty) return cc;

    final conflicts = <String, Map<String, String>>{};
    for (final d in cc.disagreements) {
      conflicts[d.fieldKey] = {
        for (final e in d.values.entries) e.key.name: e.value,
      };
    }

    Map<String, String> resolutions;
    try {
      resolutions = await GeminiService.resolveConflicts(
        wineIdentity: identity,
        conflicts: conflicts,
      );
    } catch (_) {
      return cc;
    }

    if (resolutions.isEmpty) return cc;

    for (final d in cc.disagreements) {
      final chosenName = resolutions[d.fieldKey];
      if (chosenName == null) continue;
      AiSource? matched;
      for (final src in d.values.keys) {
        if (src.name == chosenName) {
          matched = src;
          break;
        }
      }
      if (matched != null) {
        d.chosen = matched;
      }
    }

    return cc;
  }

  /// Phase de validation : envoie le résultat consensus à Gemini en mode
  /// fact-checking grounded. Toute correction trouvée est ajoutée comme
  /// désaccord pour confirmation utilisateur.
  static Future<CrossCheckResult> _validatePass(CrossCheckResult cc) async {
    Map<String, String> corrections;
    try {
      corrections = await GeminiService.validateWine(cc.merged);
    } catch (_) {
      return cc;
    }
    if (corrections.isEmpty) return cc;

    final m = cc.merged;
    final disagreements = List<FieldDisagreement>.from(cc.disagreements);

    void addCorrection(String key, String label, String currentValue) {
      final corrected = corrections[key];
      if (corrected == null || corrected.trim().isEmpty) return;
      // Ne pas re-flagger si déjà identique au consensus
      if (_normalize(corrected) == _normalize(currentValue)) return;

      // Si déjà dans les disagreements, ajoute juste la valeur validator
      FieldDisagreement? existing;
      for (final d in disagreements) {
        if (d.fieldKey == key) {
          existing = d;
          break;
        }
      }
      if (existing != null) {
        existing.values[AiSource.validator] = corrected;
        existing.chosen = AiSource.validator;
      } else {
        disagreements.add(FieldDisagreement(
          fieldKey: key,
          label: label,
          values: {
            AiSource.consensus: currentValue,
            AiSource.validator: corrected,
          },
          chosen: AiSource.validator, // par défaut on suggère la correction
        ));
      }
    }

    addCorrection('name', 'Nom', m.name);
    addCorrection('producer', 'Producteur', m.producer);
    addCorrection('vintage', 'Millésime', m.vintage?.toString() ?? '');
    addCorrection('appellation', 'Appellation', m.appellation);
    addCorrection('country', 'Pays', m.country);
    addCorrection('region', 'Région', m.region);
    addCorrection('climat', 'Climat', m.climat);
    addCorrection('domaine', 'Domaine', m.domaine);
    addCorrection('village', 'Village', m.village);
    addCorrection('domainAddress', 'Adresse domaine', m.domainAddress);
    addCorrection('grapes', 'Cépages', m.grapes);
    addCorrection('alcohol', 'Alcool %', m.alcohol?.toString() ?? '');
    addCorrection('type', 'Type', m.type);
    addCorrection('drinkFrom', 'À boire dès',
        m.drinkFrom?.toString() ?? '');
    addCorrection('drinkPeak', 'Apogée', m.drinkPeak?.toString() ?? '');
    addCorrection('drinkTo', 'Fin de garde', m.drinkTo?.toString() ?? '');
    addCorrection('marketValue', 'Valeur marchande',
        m.marketValue?.toString() ?? '');

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
        {bool unordered = false}) {
      return _voteString(
        key: key,
        label: label,
        values: {for (final e in sources.entries) e.key: get(e.value)},
        disagreements: disagreements,
        unordered: unordered,
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
      grapes:
          pickStr('grapes', 'Cépages', (r) => r.grapes, unordered: true),
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
  }) {
    // On garde uniquement les valeurs non vides pour le vote.
    final nonEmpty = <AiSource, String>{
      for (final e in values.entries)
        if (e.value.trim().isNotEmpty) e.key: e.value,
    };

    if (nonEmpty.isEmpty) return '';
    if (nonEmpty.length == 1) return nonEmpty.values.first;

    // Group par valeur normalisée.
    String norm(String v) =>
        unordered ? _normalizeUnordered(v) : _normalize(v);
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
  static String _normalizeUnordered(String s) {
    final base = _normalize(s);
    if (base.isEmpty) return '';
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
