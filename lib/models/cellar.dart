import 'package:cloud_firestore/cloud_firestore.dart';

class Cellar {
  final String id;
  final int number;
  final String name;
  final int cols;
  final int rows;
  final DateTime createdAt;

  const Cellar({
    required this.id,
    required this.number,
    this.name = '',
    required this.cols,
    required this.rows,
    required this.createdAt,
  });

  int get totalSlots => cols * rows;

  Map<String, dynamic> toMap() => {
        'number': number,
        'name': name,
        'cols': cols,
        'rows': rows,
        'createdAt': Timestamp.fromDate(createdAt),
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
    );
  }
}
