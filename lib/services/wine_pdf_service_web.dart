import 'dart:js_interop';
import 'dart:math' as math;
import 'package:web/web.dart' as web;
import '../models/wine.dart';
import '../models/bottle.dart';
import '../theme/wine_type_helpers.dart';

void openWinePrintSheetImpl(Wine wine, List<Bottle> bottles) {
  final html = _buildHtml(wine, bottles);
  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

void openAllWinesPrintSheetImpl(List<Wine> wines, List<Bottle> bottles) {
  if (wines.isEmpty) return;
  final byWine = <String, List<Bottle>>{};
  for (final b in bottles) {
    byWine.putIfAbsent(b.wineId, () => []).add(b);
  }
  final pages = <String>[];
  for (final w in wines) {
    final btls = byWine[w.id] ?? const <Bottle>[];
    pages.add(_buildPageBody(w, btls));
  }
  final body = pages.join(
    '<div style="page-break-after:always; height:0;"></div>',
  );
  final html = '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Cave – ${wines.length} fiches</title>
<style>
@page { size: A4; margin: 0; }
* { margin:0; padding:0; box-sizing:border-box; }
body { font-family: 'Didot', 'Bodoni MT', Georgia, serif; color:#1a1a1a; background:#fffdf5; }
.page { width:210mm; height:297mm; padding:40px 48px; position:relative; display:flex; flex-direction:column; overflow:hidden; page-break-inside:avoid; }
.border1 { position:absolute;top:18px;left:18px;right:18px;bottom:18px;border:1px solid #c9a96e;pointer-events:none; }
.border2 { position:absolute;top:22px;left:22px;right:22px;bottom:22px;border:1px solid #8b6914;pointer-events:none; }
@media print {
  body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
}
</style>
</head>
<body>
$body
<script>
  window.addEventListener('load', function() {
    setTimeout(function() { window.print(); }, 600);
  });
</script>
</body>
</html>''';
  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

void exportInventoryCsvImpl(List<Wine> wines, List<Bottle> bottles) {
  final csv = _buildCsv(wines, bottles);
  final blob = web.Blob(
    [csv.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8;'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = 'cave_${_stamp()}.csv';
  web.document.body!.append(a);
  a.click();
  a.remove();
  web.URL.revokeObjectURL(url);
}

void exportInventoryPdfImpl(List<Wine> wines, List<Bottle> bottles) {
  final html = _buildInventoryHtml(wines, bottles);
  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}

String _stamp() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

String _csvField(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _buildCsv(List<Wine> wines, List<Bottle> bottles) {
  const headers = [
    'Nom', 'Producteur', 'Millésime', 'Appellation', 'Région', 'Pays',
    'Domaine', 'Cépages', 'Alcool %', 'Format', 'Qté', "Prix d'achat",
    'Note', 'Garde de', 'Apogée', "Garde jusqu'à", 'Type',
  ];

  final grouped = <String, Map<BottleFormat, List<Bottle>>>{};
  for (final b in bottles) {
    grouped
        .putIfAbsent(b.wineId, () => <BottleFormat, List<Bottle>>{})
        .putIfAbsent(b.format, () => <Bottle>[])
        .add(b);
  }

  final rows = <List<String>>[headers];
  for (final wine in wines) {
    final byFormat = grouped[wine.id];
    if (byFormat == null) continue;
    for (final entry in byFormat.entries) {
      final btls = entry.value;
      final priceBottle =
          btls.firstWhere((b) => b.purchasePrice != null, orElse: () => btls.first);
      rows.add([
        wine.name,
        wine.producer,
        wine.vintage?.toString() ?? '',
        wine.appellation,
        wine.region,
        wine.country,
        wine.domaine,
        wine.grapes,
        wine.alcohol?.toStringAsFixed(1) ?? '',
        entry.key.label,
        btls.length.toString(),
        priceBottle.purchasePrice?.toStringAsFixed(2) ?? '',
        wine.rating?.toString() ?? '',
        wine.drinkFrom?.toString() ?? '',
        wine.drinkPeak?.toString() ?? '',
        wine.drinkTo?.toString() ?? '',
        wineTypeLabel(wine.type),
      ]);
    }
  }

  return rows.map((r) => r.map(_csvField).join(',')).join('\r\n');
}

String _buildInventoryHtml(List<Wine> wines, List<Bottle> bottles) {
  final grouped = <String, Map<BottleFormat, List<Bottle>>>{};
  for (final b in bottles) {
    grouped
        .putIfAbsent(b.wineId, () => <BottleFormat, List<Bottle>>{})
        .putIfAbsent(b.format, () => <Bottle>[])
        .add(b);
  }

  final today = _stamp();
  final totalQty = bottles.length;
  final rows = StringBuffer();

  for (final wine in wines) {
    final byFormat = grouped[wine.id];
    if (byFormat == null) continue;
    for (final entry in byFormat.entries) {
      final btls = entry.value;
      final priceBottle =
          btls.firstWhere((b) => b.purchasePrice != null, orElse: () => btls.first);
      final price = priceBottle.purchasePrice;
      final gardeParts = [
        if (wine.drinkFrom != null) wine.drinkFrom.toString(),
        if (wine.drinkPeak != null) '&#9670;&nbsp;${wine.drinkPeak}',
        if (wine.drinkTo != null) wine.drinkTo.toString(),
      ];
      final garde = gardeParts.join(' – ');
      rows.write('''<tr>
        <td>${_esc(wine.name)}</td>
        <td>${_esc(wine.producer)}</td>
        <td style="text-align:center;">${wine.vintage ?? ''}</td>
        <td>${_esc(wine.appellation)}</td>
        <td>${_esc(wine.region)}</td>
        <td style="text-align:center;">${_esc(wineTypeLabel(wine.type))}</td>
        <td style="text-align:center;">${_esc(entry.key.label)}</td>
        <td style="text-align:center;font-weight:bold;">${btls.length}</td>
        <td style="text-align:right;">${price != null ? '${price.toStringAsFixed(0)}&nbsp;\$' : ''}</td>
        <td style="text-align:center;">${wine.rating != null ? '<b>${wine.rating}</b>' : ''}</td>
        <td>$garde</td>
      </tr>''');
    }
  }

  return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>Inventaire cave – $today</title>
<style>
@page { size: A4 landscape; margin: 12mm; }
* { margin:0; padding:0; box-sizing:border-box; }
body { font-family: Georgia, 'Times New Roman', serif; color:#1a1a1a; background:#fffdf5; font-size:10px; }
.header { text-align:center; margin-bottom:16px; padding-bottom:12px; border-bottom:2px solid #8b6914; }
h1 { font-size:20px; color:#8b6914; letter-spacing:3px; font-weight:bold; }
.meta { font-size:10px; color:#999; margin-top:4px; }
table { width:100%; border-collapse:collapse; }
thead tr { background:#8b6914; color:#fff; }
thead th { padding:6px 8px; text-align:left; font-size:9px; letter-spacing:1px; font-weight:bold; }
tbody tr:nth-child(even) { background:#f9f5ea; }
td { padding:4px 8px; border-bottom:1px solid #e8dfc0; vertical-align:middle; }
.footer { margin-top:10px; text-align:right; color:#8b6914; font-size:10px; font-style:italic; }
@media print { body { -webkit-print-color-adjust:exact; print-color-adjust:exact; } }
</style>
</head>
<body>
<div class="header">
  <h1>INVENTAIRE DE LA CAVE</h1>
  <div class="meta">Exporté le $today &middot; $totalQty bouteilles &middot; ${wines.length} vins</div>
</div>
<table>
  <thead>
    <tr>
      <th>Nom</th><th>Producteur</th><th>Mill.</th><th>Appellation</th><th>Région</th>
      <th>Type</th><th>Format</th><th>Qté</th><th>Prix</th><th>Note</th><th>Garde</th>
    </tr>
  </thead>
  <tbody>$rows</tbody>
</table>
<div class="footer">Cave Vino &middot; $today</div>
</body>
</html>''';
}

String _buildHtml(Wine wine, List<Bottle> bottles) {
  final vintage = wine.vintage != null ? '${wine.vintage}' : '';
  final body = _buildPageBody(wine, bottles);
  return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>${_esc(wine.name)} $vintage – Fiche</title>
<style>
@page { size: A4; margin: 0; }
* { margin:0; padding:0; box-sizing:border-box; }
body { width:210mm; height:297mm; font-family: 'Didot', 'Bodoni MT', Georgia, serif; color:#1a1a1a; background:#fffdf5; }
.page { width:210mm; height:297mm; padding:40px 48px; position:relative; display:flex; flex-direction:column; overflow:hidden; }
.border1 { position:absolute;top:18px;left:18px;right:18px;bottom:18px;border:1px solid #c9a96e;pointer-events:none; }
.border2 { position:absolute;top:22px;left:22px;right:22px;bottom:22px;border:1px solid #8b6914;pointer-events:none; }
@media print {
  body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
}
</style>
</head>
<body>
$body
</body>
</html>''';
}

String _buildPageBody(Wine wine, List<Bottle> bottles) {
  final vintage = wine.vintage != null ? '${wine.vintage}' : '';
  final type = wineTypeLabel(wine.type);
  final format = bottles.isNotEmpty ? bottles.first.format.label : '750 ML';
  final alcohol = wine.alcohol != null ? '${wine.alcohol!.toStringAsFixed(1)}%' : '';
  final rating = wine.rating ?? 0;

  final grapeParts = _parseGrapes(wine.grapes);
  final donutSvg = _buildDonut(grapeParts);
  final legend = _buildLegend(grapeParts);
  final grapesHtml = _buildGrapesSection(wine.grapes, donutSvg, legend);
  final timeline = _buildTimeline(wine.drinkFrom, wine.drinkPeak, wine.drinkTo);

  final nameLen = wine.name.length;
  final nameFontSize = nameLen > 30 ? 28 : nameLen > 20 ? 34 : 40;

  final critiquesHtml = wine.critiques.map((c) => '''
    <div style="flex:1; border:1.5px solid #8b6914; padding:8px 10px; text-align:center; display:flex; flex-direction:column; justify-content:space-between;">
      <div style="font-size:11px; color:#555; line-height:1.3;">${_esc(c.source)}</div>
      <div style="font-size:18px; font-weight:bold; color:#8b6914; margin-top:4px;">${_esc(c.score)}</div>
    </div>
  ''').join('');

  final originGrid = _buildOriginGrid(wine, alcohol);

  return '''<div class="page">
  <div class="border1"></div>
  <div class="border2"></div>

  <div style="text-align:center; margin-bottom:16px;">
    <div style="display:inline-flex; align-items:center; gap:20px;">
      <div style="height:1.5px; width:80px; background:#8b6914;"></div>
      <div style="font-size:9px; letter-spacing:5px; color:#8b6914;">FICHE DE COLLECTION</div>
      <div style="height:1.5px; width:80px; background:#8b6914;"></div>
    </div>
  </div>

  <div style="display:flex; align-items:center; gap:28px; margin-bottom:18px;">
    ${wine.photoUrl != null ? '<img src="${_esc(wine.photoUrl!)}" style="width:120px; height:180px; object-fit:contain;" crossorigin="anonymous">' : '<div style="width:120px;height:180px;background:#f0ead8;display:flex;align-items:center;justify-content:center;font-size:40px;color:#c9a96e;">🍷</div>'}
    <div style="flex:1;">
      <div style="font-size:${nameFontSize}px; font-weight:bold; line-height:1.1;">${_esc(wine.name)}</div>
      <div style="font-size:28px; font-weight:bold; color:#8b6914; margin-top:4px;">$vintage</div>
      <div style="font-size:14px; color:#666; margin-top:6px;">${_esc(wine.producer)} · $type · $format</div>
    </div>
  </div>

  <div style="height:2px; background:#8b6914; margin-bottom:16px;"></div>

  <div style="display:flex; align-items:flex-start; gap:28px; margin-bottom:18px;">
    <div style="flex:1;">
      <div style="font-size:10px; color:#8b6914; letter-spacing:3px; margin-bottom:8px;">ORIGINE</div>
      $originGrid
    </div>
    $grapesHtml
  </div>

  $timeline

  <div style="height:1.5px; background:linear-gradient(to right, #8b6914, transparent, #8b6914); margin-bottom:14px; margin-top:18px;"></div>

  <div style="display:flex; gap:28px; flex:1; min-height:0; margin-bottom:16px;">
    <div style="flex:1; display:flex; flex-direction:column; min-height:0;">
      <div style="font-size:10px; font-weight:bold; color:#8b6914; letter-spacing:3px; margin-bottom:8px;">NOTES DE DÉGUSTATION</div>
      <p style="font-size:11px; line-height:1.55; text-align:justify; overflow:hidden; flex:1; min-height:0;">${_esc(wine.wineDescription)}</p>
    </div>
    <div style="flex:1; display:flex; flex-direction:column; min-height:0;">
      <div style="font-size:10px; font-weight:bold; color:#8b6914; letter-spacing:3px; margin-bottom:8px;">LE DOMAINE</div>
      <p style="font-size:11px; line-height:1.55; text-align:justify; overflow:hidden; flex:1; min-height:0;">${_esc(wine.domaineDescription)}</p>
    </div>
  </div>

  <div style="border-top:2px solid #8b6914; padding-top:10px; flex-shrink:0;">
    <div style="font-size:9px; color:#8b6914; letter-spacing:3px; margin-bottom:8px; text-align:center;">CRITIQUES</div>
    <div style="display:flex; gap:10px;">
      $critiquesHtml
    </div>
  </div>
</div>''';
}

String _buildOriginGrid(Wine wine, String alcohol) {
  final fields = <(String, String)>[
    if (wine.country.isNotEmpty) ('Pays', wine.country),
    if (wine.region.isNotEmpty) ('Région', wine.region),
    if (wine.appellation.isNotEmpty) ('Appellation', wine.appellation),
    if (wine.village.isNotEmpty) ('Village', wine.village),
    if (wine.climat.isNotEmpty) ('Climat', wine.climat),
    if (wine.domaine.isNotEmpty) ('Domaine', wine.domaine),
    if (alcohol.isNotEmpty) ('Alcool', alcohol),
    if (wine.domainAddress.isNotEmpty) ('Adresse', wine.domainAddress),
  ];
  if (fields.isEmpty) return '';
  final rows = fields.map((f) => '''
    <span style="color:#8b6914; font-size:9px; letter-spacing:1px;">${f.$1}</span>
    <span style="color:#333;">${_esc(f.$2)}</span>
  ''').join('');
  return '<div style="display:grid; grid-template-columns:auto 1fr; gap:3px 12px; font-size:11px;">$rows</div>';
}

String _buildGrapesSection(String rawGrapes, String donutSvg, String legend) {
  if (rawGrapes.isEmpty) return '';
  if (donutSvg.isNotEmpty) {
    return '''<div style="text-align:center;">
      <div style="font-size:9px; color:#8b6914; letter-spacing:3px; margin-bottom:6px;">CÉPAGES</div>
      <div style="display:flex; align-items:center; gap:14px;">
        $donutSvg
        <div style="text-align:left;">$legend</div>
      </div>
    </div>''';
  }
  final items = rawGrapes.split(RegExp(r'[,;/]')).map((s) => s.trim()).where((s) => s.isNotEmpty);
  final listHtml = items.map((g) =>
    '<div style="font-size:10px; margin-bottom:3px; color:#333;">• ${_esc(g)}</div>'
  ).join('');
  return '''<div>
    <div style="font-size:9px; color:#8b6914; letter-spacing:3px; margin-bottom:6px;">CÉPAGES</div>
    $listHtml
  </div>''';
}

List<({String name, int pct})> _parseGrapes(String grapes) {
  if (grapes.isEmpty) return [];
  final parts = grapes.split(RegExp(r'[,;/\n]'));
  final result = <({String name, int pct})>[];
  for (final p in parts) {
    final trimmed = p.trim();
    if (trimmed.isEmpty) continue;
    final m1 = RegExp(r'(.+?)\s+(\d+)\s*%').firstMatch(trimmed);
    if (m1 != null) {
      result.add((name: m1.group(1)!.trim(), pct: int.parse(m1.group(2)!)));
      continue;
    }
    final m2 = RegExp(r'(\d+)\s*%\s+(.+)').firstMatch(trimmed);
    if (m2 != null) {
      result.add((name: m2.group(2)!.trim(), pct: int.parse(m2.group(1)!)));
      continue;
    }
    final m3 = RegExp(r'(.+?)\s*\((\d+)\s*%\)').firstMatch(trimmed);
    if (m3 != null) {
      result.add((name: m3.group(1)!.trim(), pct: int.parse(m3.group(2)!)));
      continue;
    }
    final m4 = RegExp(r'(.+?)\s*:\s*(\d+)\s*%').firstMatch(trimmed);
    if (m4 != null) {
      result.add((name: m4.group(1)!.trim(), pct: int.parse(m4.group(2)!)));
      continue;
    }
    final cleaned = trimmed.replaceAll(RegExp(r'\s*\d+%?\s*'), '').trim();
    result.add((name: cleaned.isNotEmpty ? cleaned : trimmed, pct: 0));
  }
  if (result.isNotEmpty && result.every((g) => g.pct == 0)) {
    final equal = (100 ~/ result.length);
    return [for (final g in result) (name: g.name, pct: equal)];
  }
  return result;
}

String _buildDonut(List<({String name, int pct})> grapes) {
  if (grapes.isEmpty) return '';
  final colors = ['#8b6914', '#c9a96e', '#e8d5a3', '#b8956b', '#d4c4a0'];
  const size = 90, cx = 45.0, cy = 45.0, r = 41.0, innerR = 21.0;
  var svg = '<svg width="$size" height="$size" viewBox="0 0 $size $size">';
  final total = grapes.fold<int>(0, (s, g) => s + g.pct);
  if (total == 0) return '';

  // Cas 1 cépage = anneau plein. Les arcs SVG ne dessinent rien quand
  // start == end ; on utilise deux cercles concentriques.
  final fullCircleIndex =
      grapes.indexWhere((g) => g.pct == total);
  if (grapes.length == 1 || fullCircleIndex >= 0) {
    final color = colors[(fullCircleIndex >= 0 ? fullCircleIndex : 0) %
        colors.length];
    svg +=
        '<circle cx="$cx" cy="$cy" r="$r" fill="$color"/>'
        '<circle cx="$cx" cy="$cy" r="$innerR" fill="#fffdf5"/>'
        '</svg>';
    return svg;
  }

  var startAngle = -90.0;
  for (var i = 0; i < grapes.length; i++) {
    final angle = (grapes[i].pct / total) * 360;
    if (angle <= 0) continue;
    final endAngle = startAngle + angle;
    final startRad = startAngle * 3.14159265 / 180;
    final endRad = endAngle * 3.14159265 / 180;
    final x1 = cx + r * _cos(startRad), y1 = cy + r * _sin(startRad);
    final x2 = cx + r * _cos(endRad), y2 = cy + r * _sin(endRad);
    final x3 = cx + innerR * _cos(endRad), y3 = cy + innerR * _sin(endRad);
    final x4 = cx + innerR * _cos(startRad), y4 = cy + innerR * _sin(startRad);
    final la = angle > 180 ? 1 : 0;
    final color = colors[i % colors.length];
    svg += '<path d="M${x1.toStringAsFixed(1)} ${y1.toStringAsFixed(1)} A$r $r 0 $la 1 ${x2.toStringAsFixed(1)} ${y2.toStringAsFixed(1)} L${x3.toStringAsFixed(1)} ${y3.toStringAsFixed(1)} A$innerR $innerR 0 $la 0 ${x4.toStringAsFixed(1)} ${y4.toStringAsFixed(1)}Z" fill="$color"/>';
    startAngle = endAngle;
  }
  svg += '</svg>';
  return svg;
}

String _buildLegend(List<({String name, int pct})> grapes) {
  if (grapes.isEmpty) return '';
  final colors = ['#8b6914', '#c9a96e', '#e8d5a3', '#b8956b', '#d4c4a0'];
  return grapes.asMap().entries.map((e) {
    final c = colors[e.key % colors.length];
    final g = e.value;
    return '<div style="display:flex; align-items:center; gap:6px; margin-bottom:4px;">'
        '<div style="width:10px;height:10px;border-radius:2px;background:$c;"></div>'
        '<span style="font-size:10px;">${_esc(g.name)} ${g.pct}%</span></div>';
  }).join('');
}

String _buildTimeline(int? from, int? peak, int? to) {
  if (from == null && peak == null && to == null) return '';
  final f = from ?? peak ?? to!;
  final t = to ?? peak ?? from!;
  final p = peak ?? ((f + t) ~/ 2);
  final pctPeak = t > f ? ((p - f) / (t - f) * 100).toStringAsFixed(0) : '50';

  return '''
  <div style="margin-bottom:18px;">
    <div style="font-size:9px; color:#8b6914; letter-spacing:3px; margin-bottom:10px; text-align:center;">FENÊTRE DE DÉGUSTATION</div>
    <div style="position:relative; height:36px; margin:0 30px;">
      <div style="position:absolute; top:16px; left:0; right:0; height:3px; background:linear-gradient(to right, #e8d5a3, #8b6914 $pctPeak%, #e8d5a3); border-radius:2px;"></div>
      <div style="position:absolute; top:8px; left:0; text-align:center;">
        <div style="width:18px;height:18px;border-radius:50%;background:#8b6914;margin:0 auto;"></div>
        <div style="font-size:12px; font-weight:bold; color:#8b6914; margin-top:6px;">$f</div>
        <div style="font-size:8px; color:#999;">Dès</div>
      </div>
      <div style="position:absolute; top:4px; left:calc($pctPeak% - 14px); text-align:center;">
        <div style="width:28px;height:28px;border-radius:50%;background:#c9a96e;border:3px solid #8b6914;margin:0 auto;"></div>
        <div style="font-size:14px; font-weight:bold; color:#8b6914; margin-top:6px;">$p</div>
        <div style="font-size:8px; color:#999;">Apogée</div>
      </div>
      <div style="position:absolute; top:8px; right:0; text-align:center;">
        <div style="width:18px;height:18px;border-radius:50%;background:#8b6914;margin:0 auto;"></div>
        <div style="font-size:12px; font-weight:bold; color:#8b6914; margin-top:6px;">$t</div>
        <div style="font-size:8px; color:#999;">Avant</div>
      </div>
    </div>
  </div>''';
}

double _cos(double rad) => math.cos(rad);
double _sin(double rad) => math.sin(rad);

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
