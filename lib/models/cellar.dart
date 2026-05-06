import 'package:cloud_firestore/cloud_firestore.dart';

class Cellar {
  final String id;
  final int number;
  final String name;
  final int cols;
  final int rows;
  final DateTime createdAt;
  final String? goveeTopDevice;
  final String? goveeBottomDevice;
  final String? tuyaDeviceId;
  final String? tuyaLocalKey;
  final String? tuyaIp;
  final String? tuyaVersion;

  const Cellar({
    required this.id,
    required this.number,
    this.name = '',
    required this.cols,
    required this.rows,
    required this.createdAt,
    this.goveeTopDevice,
    this.goveeBottomDevice,
    this.tuyaDeviceId,
    this.tuyaLocalKey,
    this.tuyaIp,
    this.tuyaVersion,
  });

  int get totalSlots => cols * rows;

  Map<String, dynamic> toMap() => {
        'number': number,
        'name': name,
        'cols': cols,
        'rows': rows,
        'createdAt': Timestamp.fromDate(createdAt),
        if (goveeTopDevice != null) 'goveeTopDevice': goveeTopDevice,
        if (goveeBottomDevice != null) 'goveeBottomDevice': goveeBottomDevice,
        if (tuyaDeviceId != null) 'tuyaDeviceId': tuyaDeviceId,
        if (tuyaLocalKey != null) 'tuyaLocalKey': tuyaLocalKey,
        if (tuyaIp != null) 'tuyaIp': tuyaIp,
        if (tuyaVersion != null) 'tuyaVersion': tuyaVersion,
      };

  factory Cellar.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Cellar(
      id: doc.id,
      number: (data['number'] as num?)?.toInt() ?? 0,
      name: data['name'] ?? '',
      cols: (data['cols'] as num?)?.toInt() ?? 10,
      rows: (data['rows'] as num?)?.toInt() ?? 20,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      goveeTopDevice: data['goveeTopDevice'] as String?,
      goveeBottomDevice: data['goveeBottomDevice'] as String?,
      tuyaDeviceId: data['tuyaDeviceId'] as String?,
      tuyaLocalKey: data['tuyaLocalKey'] as String?,
      tuyaIp: data['tuyaIp'] as String?,
      tuyaVersion: data['tuyaVersion'] as String?,
    );
  }
}
