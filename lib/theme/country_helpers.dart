String _normalizeCountryKey(String s) {
  if (s.trim().isEmpty) return '';
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  var t = s.toLowerCase();
  accents.forEach((k, v) => t = t.replaceAll(k, v));
  t = t
      .replaceAll(RegExp(r"[^a-z0-9 ]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return t;
}

const Map<String, String> _flagByKey = {
  'france': '🇫🇷',
  'italie': '🇮🇹', 'italy': '🇮🇹',
  'espagne': '🇪🇸', 'spain': '🇪🇸',
  'portugal': '🇵🇹',
  'allemagne': '🇩🇪', 'germany': '🇩🇪',
  'autriche': '🇦🇹', 'austria': '🇦🇹',
  'suisse': '🇨🇭', 'switzerland': '🇨🇭',
  'grece': '🇬🇷', 'greece': '🇬🇷',
  'hongrie': '🇭🇺', 'hungary': '🇭🇺',
  'roumanie': '🇷🇴', 'romania': '🇷🇴',
  'bulgarie': '🇧🇬',
  'croatie': '🇭🇷', 'croatia': '🇭🇷',
  'slovenie': '🇸🇮', 'slovenia': '🇸🇮',
  'georgie': '🇬🇪', 'georgia': '🇬🇪',
  'royaume uni': '🇬🇧', 'angleterre': '🇬🇧', 'royaume-uni': '🇬🇧',
  'pays bas': '🇳🇱', 'pays-bas': '🇳🇱',
  'belgique': '🇧🇪',
  'luxembourg': '🇱🇺',
  'republique tcheque': '🇨🇿',
  'moldavie': '🇲🇩',
  'ukraine': '🇺🇦',
  'turquie': '🇹🇷',
  'liban': '🇱🇧', 'lebanon': '🇱🇧',
  'israel': '🇮🇱',
  'maroc': '🇲🇦', 'morocco': '🇲🇦',
  'tunisie': '🇹🇳',
  'algerie': '🇩🇿',
  'afrique du sud': '🇿🇦', 'south africa': '🇿🇦',
  'canada': '🇨🇦',
  'etats unis': '🇺🇸', 'etats-unis': '🇺🇸', 'usa': '🇺🇸',
  'united states': '🇺🇸', 'us': '🇺🇸', 'amerique': '🇺🇸',
  'mexique': '🇲🇽', 'mexico': '🇲🇽',
  'argentine': '🇦🇷', 'argentina': '🇦🇷',
  'chili': '🇨🇱', 'chile': '🇨🇱',
  'uruguay': '🇺🇾',
  'bresil': '🇧🇷', 'brazil': '🇧🇷',
  'perou': '🇵🇪',
  'australie': '🇦🇺', 'australia': '🇦🇺',
  'nouvelle zelande': '🇳🇿', 'nouvelle-zelande': '🇳🇿', 'new zealand': '🇳🇿',
  'japon': '🇯🇵', 'japan': '🇯🇵',
  'chine': '🇨🇳', 'china': '🇨🇳',
  'inde': '🇮🇳', 'india': '🇮🇳',
};

String? flagForCountry(String country) {
  final key = _normalizeCountryKey(country);
  if (key.isEmpty) return null;
  return _flagByKey[key];
}

enum WineContinent {
  europe('Europe'),
  ameriques('Amériques'),
  oceanie('Océanie'),
  afrique('Afrique'),
  asie('Asie'),
  autre('Autre');

  final String label;
  const WineContinent(this.label);
}

const Map<String, WineContinent> _continentByKey = {
  // Europe
  'france': WineContinent.europe,
  'italie': WineContinent.europe, 'italy': WineContinent.europe,
  'espagne': WineContinent.europe, 'spain': WineContinent.europe,
  'portugal': WineContinent.europe,
  'allemagne': WineContinent.europe, 'germany': WineContinent.europe,
  'autriche': WineContinent.europe, 'austria': WineContinent.europe,
  'suisse': WineContinent.europe, 'switzerland': WineContinent.europe,
  'grece': WineContinent.europe, 'greece': WineContinent.europe,
  'hongrie': WineContinent.europe, 'hungary': WineContinent.europe,
  'roumanie': WineContinent.europe, 'romania': WineContinent.europe,
  'bulgarie': WineContinent.europe,
  'croatie': WineContinent.europe, 'croatia': WineContinent.europe,
  'slovenie': WineContinent.europe, 'slovenia': WineContinent.europe,
  'royaume uni': WineContinent.europe, 'royaume-uni': WineContinent.europe,
  'angleterre': WineContinent.europe,
  'pays bas': WineContinent.europe, 'pays-bas': WineContinent.europe,
  'belgique': WineContinent.europe,
  'luxembourg': WineContinent.europe,
  'republique tcheque': WineContinent.europe,
  'moldavie': WineContinent.europe,
  'ukraine': WineContinent.europe,
  // Amériques
  'canada': WineContinent.ameriques,
  'etats unis': WineContinent.ameriques, 'etats-unis': WineContinent.ameriques,
  'usa': WineContinent.ameriques, 'united states': WineContinent.ameriques,
  'us': WineContinent.ameriques, 'amerique': WineContinent.ameriques,
  'mexique': WineContinent.ameriques, 'mexico': WineContinent.ameriques,
  'argentine': WineContinent.ameriques, 'argentina': WineContinent.ameriques,
  'chili': WineContinent.ameriques, 'chile': WineContinent.ameriques,
  'uruguay': WineContinent.ameriques,
  'bresil': WineContinent.ameriques, 'brazil': WineContinent.ameriques,
  'perou': WineContinent.ameriques,
  // Océanie
  'australie': WineContinent.oceanie, 'australia': WineContinent.oceanie,
  'nouvelle zelande': WineContinent.oceanie,
  'nouvelle-zelande': WineContinent.oceanie,
  'new zealand': WineContinent.oceanie,
  // Afrique
  'maroc': WineContinent.afrique, 'morocco': WineContinent.afrique,
  'tunisie': WineContinent.afrique,
  'algerie': WineContinent.afrique,
  'afrique du sud': WineContinent.afrique,
  'south africa': WineContinent.afrique,
  // Asie
  'liban': WineContinent.asie, 'lebanon': WineContinent.asie,
  'israel': WineContinent.asie,
  'turquie': WineContinent.asie,
  'georgie': WineContinent.asie, 'georgia': WineContinent.asie,
  'japon': WineContinent.asie, 'japan': WineContinent.asie,
  'chine': WineContinent.asie, 'china': WineContinent.asie,
  'inde': WineContinent.asie, 'india': WineContinent.asie,
};

WineContinent continentForCountry(String country) {
  final key = _normalizeCountryKey(country);
  if (key.isEmpty) return WineContinent.autre;
  return _continentByKey[key] ?? WineContinent.autre;
}
