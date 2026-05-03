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

  int get slotSpan {
    switch (this) {
      case ml1500:
        return 2;
      case ml3000:
      case ml6000:
        return 4;
      default:
        return 1;
    }
  }

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
  final String? cellarId;
  final int? slotCol;
  final int? slotRow;
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
  final String? drunkLocation;
  final DateTime createdAt;

  Bottle({
    required this.id,
    required this.wineId,
    required this.location,
    this.cellarId,
    this.slotCol,
    this.slotRow,
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
    this.drunkLocation,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'wineId': wineId,
        'location': location,
        'cellarId': cellarId,
        'slotCol': slotCol,
        'slotRow': slotRow,
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
        'drunkLocation': drunkLocation,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Bottle.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Bottle(
      id: doc.id,
      wineId: data['wineId'] ?? '',
      location: data['location'] ?? '',
      cellarId: data['cellarId'],
      slotCol: (data['slotCol'] as num?)?.toInt(),
      slotRow: (data['slotRow'] as num?)?.toInt(),
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
      drunkLocation: data['drunkLocation'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

String formatRowLetter(int row) {
  if (row < 26) return String.fromCharCode(65 + row);
  final first = (row ~/ 26) - 1;
  final second = row % 26;
  return '${String.fromCharCode(65 + first)}${String.fromCharCode(65 + second)}';
}

String formatSlotLabel(int row, int col) =>
    '${formatRowLetter(row)}${col + 1}';

String formatFullSlotLabel(int cellarNumber, int row, int col) =>
    'C$cellarNumber-${formatSlotLabel(row, col)}';

class ParsedSlot {
  final int cellarNumber;
  final int rowIndex;
  final int colIndex;
  const ParsedSlot({
    required this.cellarNumber,
    required this.rowIndex,
    required this.colIndex,
  });
}

ParsedSlot? parseSlotLabel(String input) {
  final cleaned = input.trim().toUpperCase();
  final m = RegExp(r'^C(\d+)-([A-Z]+)(\d+)$').firstMatch(cleaned);
  if (m == null) return null;
  final cellarN = int.tryParse(m.group(1)!);
  final col = int.tryParse(m.group(3)!);
  if (cellarN == null || col == null || col < 1) return null;
  final letters = m.group(2)!;
  int rowIndex;
  if (letters.length == 1) {
    rowIndex = letters.codeUnitAt(0) - 65;
  } else if (letters.length == 2) {
    final first = letters.codeUnitAt(0) - 65;
    final second = letters.codeUnitAt(1) - 65;
    rowIndex = (first + 1) * 26 + second;
  } else {
    return null;
  }
  return ParsedSlot(
    cellarNumber: cellarN,
    rowIndex: rowIndex,
    colIndex: col - 1,
  );
}
