enum ColumnGroup {
  identification('Identification'),
  origine('Origine'),
  caracteristiques('Caractéristiques'),
  garde('Garde'),
  achat('Achat'),
  stock('Stock');

  final String label;
  const ColumnGroup(this.label);
}

enum CaveColumn {
  photo(
      label: '',
      width: 50,
      group: ColumnGroup.identification,
      defaultVisible: true,
      essential: true),
  name(
      label: 'Vin',
      flex: 3,
      group: ColumnGroup.identification,
      defaultVisible: true,
      essential: true),
  type(
      label: 'Type',
      width: 74,
      group: ColumnGroup.identification,
      defaultVisible: false),
  vintage(
      label: 'Mill.',
      width: 58,
      group: ColumnGroup.identification,
      defaultVisible: true),
  appellation(
      label: 'Appellation',
      flex: 2,
      group: ColumnGroup.origine,
      defaultVisible: false),
  region(
      label: 'Région',
      flex: 2,
      group: ColumnGroup.origine,
      defaultVisible: true),
  country(
      label: 'Pays',
      width: 90,
      group: ColumnGroup.origine,
      defaultVisible: false),
  village(
      label: 'Village',
      width: 100,
      group: ColumnGroup.origine,
      defaultVisible: false),
  climat(
      label: 'Climat',
      width: 110,
      group: ColumnGroup.origine,
      defaultVisible: false),
  domaine(
      label: 'Domaine',
      flex: 2,
      group: ColumnGroup.origine,
      defaultVisible: false),
  domainAddress(
      label: 'Adresse',
      flex: 2,
      group: ColumnGroup.origine,
      defaultVisible: false),
  grapes(
      label: 'Cépages',
      flex: 2,
      group: ColumnGroup.caracteristiques,
      defaultVisible: false),
  alcohol(
      label: 'Alcool',
      width: 60,
      group: ColumnGroup.caracteristiques,
      defaultVisible: false),
  rating(
      label: 'Note',
      width: 52,
      group: ColumnGroup.caracteristiques,
      defaultVisible: true),
  garde(
      label: 'Garde',
      width: 80,
      group: ColumnGroup.garde,
      defaultVisible: true),
  drinkFrom(
      label: 'À boire dès',
      width: 82,
      group: ColumnGroup.garde,
      defaultVisible: false),
  apogee(
      label: 'Apogée',
      width: 66,
      group: ColumnGroup.garde,
      defaultVisible: false),
  drinkTo(
      label: 'Fin garde',
      width: 82,
      group: ColumnGroup.garde,
      defaultVisible: false),
  format(
      label: 'Format',
      width: 70,
      group: ColumnGroup.achat,
      defaultVisible: true),
  source(
      label: 'Provenance',
      width: 100,
      group: ColumnGroup.achat,
      defaultVisible: false),
  purchaseYear(
      label: 'An. achat',
      width: 72,
      group: ColumnGroup.achat,
      defaultVisible: false),
  price(
      label: 'Prix payé moy.',
      width: 74,
      group: ColumnGroup.achat,
      defaultVisible: true),
  marketValue(
      label: 'Val. marchande',
      width: 76,
      group: ColumnGroup.achat,
      defaultVisible: false),
  totalValue(
      label: 'Valeur totale',
      width: 70,
      group: ColumnGroup.achat,
      defaultVisible: true),
  location(
      label: 'Emplacement',
      width: 100,
      group: ColumnGroup.stock,
      defaultVisible: false),
  createdAt(
      label: 'Ajoutée le',
      width: 86,
      group: ColumnGroup.stock,
      defaultVisible: false),
  qty(
      label: 'Qté',
      width: 40,
      group: ColumnGroup.stock,
      defaultVisible: true,
      essential: true);

  final String label;
  final double? width;
  final int? flex;
  final ColumnGroup group;
  final bool defaultVisible;
  final bool essential;

  const CaveColumn({
    required this.label,
    this.width,
    this.flex,
    required this.group,
    required this.defaultVisible,
    this.essential = false,
  });

  static Set<CaveColumn> get defaults =>
      CaveColumn.values.where((c) => c.defaultVisible).toSet();

  static Set<CaveColumn> get essentials =>
      CaveColumn.values.where((c) => c.essential).toSet();
}
