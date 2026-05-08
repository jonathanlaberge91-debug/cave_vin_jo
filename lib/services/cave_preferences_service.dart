import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bottle.dart';
import '../models/cave_column.dart';
import '../models/drunk_column.dart';
import '../models/stat_item.dart';
import '../models/wish_column.dart';

class CavePreferencesService {
  static const _key = 'cave_columns';
  static const _drunkKey = 'drunk_columns';
  static const _wishKey = 'wish_columns';
  static const _zoomKey = 'cellar_zoom';
  static const _statsOrderKey = 'stats_order';
  static const _statsLayoutKey = 'stats_layout';
  static const _statsHidePricesKey = 'stats_hide_prices';
  static const _statsChartTypesKey = 'stats_chart_types';
  static final _settingsDoc =
      FirebaseFirestore.instance.collection('settings').doc('app');

  static final ValueNotifier<Set<CaveColumn>> visible =
      ValueNotifier(CaveColumn.defaults);

  static final ValueNotifier<Set<DrunkColumn>> drunkVisible =
      ValueNotifier(DrunkColumn.defaults);

  static final ValueNotifier<Set<WishColumn>> wishVisible =
      ValueNotifier(WishColumn.defaults);

  static final ValueNotifier<int> cellarZoom = ValueNotifier(5);

  static final ValueNotifier<List<StatItem>> statsOrder =
      ValueNotifier(StatItem.defaultOrder);

  static final ValueNotifier<List<List<StatItem>>> statsLayout =
      ValueNotifier(StatItem.defaultLayout);

  static final ValueNotifier<bool> statsHidePrices = ValueNotifier(false);

  static final ValueNotifier<Map<StatItem, StatChartType>> statsChartTypes =
      ValueNotifier({});

  static const _tableKey = 'table_columns';
  static final ValueNotifier<Set<CaveColumn>> tableVisible = ValueNotifier({
    CaveColumn.name, CaveColumn.vintage, CaveColumn.type,
    CaveColumn.region, CaveColumn.domaine, CaveColumn.appellation,
    CaveColumn.rating, CaveColumn.garde, CaveColumn.drinkFrom,
    CaveColumn.apogee, CaveColumn.drinkTo, CaveColumn.qty, CaveColumn.price,
  });

  static const _hidePricesKey = 'hide_prices';
  static final ValueNotifier<bool> hidePrices = ValueNotifier(false);

  static const _customSourcesKey = 'custom_sources';
  static final ValueNotifier<List<String>> customSources =
      ValueNotifier(const []);

  static const _autoRefreshEnabledKey = 'auto_refresh_enabled';
  static const _autoRefreshPercentKey = 'auto_refresh_percent';
  static const _autoRefreshPeriodKey = 'auto_refresh_period';
  static const _lastAutoRefreshRunKey = 'last_auto_refresh_run';

  static final ValueNotifier<bool> autoRefreshEnabled = ValueNotifier(false);
  static final ValueNotifier<int> autoRefreshPercent = ValueNotifier(10);
  static final ValueNotifier<String> autoRefreshPeriod = ValueNotifier('month');
  static final ValueNotifier<DateTime?> lastAutoRefreshRun = ValueNotifier(null);

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final local = prefs.getStringList(_key);
    if (local != null) {
      visible.value = _decode(local);
    }

    final drunkLocal = prefs.getStringList(_drunkKey);
    if (drunkLocal != null) {
      drunkVisible.value = _decodeDrunk(drunkLocal);
    }

    final wishLocal = prefs.getStringList(_wishKey);
    if (wishLocal != null) {
      wishVisible.value = _decodeWish(wishLocal);
    }

    final zoom = prefs.getInt(_zoomKey);
    if (zoom != null) cellarZoom.value = zoom.clamp(1, 10);

    final statsLocal = prefs.getStringList(_statsOrderKey);
    if (statsLocal != null) statsOrder.value = _decodeStats(statsLocal);

