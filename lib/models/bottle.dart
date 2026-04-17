import 'package:cloud_firestore/cloud_firestore.dart';

enum BottleStatus { inCave, drunk }

enum BottleFormat {
  ml375('375 ML'),
  ml750('750 ML'),
  ml1500('1500 ML'),
  ml3000('3000 ML'),
  ml6000('6000 ML');

  final String label;
  const BottleFormat(this.label);

  static BottleFormat fromLabel(String? label) =>
      values.firstWhere((f) => f.label == label, orElse: () => ml750);
}

enum BottleSource {
  saq('SAQ'),
  importationPrivee('Importation privée'),
  cadeau('Cadeau'),
  particulier('Particulier'),
  autre('Autre');

  final String label;
  const BottleSource(this.label);

  static BottleSource? fromLabel(String? label) {
    if (label == null) return null;
    for (final s in values) {
      if (s.label == label) return s;
    }
    return null;
  }
}

class Bottle {
  final String id;
  final String wineId;
  final String location;
  final BottleFormat format;
  final double? purchasePrice;
  final double? marketValue;
  final int? purchaseYear;
  final BottleSource? source;
  final BottleStatus status;
  final bool isGift;
  final String giftFrom;
  final String giftOccasion;
  final DateTime? giftDate;
  final DateTime? drunkAt;
  final int? drunkRating;
  final String? drunkNote;
  final DateTime createdAt;

  Bottle({
    required this.id,
    required this.wineId,
    required this.location,
    this.format = BottleFormat.ml750,
    this.purchasePrice,
    this.marketValue,
    this.purchaseYear,
    this.source,
    this.status = BottleStatus.inCave,
    this.isGift = false,
    this.giftFrom = '',
    this.giftOccasion = '',
    this.giftDate,
    this.drunkAt,
    this.drunkRating,
    this.drunkNote,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'wineId': wineId,
        'location': location,
        'format': format.label,
        'purchasePrice': purchasePrice,
        'marketValue': marketValue,
        'purchaseYear': purchaseYear,
        'source': source?.label,
        'status': status.name,
        'isGift': isGift,
        'giftFrom': giftFrom,
        'giftOccasion': giftOccasion,
        'giftDate': giftDate != null ? Timestamp.fromDate(giftDate!) : null,
        'drunkAt': drunkAt != null ? Timestamp.fromDate(drunkAt!) : null,
        'drunkRating': drunkRating,
        'drunkNote': drunkNote,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Bottle.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Bottle(
      id: doc.id,
      wineId: data['wineId'] ?? '',
      location: data['location'] ?? '',
      format: BottleFormat.fromLabel(data['format']),
      purchasePrice: (data['purchasePrice'] as num?)?.toDouble(),
      marketValue: (data['marketValue'] as num?)?.toDouble(),
      purchaseYear: data['purchaseYear'],
      source: BottleSource.fromLabel(data['source']),
      status: BottleStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => BottleStatus.inCave,
      ),
      isGift: data['isGift'] ?? false,
      giftFrom: data['giftFrom'] ?? '',
      giftOccasion: data['giftOccasion'] ?? '',
      giftDate: (data['giftDate'] as Timestamp?)?.toDate(),
      drunkAt: (data['drunkAt'] as Timestamp?)?.toDate(),
      drunkRating: data['drunkRating'],
      drunkNote: data['drunkNote'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
