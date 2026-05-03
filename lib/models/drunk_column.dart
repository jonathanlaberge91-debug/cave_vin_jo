enum DrunkColumnGroup {
  identification('Identification'),
  origine('Origine'),
  caracteristiques('Caractéristiques'),
  garde('Garde'),
  degustation('Dégustation'),
  achat('Achat');

  final String label;
  const DrunkColumnGroup(this.label);
}

enum DrunkColumn {
  photo(
      label: '',
      width: 42,
      group: DrunkColumnGroup.identification,
      defaultVisible: true,
      essential: true),
  name(
      label: 'Vin',
      flex: 3,
      group: DrunkColumnGroup.identification,
      defaultVisible: true,
      essential: true),
  producer(
      label: 'Producteur',
      flex: 2,
      group: DrunkColumnGroup.identification,
      defaultVisible: true),
  vintage(
      label: 'Mill.',
      width: 70,
      group: DrunkColumnGroup.identification,
      defaultVisible: true),
  type(
      label: 'Type',
      width: 80,
      group: DrunkColumnGroup.identification,
      defaultVisible: true),
  appellation(
      label: 'Appellation',
      flex: 2,
      group: DrunkColumnGroup.origine,
      defaultVisible: true),
  region(
      label: 'Région',
      flex: 2,
      group: DrunkColumnGroup.origine,
      defaultVisible: false),
  country(
      label: 'Pays',
      width: 90,
      group: DrunkColumnGroup.origine,
      defaultVisible: false),
  village(
      label: 'Village',
      width: 100,
      group: DrunkColumnGroup.origine,
      defaultVisible: false),
  climat(
      label: 'Climat',
      width: 110,
      group: DrunkColumnGroup.origine,
      defaultVisible: false),
  domaine(
      label: 'Domaine',
      flex: 2,
      group: DrunkColumnGroup.origine,
      defaultVisible: false),
  domainAddress(
      label: 'Adresse',
      flex: 2,
      group: DrunkColumnGroup.origine,
      defaultVisible: false),
  grapes(
      label: 'Cépages',
      flex: 2,
      group: DrunkColumnGroup.caracteristiques,
      defaultVisible: false),
  alcohol(
      label: 'Alcool',
      width: 60,
      group: DrunkColumnGroup.caracteristiques,
      defaultVisible: false),
  rating(
      label: 'Note vin',
      width: 66,
      group: DrunkColumnGroup.caracteristiques,
      defaultVisible: false),
  gardeStatus(
      label: 'Garde',
      width: 80,
      group: DrunkColumnGroup.garde,
      defaultVisible: false),
  drinkFrom(
      label: 'À boire dès',
      width: 82,
      group: DrunkColumnGroup.garde,
      defaultVisible: false),
  apogee(
      label: 'Apogée',
      width: 66,
      group: DrunkColumnGroup.garde,
      defaultVisible: false),
  drinkTo(
      label: 'Fin garde',
      width: 82,
      group: DrunkColumnGroup.garde,
      defaultVisible: false),
  format(
      label: 'Format',
      width: 70,
      group: DrunkColumnGroup.achat,
      defaultVisible: true),
  price(
      label: 'Prix',
      width: 70,
      group: DrunkColumnGroup.achat,
      defaultVisible: true),
  source(
      label: 'Provenance',
      width: 100,
      group: DrunkColumnGroup.achat,
      defaultVisible: false),
  purchaseYear(
      label: 'An. achat',
      width: 72,
      group: DrunkColumnGroup.achat,
      defaultVisible: false),
  marketValue(
      label: 'Val. marché',
      width: 86,
      group: DrunkColumnGroup.achat,
      defaultVisible: false),
  drunkRating(
      label: 'Note dégust.',
      width: 80,
      group: DrunkColumnGroup.degustation,
      defaultVisible: true),
  drunkDate(
      label: 'Date',
      width: 90,
      group: DrunkColumnGroup.degustation,
      defaultVisible: true),
  drunkLocation(
      label: 'Lieu',
      width: 100,
      group: DrunkColumnGroup.degustation,
      defaultVisible: false),
  drunkNote(
      label: 'Commentaire',
      flex: 2,
      group: DrunkColumnGroup.degustation,
      defaultVisible: false);

  final String label;
  final double? width;
  final int? flex;
  final DrunkColumnGroup group;
  final bool defaultVisible;
  final bool essential;

  const DrunkColumn({
    required this.label,
    this.width,
    this.flex,
    required this.group,
    required this.defaultVisible,
    this.essential = false,
  });

  static Set<DrunkColumn> get defaults =>
      DrunkColumn.values.where((c) => c.defaultVisible).toSet();

  static Set<DrunkColumn> get essentials =>
      DrunkColumn.values.where((c) => c.essential).toSet();
}
