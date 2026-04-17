import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/wine.dart';
import '../models/bottle.dart';

class CaveService {
  static final _db = FirebaseFirestore.instance;
  static final _wines = _db.collection('wines');
  static final _bottles = _db.collection('bottles');

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
        .orderBy('drunkAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Bottle.fromDoc).toList());
  }

  static Future<bool> isLocationTaken(String location) async {
    final snap = await _bottles
        .where('location', isEqualTo: location)
        .where('status', isEqualTo: BottleStatus.inCave.name)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
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

  static Future<void> markBottleDrunk({
    required String bottleId,
    required DateTime drunkAt,
    int? rating,
    String? note,
  }) async {
    await _bottles.doc(bottleId).update({
      'status': BottleStatus.drunk.name,
      'drunkAt': Timestamp.fromDate(drunkAt),
      'drunkRating': rating,
      'drunkNote': note,
    });
  }

  static Future<void> deleteBottle(String id) => _bottles.doc(id).delete();
  static Future<void> deleteWine(String id) => _wines.doc(id).delete();
}
