enum WishColumnGroup {
  identification('Identification'),
  origine('Origine'),
  caracteristiques('Caractéristiques'),
  garde('Garde'),
  valeur('Valeur'),
  notes('Notes');

  final String label;
  const WishColumnGroup(this.label);
}

enum WishColumn {
  // ── Identification ──
  photo(label: '', width: 50, group: WishColumnGroup.identification, defaultVisible: true, essential: true),
  name(label: 'Vin', flex: 3, group: WishColumnGroup.identification, defaultVisible: true, essential: true),
  producer(label: 'Producteur', flex: 2, group: WishColumnGroup.identification, defaultVisible: true),
  vintage(label: 'Mill.', width: 50, group: WishColumnGroup.identification, defaultVisible: true),
  type(label: 'Type', width: 74, group: WishColumnGroup.identification, defaultVisible: true),

  // ── Origine ──
  appellation(label: 'Appellation', flex: 2, group: WishColumnGroup.origine, defaultVisible: true),
  region(label: 'Région', flex: 2, group: WishColumnGroup.origine, defaultVisible: false),
  country(label: 'Pays', width: 90, group: WishColumnGroup.origine, defaultVisible: false),
  village(label: 'Village', width: 100, group: WishColumnGroup.origine, defaultVisible: false),
  climat(label: 'Climat', width: 110, group: WishColumnGroup.origine, defaultVisible: false),
  domaine(label: 'Domaine', flex: 2, group: WishColumnGroup.origine, defaultVisible: false),
  domainAddress(label: 'Adresse', flex: 2, group: WishColumnGroup.origine, defaultVisible: false),

  // ── Caractéristiques ──
  grapes(label: 'Cépages', flex: 2, group: WishColumnGroup.caracteristiques, defaultVisible: false),
  alcohol(label: 'Alcool', width: 60, group: WishColumnGroup.caracteristiques, defaultVisible: false),
  rating(label: 'Note', width: 52, group: WishColumnGroup.caracteristiques, defaultVisible: false),

  // ── Garde ──
  garde(label: 'Garde', width: 80, group: WishColumnGroup.garde, defaultVisible: true),
  drinkFrom(label: 'À boire dès', width: 82, group: WishColumnGroup.garde, defaultVisible: false),
  apogee(label: 'Apogée', width: 66, group: WishColumnGroup.garde, defaultVisible: false),
  drinkTo(label: 'Fin garde', width: 82, group: WishColumnGroup.garde, defaultVisible: false),

  // ── Valeur ──
  marketValue(label: 'Val. marché', width: 86, group: WishColumnGroup.valeur, defaultVisible: true),

  // ── Notes ──
  personalNote(label: 'Note perso.', flex: 2, group: WishColumnGroup.notes, defaultVisible: true),
  createdAt(label: 'Ajouté le', width: 86, group: WishColumnGroup.notes, defaultVisible: false);

  final String label;
  final double? width;
  final int? flex;
  final WishColumnGroup group;
  final bool defaultVisible;
  final bool essential;

  const WishColumn({
    required this.label,
    this.width,
    this.flex,
    required this.group,
    required this.defaultVisible,
    this.essential = false,
  });

  static Set<WishColumn> get defaults =>
      values.where((c) => c.defaultVisible).toSet();

  static Set<WishColumn> get essentials =>
      values.where((c) => c.essential).toSet();
}
