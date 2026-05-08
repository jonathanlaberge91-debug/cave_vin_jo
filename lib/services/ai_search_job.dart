import 'dart:typed_data';
import '../models/bottle.dart';
import 'ai_cross_check.dart';

enum AiSearchJobType { photo, text }

enum AiSearchJobStatus { queued, running, success, failed }

/// Données partielles d'une bouteille saisies AVANT lancement de la recherche.
/// L'utilisateur peut compléter au moment de l'enregistrement.
class WineDraftData {
  final BottleFormat format;
  final int quantity;
  final double? purchasePrice;
  final int? purchaseYear;
  final String? source;
  final bool isGift;
  final String giftFrom;
  final String giftOccasion;
  final DateTime? giftDate;

  WineDraftData({
    this.format = BottleFormat.ml750,
    this.quantity = 1,
    this.purchasePrice,
    this.purchaseYear,
    this.source,
    this.isGift = false,
    this.giftFrom = '',
    this.giftOccasion = '',
    this.giftDate,
  });

  Map<String, dynamic> toJson() => {
        'format': format.name,
        'quantity': quantity,
        'purchasePrice': purchasePrice,
        'purchaseYear': purchaseYear,
        'source': source,
        'isGift': isGift,
        'giftFrom': giftFrom,
        'giftOccasion': giftOccasion,
        'giftDate': giftDate?.toIso8601String(),
      };

  factory WineDraftData.fromJson(Map<String, dynamic> j) {
    BottleFormat parseFormat(dynamic v) {
      if (v is String) {
        for (final f in BottleFormat.values) {
          if (f.name == v) return f;
        }
      }
      return BottleFormat.ml750;
    }

    return WineDraftData(
      format: parseFormat(j['format']),
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      purchasePrice: (j['purchasePrice'] as num?)?.toDouble(),
      purchaseYear: (j['purchaseYear'] as num?)?.toInt(),
      source: j['source'] as String?,
      isGift: j['isGift'] == true,
      giftFrom: j['giftFrom'] ?? '',
      giftOccasion: j['giftOccasion'] ?? '',
      giftDate: j['giftDate'] is String
          ? DateTime.tryParse(j['giftDate'])
          : null,
    );
  }
}

class AiSearchJob {
  final String id;
  final DateTime createdAt;
  final AiSearchJobType type;

  // Pour les jobs photo : bytes en mémoire + clé persistée dans IndexedDB
  Uint8List? photoBytes;
  String? photoBlobKey; // clé du blob dans IndexedDB
  final String? photoFileName;

  // Pour les jobs texte
  final String? searchName;
  final String? searchDomaine;
  final String? searchVintage;

  // Données partielles de la bouteille (qty, format, prix, etc.)
  WineDraftData draftData;

  AiSearchJobStatus status;
  String? errorMessage;
  CrossCheckResult? result;
  DateTime? completedAt;
  int retryCount;

  AiSearchJob({
    required this.id,
    required this.createdAt,
    required this.type,
    this.photoBytes,
    this.photoBlobKey,
    this.photoFileName,
    this.searchName,
    this.searchDomaine,
    this.searchVintage,
    WineDraftData? draftData,
    this.status = AiSearchJobStatus.queued,
    this.errorMessage,
    this.result,
    this.completedAt,
    this.retryCount = 0,
  }) : draftData = draftData ?? WineDraftData();

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'type': type.name,
        'photoBlobKey': photoBlobKey,
        'photoFileName': photoFileName,
        'searchName': searchName,
        'searchDomaine': searchDomaine,
        'searchVintage': searchVintage,
        'draftData': draftData.toJson(),
        'status': status.name,
        'errorMessage': errorMessage,
        'completedAt': completedAt?.toIso8601String(),
        'result': result?.toJson(),
        'retryCount': retryCount,
      };

  factory AiSearchJob.fromJson(Map<String, dynamic> j) {
    AiSearchJobType parseType(dynamic v) {
      if (v is String) {
        for (final t in AiSearchJobType.values) {
          if (t.name == v) return t;
        }
      }
      return AiSearchJobType.text;
    }

    AiSearchJobStatus parseStatus(dynamic v) {
      if (v is String) {
        for (final s in AiSearchJobStatus.values) {
          if (s.name == v) return s;
        }
      }
      return AiSearchJobStatus.queued;
    }

    return AiSearchJob(
      id: j['id'],
      createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      type: parseType(j['type']),
      photoBlobKey: j['photoBlobKey'] as String?,
      photoFileName: j['photoFileName'] as String?,
      searchName: j['searchName'] as String?,
      searchDomaine: j['searchDomaine'] as String?,
      searchVintage: j['searchVintage'] as String?,
      draftData: j['draftData'] is Map
          ? WineDraftData.fromJson(
              (j['draftData'] as Map).cast<String, dynamic>())
          : WineDraftData(),
      status: parseStatus(j['status']),
      errorMessage: j['errorMessage'] as String?,
      completedAt: j['completedAt'] is String
          ? DateTime.tryParse(j['completedAt'])
          : null,
      result: j['result'] is Map
          ? CrossCheckResult.fromJson(
              (j['result'] as Map).cast<String, dynamic>())
          : null,
      retryCount: (j['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Libellé court pour l'affichage dans la liste.
  String get displayLabel {
    if (type == AiSearchJobType.photo) {
      final n = searchName?.trim() ?? '';
      if (n.isNotEmpty) return n;
      return 'Photo • ${photoFileName ?? "sans nom"}';
    }
    final parts = <String>[
      if (searchName != null && searchName!.trim().isNotEmpty)
        searchName!.trim(),
      if (searchDomaine != null && searchDomaine!.trim().isNotEmpty)
        searchDomaine!.trim(),
      if (searchVintage != null && searchVintage!.trim().isNotEmpty)
        searchVintage!.trim(),
    ];
    return parts.isEmpty ? 'Recherche texte' : parts.join(' · ');
  }
}
