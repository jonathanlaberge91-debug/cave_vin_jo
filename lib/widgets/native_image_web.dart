import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

int _nextId = 0;

/// Un seul type de vue (donc une seule fabrique enregistrée) par image.
/// Sans ce cache, chaque reconstruction du widget créait un nouveau type de
/// vue et un nouvel élément <img> : le téléchargement repartait de zéro à
/// chaque rebuild (catastrophique pour l'aperçu flottant, reconstruit à
/// chaque mouvement de souris).
final Map<String, String> _viewTypes = {};

String _objectFitCss(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
    default:
      return 'cover';
  }
}

String _viewTypeFor(String url, String objectFit, bool eager) {
  final key = '$url|$objectFit|$eager';
  final cached = _viewTypes[key];
  if (cached != null) return cached;

  final viewType = 'native-img-${_nextId++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int id) {
    final img = web.document.createElement('img') as web.HTMLImageElement;
    // Décodage hors du fil principal. Le chargement différé n'est utile que
    // pour les vignettes des longues listes : pour une image demandée
    // explicitement (aperçu, fiche) il ne fait que retarder le départ.
    img.loading = eager ? 'eager' : 'lazy';
    img.decoding = 'async';
    if (eager) img.setAttribute('fetchpriority', 'high');
    img.src = url;
    img.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = objectFit
      ..display = 'block';
    return img;
  });
  _viewTypes[key] = viewType;
  return viewType;
}

Widget buildWebImage({
  required String url,
  required double width,
  required double height,
  required BoxFit fit,
  bool eager = false,
}) {
  final viewType = _viewTypeFor(url, _objectFitCss(fit), eager);
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView(key: ValueKey(viewType), viewType: viewType),
  );
}

/// Demande au navigateur de télécharger l'image en avance (cache HTTP), sans
/// l'afficher. Utilisé pour que l'originale HD soit déjà là au survol.
void precacheWebImage(String url) {
  final img = web.document.createElement('img') as web.HTMLImageElement;
  img.decoding = 'async';
  img.src = url;
}
