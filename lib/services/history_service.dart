import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bottle.dart';
import '../models/wine.dart';

enum HistoryActionType {
  bottleDeleted('Bouteille supprimée'),
  bottleDrunk('Bouteille bue'),
  wineDeleted('Vin supprimé');

  final String label;
  const HistoryActionType(this.label);

  static HistoryActionType fromName(String? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return HistoryActionType.bottleDeleted;
  }
}

class HistoryEntry {
  final String id;
  final HistoryActionType type;
  final DateTime timestamp;
  final bool undone;
  final String wineLabel;
  final String? bottleLocation;
  final Map<String, dynamic> payload;

  HistoryEntry({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.undone,
    required this.wineLabel,
    required this.bottleLocation,
    required this.payload,
  });

  factory HistoryEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ts = data['timestamp'];
    return HistoryEntry(
      id: doc.id,
      type: HistoryActionType.fromName(data['type'] as String?),
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
      undone: data['undone'] == true,
      wineLabel: (data['wineLabel'] as String?) ?? '',
      bottleLocation: data['bottleLocation'] as String?,
      payload: Map<String, dynamic>.from(data['payload'] ?? const {}),
    );
  }
}

class HistoryService {
  static final _db = FirebaseFirestore.instance;
  static final _history = _db.collection('history');
  static final _wines = _db.collection('wines');
  static final _bottles = _db.collection('bottles');

  static String _wineLabel(Wine? w) {
    if (w == null) return '(vin inconnu)';
    final v = w.vintage != null ? ' ${w.vintage}' : '';
    return '${w.name}$v';
  }

  static Future<void> logBottleDeleted({
    required Bottle bottle,
    required Wine? wine,
  }) async {
    await _history.add({
      'type': HistoryActionType.bottleDeleted.name,
      'timestamp': FieldValue.serverTimestamp(),
      'undone': false,
      'wineLabel': _wineLabel(wine),
      'bottleLocation': bottle.location,
      'payload': {
        'bottleId': bottle.id,
        'bottleData': bottle.toMap(),
      },
    });
  }

  static Future<void> logBottleDrunk({
    required Bottle previousBottle,
    required Wine? wine,
  }) async {
    await _history.add({
      'type': HistoryActionType.bottleDrunk.name,
      'timestamp': FieldValue.serverTimestamp(),
      'undone': false,
      'wineLabel': _wineLabel(wine),
      'bottleLocation': previousBottle.location,
      'payload': {
        'bottleId': previousBottle.id,
        'bottleData': previousBottle.toMap(),
      },
    });
  }

  static Future<void> logWineDeleted({
    required Wine wine,
    required List<Bottle> bottles,
  }) async {
    await _history.add({
      'type': HistoryActionType.wineDeleted.name,
      'timestamp': FieldValue.serverTimestamp(),
      'undone': false,
      'wineLabel': _wineLabel(wine),
      'bottleLocation': null,
      'payload': {
        'wineId': wine.id,
        'wineData': wine.toMap(),
        'bottles': bottles
            .map((b) => {'id': b.id, 'data': b.toMap()})
            .toList(),
      },
    });
  }

  static Stream<List<HistoryEntry>> recent({int limit = 50}) {
    return _history
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(HistoryEntry.fromDoc).toList());
  }

  /// Tries to undo the action. Returns null if successful, or an error message.
  static Future<String?> undo(HistoryEntry entry) async {
    if (entry.undone) return 'Action déjà annulée.';
    try {
      switch (entry.type) {
        case HistoryActionType.bottleDeleted:
        case HistoryActionType.bottleDrunk:
          final id = entry.payload['bottleId'] as String?;
          final data = entry.payload['bottleData'] as Map?;
          if (id == null || data == null) {
            return 'Données incomplètes.';
          }
          final restored = Map<String, dynamic>.from(data);
          if (entry.type == HistoryActionType.bottleDrunk) {
            restored['status'] = BottleStatus.inCave.name;
            restored['drunkAt'] = null;
            restored['drunkRating'] = null;
            restored['drunkNote'] = null;
            restored['drunkLocation'] = null;
          }
          // If slot is now occupied, restore as unplaced.
          final cellarId = restored['cellarId'];
          final col = restored['slotCol'];
          final row = restored['slotRow'];
          if (cellarId is String && col is num && row is num) {
            final taken = await _bottles
                .where('cellarId', isEqualTo: cellarId)
                .where('slotCol', isEqualTo: col)
                .where('slotRow', isEqualTo: row)
                .where('status', isEqualTo: BottleStatus.inCave.name)
                .get();
            if (taken.docs.any((d) => d.id != id)) {
              restored['cellarId'] = null;
              restored['slotCol'] = null;
              restored['slotRow'] = null;
              restored['location'] = '';
            }
          }
          await _bottles.doc(id).set(restored);
          break;
        case HistoryActionType.wineDeleted:
          final wineId = entry.payload['wineId'] as String?;
          final wineData = entry.payload['wineData'] as Map?;
          final bottlesList = entry.payload['bottles'] as List?;
          if (wineId == null || wineData == null) {
            return 'Données incomplètes.';
          }
          await _wines.doc(wineId).set(Map<String, dynamic>.from(wineData));
          if (bottlesList != null) {
            for (final raw in bottlesList) {
              if (raw is! Map) continue;
              final id = raw['id'] as String?;
              final data = raw['data'];
              if (id == null || data is! Map) continue;
              final restored = Map<String, dynamic>.from(data);
              final cellarId = restored['cellarId'];
              final col = restored['slotCol'];
              final row = restored['slotRow'];
              if (cellarId is String && col is num && row is num) {
                final taken = await _bottles
                    .where('cellarId', isEqualTo: cellarId)
                    .where('slotCol', isEqualTo: col)
                    .where('slotRow', isEqualTo: row)
                    .where('status', isEqualTo: BottleStatus.inCave.name)
                    .get();
                if (taken.docs.any((d) => d.id != id)) {
                  restored['cellarId'] = null;
                  restored['slotCol'] = null;
                  restored['slotRow'] = null;
                  restored['location'] = '';
                }
              }
              await _bottles.doc(id).set(restored);
            }
          }
          break;
      }
      await _history.doc(entry.id).update({'undone': true});
      return null;
    } catch (e) {
      return 'Erreur : $e';
    }
  }

  static Future<void> clear() async {
    final snap = await _history.get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
