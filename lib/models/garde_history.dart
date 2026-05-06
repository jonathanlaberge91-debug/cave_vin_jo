import 'package:cloud_firestore/cloud_firestore.dart';

class GardeHistoryEntry {
  final String id;
  final int? drinkFrom;
  final int? drinkPeak;
  final int? drinkTo;
  final DateTime timestamp;
  final String source;

  const GardeHistoryEntry({
    required this.id,
    this.drinkFrom,
    this.drinkPeak,
    this.drinkTo,
    required this.timestamp,
    required this.source,
  });

  factory GardeHistoryEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return GardeHistoryEntry(
      id: doc.id,
      drinkFrom: d['drinkFrom'] as int?,
      drinkPeak: d['drinkPeak'] as int?,
      drinkTo: d['drinkTo'] as int?,
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      source: d['source'] ?? 'gemini',
    );
  }

  Map<String, dynamic> toMap() => {
    'drinkFrom': drinkFrom,
    'drinkPeak': drinkPeak,
    'drinkTo': drinkTo,
    'timestamp': Timestamp.fromDate(timestamp),
    'source': source,
  };
}
