enum StatChartType {
  info('Info'),
  compteurs('Compteurs'),
  donut('Donut'),
  ligne('Ligne'),
  barres('Barres'),
  barresH('Barres H');

  final String label;
  const StatChartType(this.label);
}

enum StatItem {
  valeurTotale('Valeur de la cave', chartType: StatChartType.info, allowedTypes: [], isPriceRelated: true),
  diversiteStreak('Diversité & streak', chartType: StatChartType.compteurs, allowedTypes: []),
  typeDonut('Répartition par type', chartType: StatChartType.donut, allowedTypes: [StatChartType.donut, StatChartType.barresH]),
  gardeDonut('Fenêtre de garde', chartType: StatChartType.donut, allowedTypes: [StatChartType.donut, StatChartType.barresH]),
  acquisitionVsConsommation('Acquisition vs consommation', chartType: StatChartType.ligne, allowedTypes: [StatChartType.ligne, StatChartType.barres]),
  ajouteesParMois('Bouteilles ajoutées / mois', chartType: StatChartType.barres, allowedTypes: [StatChartType.barres, StatChartType.ligne]),
  buesParMois('Bouteilles bues / mois', chartType: StatChartType.barres, allowedTypes: [StatChartType.barres, StatChartType.ligne]),
  parPays('Bouteilles par pays', chartType: StatChartType.barresH, allowedTypes: [StatChartType.barresH, StatChartType.donut]),
  carteMonde('Carte du monde', chartType: StatChartType.info, allowedTypes: []),
  parRegion('Bouteilles par région', chartType: StatChartType.barresH, allowedTypes: [StatChartType.barresH, StatChartType.donut]),
  parAppellation('Bouteilles par appellation', chartType: StatChartType.barresH, allowedTypes: [StatChartType.barresH, StatChartType.donut]),
  topDomaines('Top domaines', chartType: StatChartType.barresH, allowedTypes: [StatChartType.barresH, StatChartType.donut]),
  plusValue('Plus-value (achat vs marché)', chartType: StatChartType.barres, allowedTypes: [StatChartType.barres, StatChartType.ligne], isPriceRelated: true),
  distributionPrix('Distribution des prix', chartType: StatChartType.barres, allowedTypes: [StatChartType.barres, StatChartType.ligne], isPriceRelated: true),
  maturiteCalendrier('Calendrier de maturité', chartType: StatChartType.ligne, allowedTypes: [StatChartType.ligne, StatChartType.barres]),
  distributionMillesimes('Distribution des millésimes', chartType: StatChartType.barres, allowedTypes: [StatChartType.barres, StatChartType.ligne, StatChartType.donut]),
  cepagesDonut('Cépages principaux', chartType: StatChartType.donut, allowedTypes: [StatChartType.donut, StatChartType.barresH]),
  cepagesPart('Cépages - part en cave', chartType: StatChartType.donut, allowedTypes: [StatChartType.donut]),
  distributionCamembert('Distribution (cépage / pays / région)', chartType: StatChartType.donut, allowedTypes: [StatChartType.donut]);

  final String label;
  final StatChartType chartType;
  final List<StatChartType> allowedTypes;
  final bool isPriceRelated;
  const StatItem(this.label, {required this.chartType, this.allowedTypes = const [], this.isPriceRelated = false});

  static const List<StatItem> defaultOrder = [
    valeurTotale,
    diversiteStreak,
    typeDonut,
    gardeDonut,
    distributionCamembert,
    acquisitionVsConsommation,
    ajouteesParMois,
    buesParMois,
    parPays,
    carteMonde,
    parRegion,
    parAppellation,
    topDomaines,
    plusValue,
    distributionPrix,
    maturiteCalendrier,
    distributionMillesimes,
    cepagesDonut,
    cepagesPart,
  ];

  static const List<List<StatItem>> defaultLayout = [
    [valeurTotale],
    [diversiteStreak],
    [typeDonut, gardeDonut],
    [distributionCamembert],
    [acquisitionVsConsommation],
    [ajouteesParMois, buesParMois],
    [parPays],
    [carteMonde],
    [parRegion],
    [parAppellation],
    [topDomaines],
    [plusValue],
    [distributionPrix],
    [maturiteCalendrier],
    [distributionMillesimes],
    [cepagesDonut, cepagesPart],
  ];
}