    final layoutLocal = prefs.getStringList(_statsLayoutKey);
    if (layoutLocal != null) statsLayout.value = _decodeLayout(layoutLocal);

    final statsHidePricesLocal = prefs.getBool(_statsHidePricesKey);
    if (statsHidePricesLocal != null) statsHidePrices.value = statsHidePricesLocal;

    final chartTypesLocal = prefs.getStringList(_statsChartTypesKey);
    if (chartTypesLocal != null) {
      statsChartTypes.value = _decodeChartTypes(chartTypesLocal);
    }

    final tableLocal = prefs.getStringList(_tableKey);
    if (tableLocal != null) {
      final decoded = _decodeCols(tableLocal);
      if (decoded.isNotEmpty) tableVisible.value = decoded;
    }

    final hidePricesLocal = prefs.getBool(_hidePricesKey);
    if (hidePricesLocal != null) {
      hidePrices.value = hidePricesLocal;
    }

    final customSourcesLocal = prefs.getStringList(_customSourcesKey);
    if (customSourcesLocal != null) {
      customSources.value = List.unmodifiable(customSourcesLocal);
    }

    final arEnabled = prefs.getBool(_autoRefreshEnabledKey);
    if (arEnabled != null) autoRefreshEnabled.value = arEnabled;
    final arPercent = prefs.getInt(_autoRefreshPercentKey);
    if (arPercent != null) autoRefreshPercent.value = arPercent;
    final arPeriod = prefs.getString(_autoRefreshPeriodKey);
    if (arPeriod != null) autoRefreshPeriod.value = arPeriod;
    final lastRun = prefs.getString(_lastAutoRefreshRunKey);
    if (lastRun != null) lastAutoRefreshRun.value = DateTime.tryParse(lastRun);

