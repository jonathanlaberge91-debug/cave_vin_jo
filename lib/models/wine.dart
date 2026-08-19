import 'package:cloud_firestore/cloud_firestore.dart';

enum WineType { rouge, blanc, rose, orange, petillant }

class Critique {
  final String source;
  final String score;
  final String note;
  final DateTime? date;

  const Critique({
    required this.source,
    this.score = '',
    this.note = '',
    this.date,
  });

  Map<String, dynamic> toMap() => {
        'source': source,
        'score': score,
        'note': note,
        'date': date != null ? Timestamp.fromDate(date!) : null,
      };

  factory Critique.fromMap(Map<String, dynamic> data) => Critique(
        source: data['source'] ?? '',
        score: data['score'] ?? '',
        note: data['note'] ?? '',
        date: (data['date'] as Timestamp?)?.toDate(),
      );
}

class Wine {
  final String id;
  final String name;
  final String producer;
  final int? vintage;
  final String appellation;
  final String country;
  final String region;
  final String climat;
  final String domaine;
  final String village;
  final String domainAddress;
  final String grapes;
  final double? alcohol;
  final WineType type;
  final int? drinkFrom;
  final int? drinkPeak;
  final int? drinkTo;
  final int? rating;
  final String wineDescription;
  final String domaineDescription;
  final String? photoUrl;
  final String? thumbUrl;
  final List<Critique> critiques;
  final DateTime createdAt;
  final DateTime? lastAutoRefreshed;

  /// Bouteille entrée en vitesse (photo + quantité + emplacement), dont
  /// l'analyse IA n'a pas encore été lancée. Pastille « à identifier ».
  final bool aiPending;

  /// L'IA a rempli la fiche toute seule et personne ne l'a encore relue.
  /// Pastille « à vérifier », effacée dès l'ouverture de la fiche.
  final bool aiNeedsReview;

  /// Raison du dernier échec d'analyse (reste « à identifier »).
  final String? aiError;

  /// Aide-mémoire tapé à l'entrée rapide (« caisse de la SAQ », « cadeau de
  /// Marc »…). Sert à reconnaître la bouteille en attendant l'identification;
  /// l'IA n'y touche jamais.
  final String quickNote;

  /// Vrai tant que le vin n'a pas de nom : entré en vitesse, pas identifié.
  bool get isUnidentified => aiPending || name.trim().isEmpty;

  /// Nom à afficher partout : les bouteilles entrées en vitesse n'ont pas
  /// encore de nom tant que l'IA n'est pas passée.
  String get displayName {
    final n = name.trim();
    return n.isEmpty ? 'À identifier' : n;
  }

  /// URL à utiliser dans les grilles/listes (miniature légère si disponible,
  /// sinon l'originale). La fiche et l'agrandissement utilisent [photoUrl].
  String? get thumbOrFull => thumbUrl ?? photoUrl;

  Wine({
    required this.id,
    required this.name,
    this.producer = '',
    this.vintage,
    this.appellation = '',
    this.country = '',
    this.region = '',
    this.climat = '',
    this.domaine = '',
    this.village = '',
    this.domainAddress = '',
    this.grapes = '',
    this.alcohol,
    this.type = WineType.rouge,
    this.drinkFrom,
    this.drinkPeak,
    this.drinkTo,
    this.rating,
    this.wineDescription = '',
    this.domaineDescription = '',
    this.photoUrl,
    this.thumbUrl,
    this.critiques = const [],
    required this.createdAt,
    this.lastAutoRefreshed,
    this.aiPending = false,
    this.aiNeedsReview = false,
    this.aiError,
    this.quickNote = '',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'producer': producer,
        'vintage': vintage,
        'appellation': appellation,
        'country': country,
        'region': region,
        'climat': climat,
        'domaine': domaine,
        'village': village,
        'domainAddress': domainAddress,
        'grapes': grapes,
        'alcohol': alcohol,
        'type': type.name,
        'drinkFrom': drinkFrom,
        'drinkPeak': drinkPeak,
        'drinkTo': drinkTo,
        'rating': rating,
        'wineDescription': wineDescription,
        'domaineDescription': domaineDescription,
        'photoUrl': photoUrl,
        'thumbUrl': thumbUrl,
        'critiques': critiques.map((c) => c.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'aiPending': aiPending,
        'aiNeedsReview': aiNeedsReview,
        'aiError': aiError,
        'quickNote': quickNote,
      };

  factory Wine.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Wine(
      id: doc.id,
      name: data['name'] ?? '',
      producer: data['producer'] ?? '',
      vintage: data['vintage'],
      appellation: data['appellation'] ?? '',
      country: data['country'] ?? '',
      region: data['region'] ?? '',
      climat: data['climat'] ?? '',
      domaine: data['domaine'] ?? '',
      village: data['village'] ?? '',
      domainAddress: data['domainAddress'] ?? '',
      grapes: data['grapes'] ?? '',
      alcohol: (data['alcohol'] as num?)?.toDouble(),
      type: WineType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => WineType.rouge,
      ),
      drinkFrom: data['drinkFrom'],
      drinkPeak: data['drinkPeak'],
      drinkTo: data['drinkTo'],
      rating: data['rating'],
      wineDescription: data['wineDescription'] ?? '',
      domaineDescription: data['domaineDescription'] ?? '',
      photoUrl: data['photoUrl'],
      thumbUrl: data['thumbUrl'],
      critiques: (data['critiques'] as List?)
              ?.map((c) => Critique.fromMap(Map<String, dynamic>.from(c)))
              .toList() ??
          const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastAutoRefreshed: (data['lastAutoRefreshed'] as Timestamp?)?.toDate(),
      aiPending: data['aiPending'] == true,
      aiNeedsReview: data['aiNeedsReview'] == true,
      aiError: data['aiError'] as String?,
      quickNote: data['quickNote'] ?? '',
    );
  }
}
