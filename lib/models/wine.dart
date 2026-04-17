import 'package:cloud_firestore/cloud_firestore.dart';

enum WineType { rouge, blanc, rose, orange, petillant }

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
  final DateTime createdAt;

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
    required this.createdAt,
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
        'createdAt': Timestamp.fromDate(createdAt),
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