    try {
      final snap = await _settingsDoc.get();

      final remoteDrunk = snap.data()?['drunkColumns'] as List?;
      if (remoteDrunk != null) {
        final ids = remoteDrunk.map((e) => e.toString()).toList();
        drunkVisible.value = _decodeDrunk(ids);
        await prefs.setStringList(_drunkKey, ids);
      } else if (drunkLocal != null) {
        await _settingsDoc.set(
          {'drunkColumns': drunkLocal},
          SetOptions(merge: true),
        );
      }

      final remoteWish = snap.data()?['wishColumns'] as List?;
      if (remoteWish != null) {
        final ids = remoteWish.map((e) => e.toString()).toList();
        wishVisible.value = _decodeWish(ids);
        await prefs.setStringList(_wishKey, ids);
      } else if (wishLocal != null) {
        await _settingsDoc.set(
          {'wishColumns': wishLocal},
          SetOptions(merge: true),
        );
      }

      final remote = snap.data()?['caveColumns'] as List?;
      if (remote != null) {
        final ids = remote.map((e) => e.toString()).toList();
        visible.value = _decode(ids);
        await prefs.setStringList(_key, ids);
      } else if (local != null) {
        await _settingsDoc.set(
          {'caveColumns': local},
          SetOptions(merge: true),
        );
      }
      final remoteZoom = snap.data()?['cellarZoom'] as int?;
      if (remoteZoom != null) {
        cellarZoom.value = remoteZoom.clamp(1, 10);
        await prefs.setInt(_zoomKey, cellarZoom.value);
      } else if (zoom != null) {
        await _settingsDoc.set(
          {'cellarZoom': zoom},
          SetOptions(merge: true),
        );
      }

      final remoteStats = snap.data()?['statsOrder'] as List?;
      if (remoteStats != null) {
        final ids = remoteStats.map((e) => e.toString()).toList();
        statsOrder.value = _decodeStats(ids);
        await prefs.setStringList(_statsOrderKey, ids);
      } else if (statsLocal != null) {
        await _settingsDoc.set(
          {'statsOrder': statsLocal},
          SetOptions(merge: true),
        );
      }

      final remoteLayout = snap.data()?['statsLayout'] as List?;
      if (remoteLayout != null) {
        final rows = remoteLayout.map((e) => e.toString()).toList();
        statsLayout.value = _decodeLayout(rows);
        await prefs.setStringList(_statsLayoutKey, rows);
      } else if (layoutLocal != null) {
        await _settingsDoc.set(
          {'statsLayout': layoutLocal},
          SetOptions(merge: true),
        );
      }

      final remoteHidePricesGlobal = snap.data()?['hidePrices'] as bool?;
      if (remoteHidePricesGlobal != null) {
        hidePrices.value = remoteHidePricesGlobal;
        await prefs.setBool(_hidePricesKey, remoteHidePricesGlobal);
      } else if (hidePricesLocal != null) {
        await _settingsDoc.set({'hidePrices': hidePricesLocal}, SetOptions(merge: true));
      }

      final remoteCustomSources = snap.data()?['customSources'] as List?;
      if (remoteCustomSources != null) {
        final list = remoteCustomSources
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
        customSources.value = List.unmodifiable(list);
        await prefs.setStringList(_customSourcesKey, list);
      } else if (customSourcesLocal != null) {
        await _settingsDoc.set(
          {'customSources': customSourcesLocal},
          SetOptions(merge: true),
        );
      }

      final remoteHidePrices = snap.data()?['statsHidePrices'] as bool?;
      if (remoteHidePrices != null) {
        statsHidePrices.value = remoteHidePrices;
        await prefs.setBool(_statsHidePricesKey, remoteHidePrices);
      } else if (statsHidePricesLocal != null) {
        await _settingsDoc.set(
          {'statsHidePrices': statsHidePricesLocal},
          SetOptions(merge: true),
        );
      }

      final remoteChartTypes = snap.data()?['statsChartTypes'] as List?;
      if (remoteChartTypes != null) {
        final encoded = remoteChartTypes.map((e) => e.toString()).toList();
        statsChartTypes.value = _decodeChartTypes(encoded);
        await prefs.setStringList(_statsChartTypesKey, encoded);
      } else if (chartTypesLocal != null) {
        await _settingsDoc.set(
          {'statsChartTypes': chartTypesLocal},
          SetOptions(merge: true),
        );
      }

      final remoteArEnabled = snap.data()?['autoRefreshEnabled'] as bool?;
      if (remoteArEnabled != null) {
        autoRefreshEnabled.value = remoteArEnabled;
        await prefs.setBool(_autoRefreshEnabledKey, remoteArEnabled);
      } else if (arEnabled != null) {
        await _settingsDoc.set({'autoRefreshEnabled': arEnabled}, SetOptions(merge: true));
      }
      final remoteArPercent = snap.data()?['autoRefreshRatePercent'] as int?;
      if (remoteArPercent != null) {
        autoRefreshPercent.value = remoteArPercent;
        await prefs.setInt(_autoRefreshPercentKey, remoteArPercent);
      } else if (arPercent != null) {
        await _settingsDoc.set({'autoRefreshRatePercent': arPercent}, SetOptions(merge: true));
      }
      final remoteArPeriod = snap.data()?['autoRefreshRatePeriod'] as String?;
      if (remoteArPeriod != null) {
        autoRefreshPeriod.value = remoteArPeriod;
        await prefs.setString(_autoRefreshPeriodKey, remoteArPeriod);
      } else if (arPeriod != null) {
        await _settingsDoc.set({'autoRefreshRatePeriod': arPeriod}, SetOptions(merge: true));
      }
    } catch (_) {}
  }

  static Set<CaveColumn> _decodeCols(List<String> ids) {
    final result = <CaveColumn>{};
    for (final id in ids) {
      try { result.add(CaveColumn.values.byName(id)); } catch (_) {}
    }
    return result;
  }

  static Future<void> setTableVisible(Set<CaveColumn> cols) async {
    tableVisible.value = cols;
    final ids = cols.map((c) => c.name).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_tableKey, ids);
  }

  static Future<void> setVisible(Set<CaveColumn> v) async {
    final withEssentials = {...v, ...CaveColumn.essentials};
    visible.value = withEssentials;

    final ids = withEssentials.map((c) => c.name).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids);

    try {
      await _settingsDoc.set(
        {'caveColumns': ids},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static List<String> get allSourceLabels {
    final defaults = BottleSource.defaultLabels;
    final custom = customSources.value
        .where((s) => !defaults.contains(s))
        .toList();
    return [...defaults, ...custom];
  }

  static Future<void> addCustomSource(String label) async {
    final clean = label.trim();
    if (clean.isEmpty) return;
    final defaults = BottleSource.defaultLabels;
    if (defaults.contains(clean)) return;
    final current = List<String>.from(customSources.value);
    if (current.contains(clean)) return;
    current.add(clean);
    customSources.value = List.unmodifiable(current);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customSourcesKey, current);
    try {
      await _settingsDoc.set(
        {'customSources': current},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static Future<void> removeCustomSource(String label) async {
    final current = List<String>.from(customSources.value);
    if (!current.remove(label)) return;
    customSources.value = List.unmodifiable(current);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_customSourcesKey, current);
    try {
      await _settingsDoc.set(
        {'customSources': current},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static Future<void> setHidePrices(bool hide) async {
    hidePrices.value = hide;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hidePricesKey, hide);
    try {
      await _settingsDoc.set({'hidePrices': hide}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> resetToDefaults() async {
    await setVisible(CaveColumn.defaults);
  }

  static Future<void> setDrunkVisible(Set<DrunkColumn> v) async {
    final withEssentials = {...v, ...DrunkColumn.essentials};
    drunkVisible.value = withEssentials;

    final ids = withEssentials.map((c) => c.name).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_drunkKey, ids);

    try {
      await _settingsDoc.set(
        {'drunkColumns': ids},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static Future<void> resetDrunkToDefaults() async {
    await setDrunkVisible(DrunkColumn.defaults);
  }

  static Future<void> setWishVisible(Set<WishColumn> v) async {
    final withEssentials = {...v, ...WishColumn.essentials};
    wishVisible.value = withEssentials;

    final ids = withEssentials.map((c) => c.name).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_wishKey, ids);

    try {
      await _settingsDoc.set(
        {'wishColumns': ids},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static Future<void> resetWishToDefaults() async {
    await setWishVisible(WishColumn.defaults);
  }

  static Future<void> setCellarZoom(int zoom) async {
    final v = zoom.clamp(1, 10);
    cellarZoom.value = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_zoomKey, v);
    try {
      await _settingsDoc.set({'cellarZoom': v}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Set<CaveColumn> _decode(List<String> ids) {
    final byName = {for (final c in CaveColumn.values) c.name: c};
    final out = <CaveColumn>{};
    for (final id in ids) {
      final col = byName[id];
      if (col != null) out.add(col);
    }
    out.addAll(CaveColumn.essentials);
    return out;
  }

  static Set<DrunkColumn> _decodeDrunk(List<String> ids) {
    final byName = {for (final c in DrunkColumn.values) c.name: c};
    final out = <DrunkColumn>{};
    for (final id in ids) {
      final col = byName[id];
      if (col != null) out.add(col);
    }
    out.addAll(DrunkColumn.essentials);
    return out;
  }

  static Future<void> setStatsOrder(List<StatItem> order) async {
    statsOrder.value = order;
    final ids = order.map((s) => s.name).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_statsOrderKey, ids);
    try {
      await _settingsDoc.set({'statsOrder': ids}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> setStatsLayout(List<List<StatItem>> layout) async {
    statsLayout.value = layout;
    final encoded = _encodeLayout(layout);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_statsLayoutKey, encoded);
    try {
      await _settingsDoc.set({'statsLayout': encoded}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> setStatsHidePrices(bool hide) async {
    statsHidePrices.value = hide;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_statsHidePricesKey, hide);
    try {
      await _settingsDoc.set({'statsHidePrices': hide}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> setStatsChartType(StatItem item, StatChartType type) async {
    final map = Map<StatItem, StatChartType>.from(statsChartTypes.value);
    if (type == item.chartType) {
      map.remove(item);
    } else {
      map[item] = type;
    }
    statsChartTypes.value = map;
    final encoded = _encodeChartTypes(map);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_statsChartTypesKey, encoded);
    try {
      await _settingsDoc.set({'statsChartTypes': encoded}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> resetStatsToDefaults() async {
    await setStatsOrder(StatItem.defaultOrder);
    await setStatsLayout(StatItem.defaultLayout);
    await setStatsHidePrices(false);
    statsChartTypes.value = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsChartTypesKey);
    try {
      await _settingsDoc.set({'statsChartTypes': FieldValue.delete()}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> setAutoRefreshEnabled(bool enabled) async {
    autoRefreshEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoRefreshEnabledKey, enabled);
    try {
      await _settingsDoc.set({'autoRefreshEnabled': enabled}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> setAutoRefreshPercent(int percent) async {
    autoRefreshPercent.value = percent;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoRefreshPercentKey, percent);
    try {
      await _settingsDoc.set({'autoRefreshRatePercent': percent}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> setAutoRefreshPeriod(String period) async {
    autoRefreshPeriod.value = period;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_autoRefreshPeriodKey, period);
    try {
      await _settingsDoc.set({'autoRefreshRatePeriod': period}, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> setLastAutoRefreshRun(DateTime dt) async {
    lastAutoRefreshRun.value = dt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAutoRefreshRunKey, dt.toIso8601String());
    try {
      await _settingsDoc.set({'lastAutoRefreshRun': Timestamp.fromDate(dt)}, SetOptions(merge: true));
    } catch (_) {}
  }

  static List<StatItem> _decodeStats(List<String> ids) {
    final byName = {for (final s in StatItem.values) s.name: s};
    final out = <StatItem>[];
    for (final id in ids) {
      final item = byName[id];
      if (item != null) out.add(item);
    }
    for (final s in StatItem.defaultOrder) {
      if (!out.contains(s)) out.add(s);
    }
    return out;
  }

  static Set<WishColumn> _decodeWish(List<String> ids) {
    final byName = {for (final c in WishColumn.values) c.name: c};
    final out = <WishColumn>{};
    for (final id in ids) {
      final col = byName[id];
      if (col != null) out.add(col);
    }
    out.addAll(WishColumn.essentials);
    return out;
  }

  // Layout is stored as list of strings: "item1,item2" per row
  static List<String> _encodeLayout(List<List<StatItem>> layout) {
    return layout.map((row) => row.map((s) => s.name).join(',')).toList();
  }

  static List<List<StatItem>> _decodeLayout(List<String> encoded) {
    final byName = {for (final s in StatItem.values) s.name: s};
    final out = <List<StatItem>>[];
    for (final row in encoded) {
      final items = <StatItem>[];
      for (final name in row.split(',')) {
        final item = byName[name.trim()];
        if (item != null) items.add(item);
      }
      if (items.isNotEmpty) out.add(items);
    }
    // Add any missing items
    final present = out.expand((r) => r).toSet();
    for (final s in StatItem.defaultOrder) {
      if (!present.contains(s)) out.add([s]);
    }
    return out;
  }

  // Chart type overrides stored as "itemName:typeName" pairs
  static List<String> _encodeChartTypes(Map<StatItem, StatChartType> map) {
    return map.entries.map((e) => '${e.key.name}:${e.value.name}').toList();
  }

  static Map<StatItem, StatChartType> _decodeChartTypes(List<String> encoded) {
    final itemByName = {for (final s in StatItem.values) s.name: s};
    final typeByName = {for (final t in StatChartType.values) t.name: t};
    final out = <StatItem, StatChartType>{};
    for (final entry in encoded) {
      final parts = entry.split(':');
      if (parts.length != 2) continue;
      final item = itemByName[parts[0]];
      final type = typeByName[parts[1]];
      if (item != null && type != null) out[item] = type;
    }
    return out;
  }
}
