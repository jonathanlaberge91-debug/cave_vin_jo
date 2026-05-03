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

String _buildHtml(Wine wine, List<Bottle> bottles) {
  final vintage = wine.vintage != null ? '${wine.vintage}' : '';
  final type = wineTypeLabel(wine.type);
  final format = bottles.isNotEmpty ? bottles.first.format.label : '750 ML';
  final alcohol = wine.alcohol != null ? '${wine.alcohol!.toStringAsFixed(1)}%' : '';
  final rating = wine.rating ?? 0;

  final grapeParts = _parseGrapes(wine.grapes);
  final donutSvg = _buildDonut(grapeParts);
  final legend = _buildLegend(grapeParts);
  final timeline = _buildTimeline(wine.drinkFrom, wine.drinkPeak, wine.drinkTo);

  final critiquesHtml = wine.critiques.map((c) => '''
    <div style="flex:1; border:1.5px solid #8b6914; padding:10px; text-align:center;">
      <div style="font-size:11px; color:#555;">${_esc(c.source)}</div>
      <div style="font-size:20px; font-weight:bold; color:#8b6914; margin-top:4px;">${_esc(c.score)}</div>
    </div>
  ''').join('');

  final originGrid = _buildOriginGrid(wine, alcohol);

  return '''<!DOCTYPE html>
<html lang="fr">
<head>
<meta charset="UTF-8">
<title>${_esc(wine.name)} $vintage – Fiche</title>
<style>
@page { size: A4; margin: 0; }
* { margin:0; padding:0; box-sizing:border-box; }
body { width:210mm; height:297mm; font-family: 'Didot', 'Bodoni MT', Georgia, serif; color:#1a1a1a; background:#fffdf5; }
.page { width:210mm; height:297mm; padding:40px 48px; position:relative; display:flex; flex-direction:column; }
.border1 { position:absolute;top:18px;left:18px;right:18px;bottom:18px;border:1px solid #c9a96e;pointer-events:none; }
.border2 { position:absolute;top:22px;left:22px;right:22px;bottom:22px;border:1px solid #8b6914;pointer-events:none; }
@media print {
  body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
}
</style>
</head>
<body>
<div class="page">
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
      <div style="font-size:40px; font-weight:bold; line-height:1.1;">${_esc(wine.name)}</div>
      <div style="font-size:28px; font-weight:bold; color:#8b6914; margin-top:4px;">$vintage</div>
      <div style="font-size:14px; color:#666; margin-top:6px;">${_esc(wine.producer)} · $type · $format</div>
    </div>
    <div style="text-align:center;">
      <div style="font-size:52px; font-weight:bold; color:#8b6914; line-height:1;">$rating</div>
      <div style="font-size:10px; color:#999; letter-spacing:2px;">/100</div>
    </div>
  </div>

  <div style="height:2px; background:#8b6914; margin-bottom:16px;"></div>

  <div style="display:flex; align-items:flex-start; gap:28px; margin-bottom:18px;">
    <div style="flex:1;">
      <div style="font-size:10px; color:#8b6914; letter-spacing:3px; margin-bottom:8px;">ORIGINE</div>
      $originGrid
    </div>
    <div style="text-align:center;">
      <div style="font-size:9px; color:#8b6914; letter-spacing:3px; margin-bottom:6px;">CÉPAGES</div>
      <div style="display:flex; align-items:center; gap:14px;">
        $donutSvg
        <div style="text-align:left;">$legend</div>
      </div>
    </div>
  </div>

  $timeline

  <div style="height:1.5px; background:linear-gradient(to right, #8b6914, transparent, #8b6914); margin-bottom:16px; margin-top:24px;"></div>

  <div style="display:flex; gap:28px; flex:1; margin-bottom:16px;">
    <div style="flex:1;">
      <div style="font-size:10px; font-weight:bold; color:#8b6914; letter-spacing:3px; margin-bottom:8px;">NOTES DE DÉGUSTATION</div>
      <p style="font-size:11.5px; line-height:1.6; text-align:justify;">${_esc(wine.wineDescription)}</p>
    </div>
    <div style="flex:1;">
      <div style="font-size:10px; font-weight:bold; color:#8b6914; letter-spacing:3px; margin-bottom:8px;">LE DOMAINE</div>
      <p style="font-size:11.5px; line-height:1.6; text-align:justify;">${_esc(wine.domaineDescription)}</p>
    </div>
  </div>

  <div style="border-top:2px solid #8b6914; padding-top:14px;">
    <div style="font-size:9px; color:#8b6914; letter-spacing:3px; margin-bottom:10px; text-align:center;">CRITIQUES</div>
    <div style="display:flex; gap:10px;">
      $critiquesHtml
    </div>
  </div>
</div>
</body>
</html>''';
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

List<({String name, int pct})> _parseGrapes(String grapes) {
  if (grapes.isEmpty) return [];
  final parts = grapes.split(RegExp(r'[,;]'));
  final result = <({String name, int pct})>[];
  for (final p in parts) {
    final m = RegExp(r'(.+?)\s+(\d+)\s*%').firstMatch(p.trim());
    if (m != null) {
      result.add((name: m.group(1)!.trim(), pct: int.parse(m.group(2)!)));
    } else {
      result.add((name: p.trim(), pct: 0));
    }
  }
  return result;
}

String _buildDonut(List<({String name, int pct})> grapes) {
  if (grapes.isEmpty) return '';
  final colors = ['#8b6914', '#c9a96e', '#e8d5a3', '#b8956b', '#d4c4a0'];
  const size = 90, cx = 45.0, cy = 45.0, r = 41.0, innerR = 21.0;
  var svg = '<svg width="$size" height="$size" viewBox="0 0 $size $size">';
  var startAngle = -90.0;
  final total = grapes.fold<int>(0, (s, g) => s + g.pct);
  if (total == 0) return '';
  for (var i = 0; i < grapes.length; i++) {
    final angle = (grapes[i].pct / total) * 360;
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
