import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wine.dart';
import '../models/bottle.dart' show Bottle, BottleFormat, BottleStatus, formatFullSlotLabel;
import 'history_service.dart';

class CaveService {
  static final _db = FirebaseFirestore.instance;
  static final _wines = _db.collection('wines');
  static final _bottles = _db.collection('bottles');

  static Stream<Wine?> wine(String id) {
    return _wines.doc(id).snapshots().map(
          (snap) => snap.exists ? Wine.fromDoc(snap) : null,
        );
  }

  static Stream<List<Wine>> wines() {
    return _wines.orderBy('createdAt', descending: true).snapshots().map(
          (snap) => snap.docs.map(Wine.fromDoc).toList(),
        );
  }

  static Stream<List<Bottle>> bottlesInCave() {
    return _bottles
        .where('status', isEqualTo: BottleStatus.inCave.name)
        .snapshots()
        .map((snap) => snap.docs.map(Bottle.fromDoc).toList());
  }

  static Stream<List<Bottle>> bottlesDrunk() {
    return _bottles
        .where('status', isEqualTo: BottleStatus.drunk.name)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map(Bottle.fromDoc).toList();
          list.sort((a, b) => (b.drunkAt ?? b.createdAt).compareTo(a.drunkAt ?? a.createdAt));
          return list;
        });
  }

  static Future<bool> isLocationTaken(
    String location, {
    String? exceptBottleId,
  }) async {
    final snap = await _bottles
        .where('location', isEqualTo: location)
        .where('status', isEqualTo: BottleStatus.inCave.name)
        .get();
    return snap.docs.any((d) => d.id != exceptBottleId);
  }

  static Future<bool> isSlotTaken({
    required String cellarId,
    required int slotCol,
    required int slotRow,
    String? exceptBottleId,
  }) async {
    final snap = await _bottles
        .where('cellarId', isEqualTo: cellarId)
        .where('slotCol', isEqualTo: slotCol)
        .where('slotRow', isEqualTo: slotRow)
        .where('status', isEqualTo: BottleStatus.inCave.name)
        .get();
    return snap.docs.any((d) => d.id != exceptBottleId);
  }

  static Stream<List<Bottle>> bottlesByWine(String wineId) {
    return _bottles
        .where('wineId', isEqualTo: wineId)
        .snapshots()
        .map((snap) => snap.docs.map(Bottle.fromDoc).toList());
  }

  static Stream<List<Bottle>> bottlesByCellar(String cellarId) {
    return _bottles
        .where('cellarId', isEqualTo: cellarId)
        .where('status', isEqualTo: BottleStatus.inCave.name)
        .snapshots()
        .map((snap) => snap.docs.map(Bottle.fromDoc).toList());
  }

  static Stream<List<Bottle>> unplacedBottlesInCave() {
    return bottlesInCave().map(
      (list) => list
          .where((b) => b.cellarId == null || b.cellarId!.isEmpty)
          .toList(),
    );
  }

  static Future<void> assignSlot({
    required String bottleId,
    required String cellarId,
    required int cellarNumber,
    required int col,
    required int row,
  }) {
    return _bottles.doc(bottleId).update({
      'cellarId': cellarId,
      'slotCol': col,
      'slotRow': row,
      'location': formatFullSlotLabel(cellarNumber, row, col),
    });
  }

  static Future<void> unassignSlot(String bottleId) {
    return _bottles.doc(bottleId).update({
      'cellarId': null,
      'slotCol': null,
      'slotRow': null,
      'location': '',
    });
  }

  static Future<void> swapSlots({
    required Bottle a,
    required Bottle b,
    required int cellarNumber,
  }) {
    final batch = _db.batch();
    batch.update(_bottles.doc(a.id), {
      'cellarId': b.cellarId,
      'slotCol': b.slotCol,
      'slotRow': b.slotRow,
      'location': formatFullSlotLabel(cellarNumber, b.slotRow!, b.slotCol!),
    });
    batch.update(_bottles.doc(b.id), {
      'cellarId': a.cellarId,
      'slotCol': a.slotCol,
      'slotRow': a.slotRow,
      'location': formatFullSlotLabel(cellarNumber, a.slotRow!, a.slotCol!),
    });
    return batch.commit();
  }

  static Future<String> addWineWithBottles({
    required Wine wine,
    required List<Bottle> bottles,
  }) async {
    final wineRef = await _wines.add(wine.toMap());
    final batch = _db.batch();
    for (final b in bottles) {
      final bRef = _bottles.doc();
      final map = b.toMap();
      map['wineId'] = wineRef.id;
      batch.set(bRef, map);
    }
    await batch.commit();
    return wineRef.id;
  }

  static Future<void> addBottlesToWine({
    required String wineId,
    required List<Bottle> bottles,
  }) async {
    final batch = _db.batch();
    for (final b in bottles) {
      final ref = _bottles.doc();
      final map = b.toMap();
      map['wineId'] = wineId;
      batch.set(ref, map);
    }
    await batch.commit();
  }

  static Future<void> markBottleDrunk({
    required String bottleId,
    required DateTime drunkAt,
    int? rating,
    String? note,
    String? location,
  }) async {
    final snap = await _bottles.doc(bottleId).get();
    if (snap.exists) {
      try {
        final previous = Bottle.fromDoc(snap);
        final wineSnap = await _wines.doc(previous.wineId).get();
        final wine = wineSnap.exists ? Wine.fromDoc(wineSnap) : null;
        await HistoryService.logBottleDrunk(
          previousBottle: previous,
          wine: wine,
        );
      } catch (_) {}
    }
    await _bottles.doc(bottleId).update({
      'status': BottleStatus.drunk.name,
      'drunkAt': Timestamp.fromDate(drunkAt),
      'drunkRating': rating,
      'drunkNote': note,
      'drunkLocation': location,
      'cellarId': null,
      'slotCol': null,
      'slotRow': null,
    });
  }

  static Future<void> updateBottle(
    String id,
    Map<String, dynamic> data,
  ) =>
      _bottles.doc(id).update(data);

  static Future<void> updateWine(String id, Map<String, dynamic> data) =>
      _wines.doc(id).update(data);

  static Future<void> deleteBottle(String id) async {
    final snap = await _bottles.doc(id).get();
    if (snap.exists) {
      try {
        final bottle = Bottle.fromDoc(snap);
        final wineSnap = await _wines.doc(bottle.wineId).get();
        final wine = wineSnap.exists ? Wine.fromDoc(wineSnap) : null;
        await HistoryService.logBottleDeleted(bottle: bottle, wine: wine);
      } catch (_) {}
    }
    await _bottles.doc(id).delete();
  }

  static Future<void> deleteWine(String id) async {
    final wineSnap = await _wines.doc(id).get();
    if (wineSnap.exists) {
      try {
        final wine = Wine.fromDoc(wineSnap);
        final bottlesSnap =
            await _bottles.where('wineId', isEqualTo: id).get();
        final bottles = bottlesSnap.docs.map(Bottle.fromDoc).toList();
        await HistoryService.logWineDeleted(wine: wine, bottles: bottles);
      } catch (_) {}
    }
    final bottlesSnap = await _bottles.where('wineId', isEqualTo: id).get();
    final batch = _db.batch();
    for (final doc in bottlesSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_wines.doc(id));
    await batch.commit();
  }

  // Clone a wine document (same metadata) and attach new bottles to it.
  static Future<String> cloneWineWithBottles({
    required Wine sourceWine,
    required List<Bottle> bottles,
  }) async {
    final cloneMap = sourceWine.toMap();
    cloneMap['createdAt'] = Timestamp.fromDate(DateTime.now());
    final wineRef = await _wines.add(cloneMap);
    final batch = _db.batch();
    for (final b in bottles) {
      final bRef = _bottles.doc();
      final map = b.toMap();
      map['wineId'] = wineRef.id;
      batch.set(bRef, map);
    }
    await batch.commit();
    return wineRef.id;
  }

  // One-time migration: for each Wine that has bottles of multiple formats,
  // split into separate Wine documents (one per format).
  static Future<void> splitMixedFormatWines() async {
    final winesSnap = await _wines.get();
    final bottlesSnap = await _bottles
        .where('status', isEqualTo: BottleStatus.inCave.name)
        .get();
    final allBottles = bottlesSnap.docs.map(Bottle.fromDoc).toList();

    for (final wineDoc in winesSnap.docs) {
      final wine = Wine.fromDoc(wineDoc);
      final wineBottles = allBottles.where((b) => b.wineId == wine.id).toList();

      final byFormat = <BottleFormat, List<Bottle>>{};
      for (final b in wineBottles) {
        byFormat.putIfAbsent(b.format, () => []).add(b);
      }
      if (byFormat.length <= 1) continue;

      // Keep the format with the most bottles as primary (stays on original Wine).
      final primaryFormat = byFormat.entries
          .reduce((a, b) => a.value.length >= b.value.length ? a : b)
          .key;

      for (final entry in byFormat.entries) {
        if (entry.key == primaryFormat) continue;

        final cloneMap = wine.toMap();
        cloneMap['createdAt'] = Timestamp.fromDate(DateTime.now());
        final newWineRef = await _wines.add(cloneMap);

        final batch = _db.batch();
        for (final bottle in entry.value) {
          batch.update(_bottles.doc(bottle.id), {'wineId': newWineRef.id});
        }
        await batch.commit();
      }
    }
  }
}
