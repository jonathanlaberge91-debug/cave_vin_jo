import 'package:cloud_firestore/cloud_firestore.dart';

class MarketHistoryEntry {
  final String id;
  final double value;
  final DateTime timestamp;
  final String source;

  const MarketHistoryEntry({
    required this.id,
    required this.value,
    required this.timestamp,
    required this.source,
  });

  factory MarketHistoryEntry.fromDoc(DocumentSnapshot doc) {
    final d = doc.data()! as Map<String, dynamic>;
    return MarketHistoryEntry(
      id: doc.id,
      value: (d['value'] as num).toDouble(),
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      source: d['source'] ?? 'gemini',
    );
  }

  Map<String, dynamic> toMap() => {
    'value': value,
    'timestamp': Timestamp.fromDate(timestamp),
    'source': source,
  };
}
