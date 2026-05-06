import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cellar.dart';

class CellarService {
  static final _db = FirebaseFirestore.instance;
  static final _cellars = _db.collection('cellars');

  static Stream<List<Cellar>> watch() {
    return _cellars.orderBy('number').snapshots().map(
          (snap) => snap.docs.map(Cellar.fromDoc).toList(),
        );
  }

  static Future<int> nextNumber() async {
    final snap = await _cellars.orderBy('number', descending: true).limit(1).get();
    if (snap.docs.isEmpty) return 1;
    final n = (snap.docs.first.data()['number'] as num?)?.toInt() ?? 0;
    return n + 1;
  }

  static Future<bool> isNumberTaken(int number, {String? exceptId}) async {
    final snap = await _cellars.where('number', isEqualTo: number).get();
    return snap.docs.any((d) => d.id != exceptId);
  }

  static Future<Cellar?> findByNumber(int number) async {
    final snap =
        await _cellars.where('number', isEqualTo: number).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return Cellar.fromDoc(snap.docs.first);
  }

  static Future<String> add({
    required int number,
    required String name,
    required int cols,
    required int rows,
    String? goveeTopDevice,
    String? goveeBottomDevice,
    String? tuyaDeviceId,
  }) async {
    final ref = await _cellars.add({
      'number': number,
      'name': name,
      'cols': cols,
      'rows': rows,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      if (goveeTopDevice != null && goveeTopDevice.isNotEmpty)
        'goveeTopDevice': goveeTopDevice,
      if (goveeBottomDevice != null && goveeBottomDevice.isNotEmpty)
        'goveeBottomDevice': goveeBottomDevice,
      if (tuyaDeviceId != null && tuyaDeviceId.isNotEmpty)
        'tuyaDeviceId': tuyaDeviceId,
    });
    return ref.id;
  }

  static Future<void> update(
    String id, {
    int? number,
    String? name,
    int? cols,
    int? rows,
    String? goveeTopDevice,
    String? goveeBottomDevice,
    String? tuyaDeviceId,
    bool clearGoveeTop = false,
    bool clearGoveeBottom = false,
    bool clearTuyaDeviceId = false,
  }) {
    final data = <String, dynamic>{};
    if (number != null) data['number'] = number;
    if (name != null) data['name'] = name;
    if (cols != null) data['cols'] = cols;
    if (rows != null) data['rows'] = rows;
    if (goveeTopDevice != null && goveeTopDevice.isNotEmpty) {
      data['goveeTopDevice'] = goveeTopDevice;
    } else if (clearGoveeTop) {
      data['goveeTopDevice'] = FieldValue.delete();
    }
    if (goveeBottomDevice != null && goveeBottomDevice.isNotEmpty) {
      data['goveeBottomDevice'] = goveeBottomDevice;
    } else if (clearGoveeBottom) {
      data['goveeBottomDevice'] = FieldValue.delete();
    }
    if (tuyaDeviceId != null && tuyaDeviceId.isNotEmpty) {
      data['tuyaDeviceId'] = tuyaDeviceId;
    } else if (clearTuyaDeviceId) {
      data['tuyaDeviceId'] = FieldValue.delete();
    }
    return _cellars.doc(id).update(data);
  }

  static Future<void> delete(String id) => _cellars.doc(id).delete();
}
