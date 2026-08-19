import 'dart:async';


import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/wine.dart';
import 'ai_cross_check.dart';
import 'cave_service.dart';
import 'gemini_service.dart';

/// Avancement de l'analyse différée, pour l'affichage.
class PendingAiProgress {
  final bool running;
  final int done;
  final int total;
  final String? currentLabel;
  final int failed;

  const PendingAiProgress({
    this.running = false,
    this.done = 0,
    this.total = 0,
    this.currentLabel,
    this.failed = 0,
  });

  bool get finished => !running && total > 0;
}

/// Analyse IA différée des bouteilles entrées « en vitesse ».
///
/// Le principe : à l'entrée, on enregistre tout de suite le vin et ses
/// bouteilles (photo, quantité, emplacements) avec `aiPending = true`. Les
/// bouteilles sont donc dans la cave, à leur place, immédiatement. Plus tard,
/// quand tout est rentré, on lance cette analyse : elle reprend chaque vin en
/// attente, lit l'étiquette et remplit la fiche.
///
/// Le résultat est applique automatiquement, et le vin passe en
/// `aiNeedsReview = true` (pastille « à vérifier ») jusqu'à ce que la fiche
/// soit ouverte.
class PendingAiService {
  static final ValueNotifier<PendingAiProgress> progress =
      ValueNotifier<PendingAiProgress>(const PendingAiProgress());

  static bool _running = false;
  static bool _cancelRequested = false;

  static bool get isRunning => _running;

  /// Demande l'arrêt après le vin en cours.
  static void cancel() => _cancelRequested = true;

  /// Analyse tous les vins en attente, un par un (les IA sont déjà appelées
  /// en parallèle pour un même vin ; en enchaîner plusieurs en même temps
  /// ferait surtout monter le risque de limite de quota).
  static Future<void> runAll(List<Wine> wines) async {
    if (_running) return;
    final pending = wines.where((w) => w.aiPending).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (pending.isEmpty) return;

    _running = true;
    _cancelRequested = false;
    var done = 0;
    var failed = 0;
    progress.value = PendingAiProgress(
      running: true,
      total: pending.length,
      currentLabel: _labelOf(pending.first),
    );

    try {
      for (final wine in pending) {
        if (_cancelRequested) break;
        progress.value = PendingAiProgress(
          running: true,
          done: done,
          total: pending.length,
          failed: failed,
          currentLabel: _labelOf(wine),
        );
        final ok = await _analyzeOne(wine);
        done++;
        if (!ok) failed++;
      }
    } finally {
      _running = false;
      progress.value = PendingAiProgress(
        running: false,
        done: done,
        total: pending.length,
        failed: failed,
      );
    }
  }

  /// Analyse un seul vin. Renvoie false si ça a échoué (le vin reste
  /// « à identifier », avec la raison dans `aiError`).
  static Future<bool> analyze(Wine wine) => _analyzeOne(wine);

  static String _labelOf(Wine w) {
    final n = w.name.trim();
    if (n.isNotEmpty) return n;
    final note = w.quickNote.trim();
    if (note.isNotEmpty) return note;
    final v = w.vintage;
    return v != null ? 'Bouteille $v' : 'Bouteille sans nom';
  }

  static Future<bool> _analyzeOne(Wine wine) async {
    try {
      if (!GeminiService.isConfigured) {
        throw Exception(
          'Clé Gemini absente (Paramètres → Intelligence artificielle).',
        );
      }

      final CrossCheckResult cc;
      final photo = wine.photoUrl;
      if (photo != null && photo.isNotEmpty) {
        final bytes = await _download(photo);
        cc = await AiCrossCheck.searchByPhoto(
          bytes,
          vintageHint: wine.vintage?.toString(),
        );
      } else if (wine.name.trim().isNotEmpty) {
        // Pas de photo mais un nom saisi à la main : on cherche par texte.
        cc = await AiCrossCheck.searchByText(
          name: wine.name.trim(),
          domaine: wine.domaine.trim(),
          vintage: wine.vintage?.toString() ?? '',
        );
      } else {
        throw Exception('Ni photo ni nom : rien à analyser.');
      }

      final update = _updateFrom(cc.merged, wine);
      update['aiPending'] = false;
      update['aiNeedsReview'] = true;
      update['aiError'] = null;
      await CaveService.updateWine(wine.id, update);
      return true;
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      try {
        await CaveService.updateWine(wine.id, {'aiError': msg});
      } catch (_) {}
      return false;
    }
  }

  static Future<Uint8List> _download(String url) async {
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw Exception('Photo illisible (HTTP ${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  /// Construit la mise à jour Firestore à partir du résultat IA.
  ///
  /// Règle : on ne remplace JAMAIS une valeur déjà saisie à la main par du
  /// vide, et le millésime tapé à l'entrée gagne sur celui devine par l'IA.
  static Map<String, dynamic> _updateFrom(GeminiResult r, Wine wine) {
    final u = <String, dynamic>{};

    void text(String key, String value, String existing) {
      final v = value.trim();
      if (v.isEmpty) return;
      if (existing.trim().isNotEmpty) return; // saisi a la main : on garde
      u[key] = v;
    }

    text('name', r.name, wine.name);
    text('producer', r.producer, wine.producer);
    text('appellation', r.appellation, wine.appellation);
    text('country', r.country, wine.country);
    text('region', r.region, wine.region);
    text('climat', r.climat, wine.climat);
    text('domaine', r.domaine, wine.domaine);
    text('village', r.village, wine.village);
    text('domainAddress', r.domainAddress, wine.domainAddress);
    text('grapes', r.grapes, wine.grapes);
    text('wineDescription', r.wineDescription, wine.wineDescription);
    text('domaineDescription', r.domaineDescription, wine.domaineDescription);

    if (wine.vintage == null && r.vintage != null) u['vintage'] = r.vintage;
    if (wine.alcohol == null && r.alcohol != null) u['alcohol'] = r.alcohol;
    if (wine.drinkFrom == null && r.drinkFrom != null) {
      u['drinkFrom'] = r.drinkFrom;
    }
    if (wine.drinkPeak == null && r.drinkPeak != null) {
      u['drinkPeak'] = r.drinkPeak;
    }
    if (wine.drinkTo == null && r.drinkTo != null) u['drinkTo'] = r.drinkTo;

    if (r.type.isNotEmpty) {
      final t = WineType.values.firstWhere(
        (x) => x.name == r.type,
        orElse: () => wine.type,
      );
      u['type'] = t.name;
    }

    if (r.critiques.isNotEmpty && wine.critiques.isEmpty) {
      u['critiques'] = r.critiques.map((c) => c.toMap()).toList();
    }

    return u;
  }
}
