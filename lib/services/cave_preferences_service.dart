import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    final hidePrices = prefs.getBool(_statsHidePricesKey);
    if (hidePrices != null) statsHidePrices.value = hidePrices;

    final chartTypesLocal = prefs.getStringList(_statsChartTypesKey);
    if (chartTypesLocal != null) {
      statsChartTypes.value = _decodeChartTypes(chartTypesLocal);
    }

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

      final remoteHidePrices = snap.data()?['statsHidePrices'] as bool?;
      if (remoteHidePrices != null) {
        statsHidePrices.value = remoteHidePrices;
        await prefs.setBool(_statsHidePricesKey, remoteHidePrices);
      } else if (hidePrices != null) {
        await _settingsDoc.set(
          {'statsHidePrices': hidePrices},
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
    } catch (_) {}
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
