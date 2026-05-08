import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wine.dart';
import '../models/market_history.dart';
import '../models/garde_history.dart';
import 'gemini_service.dart';
import 'cave_service.dart';
import 'cave_preferences_service.dart';

class ActualisationService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference _marketCol(String wineId) =>
      _db.collection('wines').doc(wineId).collection('marketHistory');

  static CollectionReference _gardeCol(String wineId) =>
      _db.collection('wines').doc(wineId).collection('gardeHistory');

  // --- Market History CRUD ---

  static Stream<List<MarketHistoryEntry>> watchMarketHistory(String wineId) =>
      _marketCol(wineId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((s) => s.docs.map(MarketHistoryEntry.fromDoc).toList());

  static Future<List<MarketHistoryEntry>> getMarketHistory(String wineId) async {
    final snap = await _marketCol(wineId).orderBy('timestamp', descending: true).get();
    return snap.docs.map(MarketHistoryEntry.fromDoc).toList();
  }

  // --- Garde History CRUD ---

  static Stream<List<GardeHistoryEntry>> watchGardeHistory(String wineId) =>
      _gardeCol(wineId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((s) => s.docs.map(GardeHistoryEntry.fromDoc).toList());

  static Future<List<GardeHistoryEntry>> getGardeHistory(String wineId) async {
    final snap = await _gardeCol(wineId).orderBy('timestamp', descending: true).get();
    return snap.docs.map(GardeHistoryEntry.fromDoc).toList();
  }

  // --- Seed initial data from existing wine/bottles ---

  static Future<void> seedIfNeeded(Wine wine) async {
    final marketSnap = await _marketCol(wine.id).limit(1).get();
    if (marketSnap.docs.isEmpty) {
      final bottles = await CaveService.bottlesByWine(wine.id).first;
      for (final b in bottles) {
        if (b.marketValue != null) {
          await _marketCol(wine.id).add(MarketHistoryEntry(
            id: '',
            value: b.marketValue!,
            timestamp: b.createdAt,
            source: 'initial',
          ).toMap());
        }
      }
    }

    final gardeSnap = await _gardeCol(wine.id).limit(1).get();
    if (gardeSnap.docs.isEmpty) {
      if (wine.drinkFrom != null || wine.drinkPeak != null || wine.drinkTo != null) {
        await _gardeCol(wine.id).add(GardeHistoryEntry(
          id: '',
          drinkFrom: wine.drinkFrom,
          drinkPeak: wine.drinkPeak,
          drinkTo: wine.drinkTo,
          timestamp: wine.createdAt,
          source: 'initial',
        ).toMap());
      }
    }
  }

  // --- Refresh market value for one wine ---

  static Future<double?> refreshMarketValue(Wine wine) async {
    final base750 = await GeminiService.estimateMarketValue(
      name: wine.name,
      producer: wine.producer,
      vintage: wine.vintage?.toString(),
      appellation: wine.appellation,
    );

    if (base750 != null) {
      await _marketCol(wine.id).add(MarketHistoryEntry(
        id: '',
        value: base750,
        timestamp: DateTime.now(),
        source: 'gemini',
      ).toMap());

      final bottles = await CaveService.bottlesByWine(wine.id).first;
      for (final b in bottles) {
        final adjusted = (base750 * b.format.marketMultiplier).roundToDouble();
        await CaveService.updateBottle(b.id, {'marketValue': adjusted});
      }
    }

    return base750;
  }

  // --- Refresh garde for one wine ---

  static Future<({int? drinkFrom, int? drinkPeak, int? drinkTo})?> refreshGarde(Wine wine) async {
    final result = await GeminiService.estimateGarde(
      name: wine.name,
      producer: wine.producer,
      vintage: wine.vintage?.toString(),
      appellation: wine.appellation,
    );

    if (result.drinkFrom != null || result.drinkPeak != null || result.drinkTo != null) {
      await _gardeCol(wine.id).add(GardeHistoryEntry(
        id: '',
        drinkFrom: result.drinkFrom,
        drinkPeak: result.drinkPeak,
        drinkTo: result.drinkTo,
        timestamp: DateTime.now(),
        source: 'gemini',
      ).toMap());

      final averaged = await computeAveragedGarde(wine.id);
      await CaveService.updateWine(wine.id, {
        'drinkFrom': averaged.drinkFrom,
        'drinkPeak': averaged.drinkPeak,
        'drinkTo': averaged.drinkTo,
      });
    }

    return result;
  }

  // --- Compute averaged garde from all history ---

  static Future<({int? drinkFrom, int? drinkPeak, int? drinkTo})> computeAveragedGarde(String wineId) async {
    final entries = await getGardeHistory(wineId);
    if (entries.isEmpty) return (drinkFrom: null, drinkPeak: null, drinkTo: null);

    int? avg(int? Function(GardeHistoryEntry) getter) {
      final values = entries.map(getter).whereType<int>().toList();
      if (values.isEmpty) return null;
      return (values.reduce((a, b) => a + b) / values.length).round();
    }

    return (
      drinkFrom: avg((e) => e.drinkFrom),
      drinkPeak: avg((e) => e.drinkPeak),
      drinkTo: avg((e) => e.drinkTo),
    );
  }

  // --- Bulk refresh ---

  static Future<void> refreshAllMarketValues(
    List<Wine> wines, {
    void Function(int done, int total)? onProgress,
  }) async {
    for (var i = 0; i < wines.length; i++) {
      try {
        await refreshMarketValue(wines[i]);
      } catch (_) {}
      onProgress?.call(i + 1, wines.length);
      if (i < wines.length - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  static Future<void> refreshAllGarde(
    List<Wine> wines, {
    void Function(int done, int total)? onProgress,
  }) async {
    for (var i = 0; i < wines.length; i++) {
      try {
        await refreshGarde(wines[i]);
      } catch (_) {}
      onProgress?.call(i + 1, wines.length);
      if (i < wines.length - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  // --- Auto-refresh scheduled batch ---

  static Future<void> runAutoRefreshIfDue(List<Wine> wines) async {
    if (!CavePreferencesService.autoRefreshEnabled.value) return;
    if (wines.isEmpty) return;

    final period = CavePreferencesService.autoRefreshPeriod.value;
    final periodDays = period == 'week' ? 7 : 30;
    final lastRun = CavePreferencesService.lastAutoRefreshRun.value;
    final now = DateTime.now();

    if (lastRun != null && now.difference(lastRun).inDays < periodDays) return;

    final percent = CavePreferencesService.autoRefreshPercent.value;
    final count = (wines.length * percent / 100).ceil().clamp(1, wines.length);

    // Sort: wines never refreshed first, then oldest refresh first
    final sorted = [...wines]..sort((a, b) {
        if (a.lastAutoRefreshed == null && b.lastAutoRefreshed == null) return 0;
        if (a.lastAutoRefreshed == null) return -1;
        if (b.lastAutoRefreshed == null) return 1;
        return a.lastAutoRefreshed!.compareTo(b.lastAutoRefreshed!);
      });

    final batch = sorted.take(count).toList();

    // Mark run time immediately to prevent double-runs if app reopens during refresh
    await CavePreferencesService.setLastAutoRefreshRun(now);

    for (final wine in batch) {
      try {
        await refreshMarketValue(wine);
        await refreshGarde(wine);
        await CaveService.updateWine(wine.id, {
          'lastAutoRefreshed': Timestamp.fromDate(now),
        });
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 2));
    }
  }
}
