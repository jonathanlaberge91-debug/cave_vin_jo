import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../models/stat_item.dart';
import '../services/cave_service.dart';
import '../services/cave_preferences_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/country_helpers.dart';
import '../theme/wine_type_helpers.dart';
import '../widgets/cave_table.dart' show GardeInfo;

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Wine>>(
      stream: CaveService.wines(),
      builder: (context, wineSnap) {
        return StreamBuilder<List<Bottle>>(
          stream: CaveService.bottlesInCave(),
          builder: (context, caveSnap) {
            return StreamBuilder<List<Bottle>>(
              stream: CaveService.bottlesDrunk(),
              builder: (context, drunkSnap) {
                if (!wineSnap.hasData || !caveSnap.hasData || !drunkSnap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  );
                }
                final wines = {for (final w in wineSnap.data!) w.id: w};
                final cave = caveSnap.data!;
                final drunk = drunkSnap.data!;
                final all = [...cave, ...drunk];
                return _StatsBody(wines: wines, cave: cave, drunk: drunk, all: all);
              },
            );
          },
        );
      },
    );
  }
}

class _StatsBody extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  final List<Bottle> drunk;
  final List<Bottle> all;

  const _StatsBody({
    required this.wines,
    required this.cave,
    required this.drunk,
    required this.all,
  });

  Widget _buildStat(StatItem item, Map<StatItem, StatChartType> chartTypes) {
    final type = chartTypes[item] ?? item.chartType;
    switch (item) {
      case StatItem.valeurTotale:
        return _ValeurTotaleCard(cave: cave);
      case StatItem.diversiteStreak:
        return _DiversiteStreakRow(wines: wines, cave: cave, drunk: drunk);
      case StatItem.typeDonut:
        final data = _countByWineType(cave);
        if (type == StatChartType.barresH) {
          return _HorizontalBarCard(title: 'Répartition par type', data: data, barColor: AppColors.gold);
        }
        return _TypeDonutCard(wines: wines, cave: cave);
      case StatItem.gardeDonut:
        if (type == StatChartType.barresH) {
          return _GardeBarCard(wines: wines, cave: cave);
        }
        return _GardeDonutCard(wines: wines, cave: cave);
      case StatItem.acquisitionVsConsommation:
        if (type == StatChartType.barres) {
          return _AcquisitionVsConsommationBarCard(cave: cave, drunk: drunk, all: all);
        }
        return _AcquisitionVsConsommationCard(cave: cave, drunk: drunk, all: all);
      case StatItem.ajouteesParMois:
        if (type == StatChartType.ligne) {
          return _BottlesPerMonthLineCard(bottles: all, title: 'Bouteilles ajoutées / mois', useCreatedAt: true);
        }
        return _BottlesPerMonthCard(bottles: all, title: 'Bouteilles ajoutées / mois', useCreatedAt: true);
      case StatItem.buesParMois:
        if (type == StatChartType.ligne) {
          return _BottlesPerMonthLineCard(bottles: drunk, title: 'Bouteilles bues / mois', useCreatedAt: false);
        }
        return _BottlesPerMonthCard(bottles: drunk, title: 'Bouteilles bues / mois', useCreatedAt: false);
      case StatItem.parPays:
        final data = _countByField(cave, (b) => wines[b.wineId]?.country ?? '');
        if (type == StatChartType.donut) {
          return _GenericDonutCard(title: 'Bouteilles par pays', data: data);
        }
        return _HorizontalBarCard(title: 'Bouteilles par pays', data: data, barColor: AppColors.gold);
      case StatItem.carteMonde:
        return _CarteMondeCard(wines: wines, cave: cave);
      case StatItem.parRegion:
        final data = _countByField(cave, (b) => wines[b.wineId]?.region ?? '');
        if (type == StatChartType.donut) {
          return _GenericDonutCard(title: 'Bouteilles par région', data: data);
        }
        return _HorizontalBarCard(title: 'Bouteilles par région', data: data, barColor: const Color(0xFF7CD492));
      case StatItem.parAppellation:
        final data = _countByField(cave, (b) => wines[b.wineId]?.appellation ?? '');
        if (type == StatChartType.donut) {
          return _GenericDonutCard(title: 'Bouteilles par appellation', data: data);
        }
        return _HorizontalBarCard(title: 'Bouteilles par appellation', data: data, barColor: const Color(0xFF70B8E8), showAll: true);
      case StatItem.topDomaines:
        final data = _countByField(cave, (b) => wines[b.wineId]?.domaine ?? '');
        if (type == StatChartType.donut) {
          return _GenericDonutCard(title: 'Top domaines', data: data);
        }
        return _HorizontalBarCard(title: 'Top domaines', data: data, barColor: const Color(0xFFC490F0));
      case StatItem.plusValue:
        if (type == StatChartType.ligne) {
          return _PlusValueLineCard(wines: wines, cave: cave);
        }
        return _PlusValueCard(wines: wines, cave: cave);
      case StatItem.distributionPrix:
        if (type == StatChartType.ligne) {
          return _PrixDistributionLineCard(cave: cave);
        }
        return _PrixDistributionCard(cave: cave);
      case StatItem.maturiteCalendrier:
        if (type == StatChartType.barres) {
          return _MaturiteBarCard(wines: wines, cave: cave);
        }
        return _MaturiteCalendarCard(wines: wines, cave: cave);
      case StatItem.distributionMillesimes:
        if (type == StatChartType.ligne) {
          return _VintageDistributionLineCard(wines: wines, cave: cave);
        }
        if (type == StatChartType.donut) {
          return _VintageDistributionDonutCard(wines: wines, cave: cave);
        }
        return _VintageDistributionCard(wines: wines, cave: cave);
      case StatItem.cepagesDonut:
        if (type == StatChartType.barresH) {
          return _CepageBarCard(wines: wines, cave: cave);
        }
        return _CepageDonutCard(wines: wines, cave: cave);
      case StatItem.cepagesPart:
        return _CepagePartDonutCard(wines: wines, cave: cave);
      case StatItem.distributionCamembert:
        return _DistributionCamembertCard(wines: wines, cave: cave);
    }
  }

  Map<String, int> _countByWineType(List<Bottle> bottles) {
    final map = <String, int>{};
    for (final b in bottles) {
      final w = wines[b.wineId];
      if (w == null) continue;
      final label = wineTypeLabel(w.type);
      map[label] = (map[label] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<List<StatItem>>>(
      valueListenable: CavePreferencesService.statsLayout,
      builder: (context, layout, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: CavePreferencesService.statsHidePrices,
          builder: (context, hidePrices, _) {
            return ValueListenableBuilder<Map<StatItem, StatChartType>>(
              valueListenable: CavePreferencesService.statsChartTypes,
              builder: (context, chartTypes, _) {
                final widgets = <Widget>[];
                for (final row in layout) {
                  final visibleRow = hidePrices
                      ? row.where((s) => !s.isPriceRelated).toList()
                      : row;
                  if (visibleRow.isEmpty) continue;
                  if (visibleRow.length == 1) {
                    widgets.add(_buildStat(visibleRow.first, chartTypes));
                  } else {
                    widgets.add(_Row2(children: [
                      for (var i = 0; i < visibleRow.length; i++) ...[
                        Expanded(child: _buildStat(visibleRow[i], chartTypes)),
                        if (i < visibleRow.length - 1) const SizedBox(width: 16),
                      ],
                    ]));
                  }
                }

                final mobile = MediaQuery.of(context).size.width < 600;
                return ListView(
                  padding: EdgeInsets.fromLTRB(mobile ? 12 : 24, 24, mobile ? 12 : 24, 24),
                  children: [
                    Text(
                      'Statistiques',
                      style: AppText.serif(
                        color: AppColors.gold2,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (var j = 0; j < widgets.length; j++) ...[
                      widgets[j],
                      if (j < widgets.length - 1) const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 40),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Map<String, int> _countByField(List<Bottle> bottles, String Function(Bottle) field) {
    final map = <String, int>{};
    for (final b in bottles) {
      final key = field(b);
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }
}

class _Row2 extends StatelessWidget {
  final List<Widget> children;
  const _Row2({required this.children});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 800;
    if (wide) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    return Column(
      children: children.where((c) => c is! SizedBox).map((c) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: c is Expanded ? c.child : c,
        );
      }).toList(),
    );
  }
}

// ── Card wrapper ──
class _StatCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double? height;
  const _StatCard({required this.title, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Text(
              title.toUpperCase(),
              style: AppText.sans(
                color: AppColors.text3,
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(height: 1, color: AppColors.border),
          Expanded(child: Padding(padding: const EdgeInsets.all(18), child: child)),
        ],
      ),
    );
  }
}

// ── 1. Valeur totale ──
class _ValeurTotaleCard extends StatelessWidget {
  final List<Bottle> cave;
  const _ValeurTotaleCard({required this.cave});

  @override
  Widget build(BuildContext context) {
    double totalAchat = 0, totalMarche = 0;
    for (final b in cave) {
      totalAchat += b.purchasePrice ?? 0;
      totalMarche += b.marketValue ?? b.purchasePrice ?? 0;
    }
    final diff = totalMarche - totalAchat;
    final pct = totalAchat > 0 ? (diff / totalAchat * 100) : 0.0;
    final positive = diff >= 0;

    final isMobile = MediaQuery.of(context).size.width < 600;
    final heroSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VALEUR DE LA CAVE',
            style: AppText.sans(color: AppColors.text3, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text('${totalMarche.toStringAsFixed(0)} \$',
            style: AppText.serif(color: AppColors.gold2, fontSize: isMobile ? 28 : 36, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('valeur marchande estimée', style: AppText.sans(color: AppColors.text3, fontSize: 12)),
      ],
    );
    final detailSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _valLine('Prix d\'achat', '${totalAchat.toStringAsFixed(0)} \$', AppColors.text2),
        const SizedBox(height: 8),
        _valLine('Valeur marché', '${totalMarche.toStringAsFixed(0)} \$', AppColors.gold2),
        const SizedBox(height: 8),
        _valLine(
          'Plus-value',
          '${positive ? '+' : ''}${diff.toStringAsFixed(0)} \$ (${pct.toStringAsFixed(1)}%)',
          positive ? const Color(0xFF7CD492) : const Color(0xFFE8667A),
        ),
        const SizedBox(height: 8),
        _valLine('Bouteilles', '${cave.length}', AppColors.text),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heroSection, const SizedBox(height: 20), detailSection],
            )
          : Row(
              children: [
                Expanded(child: heroSection),
                Container(width: 1, height: 80, color: AppColors.border),
                const SizedBox(width: 24),
                Expanded(child: detailSection),
              ],
            ),
    );
  }

  Widget _valLine(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppText.sans(color: AppColors.text3, fontSize: 12)),
        Text(value, style: AppText.sans(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── 24 & 25. Diversité + Streak ──
class _DiversiteStreakRow extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  final List<Bottle> drunk;
  const _DiversiteStreakRow({required this.wines, required this.cave, required this.drunk});

  @override
  Widget build(BuildContext context) {
    final countries = <String>{};
    final regions = <String>{};
    final appellations = <String>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null) continue;
      if (w.country.isNotEmpty) countries.add(w.country);
      if (w.region.isNotEmpty) regions.add(w.region);
      if (w.appellation.isNotEmpty) appellations.add(w.appellation);
    }

    int streak = 0;
    if (drunk.isNotEmpty) {
      final dates = drunk
          .map((b) => b.drunkAt)
          .whereType<DateTime>()
          .map((d) => DateTime(d.year, d.month, d.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      if (dates.isEmpty || dates.first != today) {
        var check = today;
        while (!dates.contains(check)) {
          streak++;
          check = check.subtract(const Duration(days: 1));
          if (streak > 365 || !dates.contains(check)) break;
        }
        if (!dates.contains(check) && streak > 0) {
          // never drank
        }
      }
      // calculate consecutive days WITHOUT drinking
      streak = 0;
      var day = today;
      final dateSet = dates.toSet();
      while (!dateSet.contains(day)) {
        streak++;
        day = day.subtract(const Duration(days: 1));
        if (streak > 999) break;
      }
    }

    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      return Column(
        children: [
          Row(children: [
            _counterTile(Icons.wine_bar_outlined, '${cave.length}', 'Bouteilles', AppColors.text),
            const SizedBox(width: 10),
            _counterTile(Icons.public_outlined, '${countries.length}', 'Pays', const Color(0xFF70B8E8)),
            const SizedBox(width: 10),
            _counterTile(Icons.terrain_outlined, '${regions.length}', 'Régions', const Color(0xFF7CD492)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _counterTile(Icons.label_outlined, '${appellations.length}', 'Appellations', AppColors.gold2),
            const SizedBox(width: 10),
            _counterTile(Icons.local_fire_department_outlined, '$streak j', 'Sans ouvrir', const Color(0xFFE8667A)),
          ]),
        ],
      );
    }
    return Row(
      children: [
        _counterTile(Icons.wine_bar_outlined, '${cave.length}', 'Bouteilles', AppColors.text),
        const SizedBox(width: 12),
        _counterTile(Icons.public_outlined, '${countries.length}', 'Pays', const Color(0xFF70B8E8)),
        const SizedBox(width: 12),
        _counterTile(Icons.terrain_outlined, '${regions.length}', 'Régions', const Color(0xFF7CD492)),
        const SizedBox(width: 12),
        _counterTile(Icons.label_outlined, '${appellations.length}', 'Appellations', AppColors.gold2),
        const SizedBox(width: 12),
        _counterTile(Icons.local_fire_department_outlined, '$streak j', 'Sans ouvrir', const Color(0xFFE8667A)),
      ],
    );
  }

  Widget _counterTile(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: AppText.serif(color: color, fontSize: 28, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(label,
                style: AppText.sans(color: AppColors.text3, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── 2. Donut par type ──
class _TypeDonutCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _TypeDonutCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final counts = <WineType, int>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null) continue;
      counts[w.type] = (counts[w.type] ?? 0) + 1;
    }
    final total = cave.length;
    final sections = WineType.values
        .where((t) => (counts[t] ?? 0) > 0)
        .map((t) {
      final c = counts[t]!;
      return PieChartSectionData(
        value: c.toDouble(),
        title: '$c',
        color: wineTypeColor(t),
        radius: 38,
        titleStyle: AppText.sans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
      );
    }).toList();

    final isMobile = MediaQuery.of(context).size.width < 600;
    final legend = WineType.values.where((t) => (counts[t] ?? 0) > 0).map((t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: wineTypeColor(t), shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('${wineTypeLabel(t)} (${counts[t]})', style: AppText.sans(color: AppColors.text2, fontSize: 11)),
      ]),
    )).toList();
    final chart = PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2));

    if (isMobile) {
      return SizedBox(
        height: 360,
        child: _StatCard(
          title: 'Répartition par type ($total)',
          child: Column(children: [
            SizedBox(height: 180, child: chart),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 4, children: legend),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 300,
      child: _StatCard(
        title: 'Répartition par type ($total)',
        child: Row(children: [
          Expanded(child: chart),
          const SizedBox(width: 16),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: legend),
        ]),
      ),
    );
  }
}

// ── 15. Garde donut ──
class _GardeDonutCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _GardeDonutCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    int aBoire = 0, garde = 0, apogee = 0, passe = 0, inconnu = 0;
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null) { inconnu++; continue; }
      final g = GardeInfo.fromWine(w);
      if (g == null) { inconnu++; continue; }
      switch (g.label) {
        case 'À boire': aBoire++;
        case 'Garde': garde++;
        case 'Apogée': apogee++;
        case 'Passé': passe++;
        default: inconnu++;
      }
    }

    final items = <(String, int, Color)>[
      ('Apogée', apogee, const Color(0xFFF5D060)),
      ('À boire', aBoire, const Color(0xFF2E7D32)),
      ('Garde', garde, const Color(0xFF546E7A)),
      ('Passé', passe, const Color(0xFFC62828)),
      ('Inconnu', inconnu, AppColors.text3),
    ].where((e) => e.$2 > 0).toList();

    final sections = items.map((e) => PieChartSectionData(
      value: e.$2.toDouble(),
      title: '${e.$2}',
      color: e.$3,
      radius: 38,
      titleStyle: AppText.sans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
    )).toList();

    final isMobile = MediaQuery.of(context).size.width < 600;
    final legend = items.map((e) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: e.$3, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('${e.$1} (${e.$2})', style: AppText.sans(color: AppColors.text2, fontSize: 11)),
      ]),
    )).toList();
    final chart = PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2));

    if (isMobile) {
      return SizedBox(
        height: 340,
        child: _StatCard(
          title: 'Fenêtre de garde',
          child: Column(children: [
            SizedBox(height: 180, child: chart),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 4, children: legend),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 300,
      child: _StatCard(
        title: 'Fenêtre de garde',
        child: Row(children: [
          Expanded(child: chart),
          const SizedBox(width: 16),
          Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: legend),
        ]),
      ),
    );
  }
}

// ── 5. Acquisition vs Consommation (ligne double) ──
class _AcquisitionVsConsommationCard extends StatelessWidget {
  final List<Bottle> cave;
  final List<Bottle> drunk;
  final List<Bottle> all;
  const _AcquisitionVsConsommationCard({required this.cave, required this.drunk, required this.all});

  @override
  Widget build(BuildContext context) {
    final addedByMonth = <String, int>{};
    final drunkByMonth = <String, int>{};

    for (final b in all) {
      final d = b.createdAt;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      addedByMonth[key] = (addedByMonth[key] ?? 0) + 1;
    }
    for (final b in drunk) {
      final d = b.drunkAt ?? b.createdAt;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      drunkByMonth[key] = (drunkByMonth[key] ?? 0) + 1;
    }

    final allKeys = {...addedByMonth.keys, ...drunkByMonth.keys}.toList()..sort();
    if (allKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    final addedSpots = <FlSpot>[];
    final drunkSpots = <FlSpot>[];
    for (var i = 0; i < allKeys.length; i++) {
      addedSpots.add(FlSpot(i.toDouble(), (addedByMonth[allKeys[i]] ?? 0).toDouble()));
      drunkSpots.add(FlSpot(i.toDouble(), (drunkByMonth[allKeys[i]] ?? 0).toDouble()));
    }

    final maxY = [...addedSpots, ...drunkSpots].map((s) => s.y).reduce(max);

    return SizedBox(
      height: 300,
      child: _StatCard(
        title: 'Acquisition vs consommation',
        child: LineChart(LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1, (maxY / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: max(1, (allKeys.length / 6).ceilToDouble()),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= allKeys.length) return const SizedBox.shrink();
                  final parts = allKeys[i].split('-');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${parts[1]}/${parts[0].substring(2)}',
                        style: AppText.sans(color: AppColors.text3, fontSize: 9)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: max(1, (maxY / 4).ceilToDouble()),
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: AppText.sans(color: AppColors.text3, fontSize: 10)),
              ),
            ),
          ),
          minY: 0,
          maxY: maxY + 1,
          lineBarsData: [
            LineChartBarData(
              spots: addedSpots,
              isCurved: true,
              color: AppColors.gold,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: AppColors.gold.withValues(alpha: 0.1)),
            ),
            LineChartBarData(
              spots: drunkSpots,
              isCurved: true,
              color: const Color(0xFFE8667A),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: const Color(0xFFE8667A).withValues(alpha: 0.1)),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.bg3,
            ),
          ),
        )),
      ),
    );
  }
}

// ── 3 & 4. Bottles per month bar chart ──
class _BottlesPerMonthCard extends StatelessWidget {
  final List<Bottle> bottles;
  final String title;
  final bool useCreatedAt;
  const _BottlesPerMonthCard({required this.bottles, required this.title, required this.useCreatedAt});

  @override
  Widget build(BuildContext context) {
    final byMonth = <String, int>{};
    for (final b in bottles) {
      final d = useCreatedAt ? b.createdAt : (b.drunkAt ?? b.createdAt);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + 1;
    }
    final keys = byMonth.keys.toList()..sort();
    if (keys.isEmpty) return SizedBox(height: 280, child: _StatCard(title: title, child: const Center(child: Text('Aucune donnée', style: TextStyle(color: AppColors.text3)))));

    final maxVal = byMonth.values.reduce(max).toDouble();

    return SizedBox(
      height: 280,
      child: _StatCard(
        title: title,
        child: BarChart(BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                  final parts = keys[i].split('-');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${parts[1]}/${parts[0].substring(2)}',
                        style: AppText.sans(color: AppColors.text3, fontSize: 9)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: max(1, (maxVal / 4).ceilToDouble()),
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: AppText.sans(color: AppColors.text3, fontSize: 10)),
              ),
            ),
          ),
          maxY: maxVal + 1,
          barGroups: List.generate(keys.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: byMonth[keys[i]]!.toDouble(),
                color: useCreatedAt ? AppColors.gold : const Color(0xFFE8667A),
                width: max(4, 200 / keys.length),
                borderRadius: BorderRadius.circular(3),
              ),
            ]);
          }),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.bg3,
              getTooltipItem: (group, _, rod, __) {
                final k = keys[group.x];
                return BarTooltipItem('$k\n${rod.toY.toInt()}',
                    AppText.sans(color: AppColors.text, fontSize: 11));
              },
            ),
          ),
        )),
      ),
    );
  }
}

// ── 6/7/8/9. Horizontal bar chart ──
class _HorizontalBarCard extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  final Color barColor;
  final bool showAll;
  const _HorizontalBarCard({required this.title, required this.data, required this.barColor, this.showAll = false});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    var sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (!showAll && sorted.length > 15) sorted = sorted.sublist(0, 15);
    final maxVal = sorted.first.value;
    final labelW = MediaQuery.of(context).size.width < 600 ? 90.0 : 140.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Text(title.toUpperCase(),
                style: AppText.sans(color: AppColors.text3, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
          ),
          Container(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: sorted.map((e) {
                final pct = e.value / maxVal;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: labelW,
                        child: Text(e.key,
                            style: AppText.sans(color: AppColors.text2, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.bg3,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct,
                              child: Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  color: barColor.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: barColor.withValues(alpha: 0.3)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 30,
                        child: Text('${e.value}',
                            style: AppText.sans(color: barColor, fontSize: 12, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 11. Plus-value ──
class _PlusValueCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _PlusValueCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final byWine = <String, (double achat, double marche, String name)>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null) continue;
      final a = b.purchasePrice ?? 0;
      final m = b.marketValue ?? b.purchasePrice ?? 0;
      if (a <= 0 && m <= 0) continue;
      final prev = byWine[b.wineId];
      if (prev != null) {
        byWine[b.wineId] = (prev.$1 + a, prev.$2 + m, w.name);
      } else {
        byWine[b.wineId] = (a, m, w.name);
      }
    }

    var sorted = byWine.entries.toList()
      ..sort((a, b) => (b.value.$2 - b.value.$1).compareTo(a.value.$2 - a.value.$1));
    if (sorted.length > 12) sorted = sorted.sublist(0, 12);
    if (sorted.isEmpty) return const SizedBox.shrink();

    final maxVal = sorted.map((e) => max(e.value.$1, e.value.$2)).reduce(max);

    return SizedBox(
      height: 320,
      child: _StatCard(
        title: 'Plus-value (achat vs marché)',
        child: BarChart(BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        sorted[i].value.$3.length > 14
                            ? '${sorted[i].value.$3.substring(0, 14)}…'
                            : sorted[i].value.$3,
                        style: AppText.sans(color: AppColors.text3, fontSize: 9),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: max(1, (maxVal / 4).ceilToDouble()),
                getTitlesWidget: (v, _) => Text('${v.toInt()} \$',
                    style: AppText.sans(color: AppColors.text3, fontSize: 9)),
              ),
            ),
          ),
          maxY: maxVal + maxVal * 0.1,
          barGroups: List.generate(sorted.length, (i) {
            final e = sorted[i];
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: e.value.$1,
                color: AppColors.text3,
                width: 10,
                borderRadius: BorderRadius.circular(3),
              ),
              BarChartRodData(
                toY: e.value.$2,
                color: AppColors.gold,
                width: 10,
                borderRadius: BorderRadius.circular(3),
              ),
            ]);
          }),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.bg3,
              getTooltipItem: (group, gIdx, rod, rIdx) {
                final e = sorted[group.x];
                final label = rIdx == 0 ? 'Achat' : 'Marché';
                return BarTooltipItem('${e.value.$3}\n$label: ${rod.toY.toStringAsFixed(0)} \$',
                    AppText.sans(color: AppColors.text, fontSize: 11));
              },
            ),
          ),
        )),
      ),
    );
  }
}

// ── 13. Distribution des prix ──
class _PrixDistributionCard extends StatelessWidget {
  final List<Bottle> cave;
  const _PrixDistributionCard({required this.cave});

  @override
  Widget build(BuildContext context) {
    final ranges = <String, int>{
      '0-25': 0, '25-50': 0, '50-100': 0, '100-200': 0, '200-500': 0, '500+': 0,
    };
    for (final b in cave) {
      final p = b.purchasePrice ?? b.marketValue;
      if (p == null) continue;
      if (p < 25) ranges['0-25'] = ranges['0-25']! + 1;
      else if (p < 50) ranges['25-50'] = ranges['25-50']! + 1;
      else if (p < 100) ranges['50-100'] = ranges['50-100']! + 1;
      else if (p < 200) ranges['100-200'] = ranges['100-200']! + 1;
      else if (p < 500) ranges['200-500'] = ranges['200-500']! + 1;
      else ranges['500+'] = ranges['500+']! + 1;
    }

    final filtered = ranges.entries.where((e) => e.value > 0).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    final maxVal = filtered.map((e) => e.value).reduce(max).toDouble();
    final colors = [
      const Color(0xFF546E7A),
      const Color(0xFF7CD492),
      AppColors.gold,
      const Color(0xFFE08A3C),
      const Color(0xFFE8667A),
      const Color(0xFFC490F0),
    ];

    return SizedBox(
      height: 280,
      child: _StatCard(
        title: 'Distribution des prix (\$)',
        child: BarChart(BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= filtered.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${filtered[i].key} \$',
                        style: AppText.sans(color: AppColors.text3, fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: max(1, (maxVal / 4).ceilToDouble()),
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: AppText.sans(color: AppColors.text3, fontSize: 10)),
              ),
            ),
          ),
          maxY: maxVal + 1,
          barGroups: List.generate(filtered.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: filtered[i].value.toDouble(),
                color: colors[ranges.keys.toList().indexOf(filtered[i].key) % colors.length],
                width: 36,
                borderRadius: BorderRadius.circular(4),
              ),
            ]);
          }),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.bg3,
              getTooltipItem: (group, _, rod, __) {
                return BarTooltipItem('${filtered[group.x].key} \$\n${rod.toY.toInt()} bouteilles',
                    AppText.sans(color: AppColors.text, fontSize: 11));
              },
            ),
          ),
        )),
      ),
    );
  }
}

// ── 16. Calendrier de maturité ──
class _MaturiteCalendarCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _MaturiteCalendarCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final byYear = <int, int>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null || w.drinkFrom == null) continue;
      final year = w.drinkFrom!;
      byYear[year] = (byYear[year] ?? 0) + 1;
    }
    if (byYear.isEmpty) return const SizedBox.shrink();

    final years = byYear.keys.toList()..sort();
    final minYear = years.first;
    final maxYear = years.last;
    final allYears = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    final maxVal = byYear.values.reduce(max).toDouble();
    final now = DateTime.now().year;

    final spots = allYears.map((y) {
      return FlSpot((y - minYear).toDouble(), (byYear[y] ?? 0).toDouble());
    }).toList();

    return SizedBox(
      height: 280,
      child: _StatCard(
        title: 'Calendrier de maturité (prêtes à boire par année)',
        child: LineChart(LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: max(1, (allYears.length / 8).ceilToDouble()),
                getTitlesWidget: (v, _) {
                  final year = minYear + v.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('$year',
                        style: AppText.sans(
                          color: year == now ? AppColors.gold2 : AppColors.text3,
                          fontSize: 10,
                          fontWeight: year == now ? FontWeight.w700 : FontWeight.w400,
                        )),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: max(1, (maxVal / 4).ceilToDouble()),
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: AppText.sans(color: AppColors.text3, fontSize: 10)),
              ),
            ),
          ),
          minY: 0,
          maxY: maxVal + 1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF7CD492),
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF7CD492).withValues(alpha: 0.12)),
            ),
          ],
          extraLinesData: ExtraLinesData(verticalLines: [
            VerticalLine(
              x: (now - minYear).toDouble(),
              color: AppColors.gold.withValues(alpha: 0.5),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ]),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.bg3,
            ),
          ),
        )),
      ),
    );
  }
}

// ── 17. Distribution des millésimes ──
class _VintageDistributionCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _VintageDistributionCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final byVintage = <int, int>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null || w.vintage == null) continue;
      byVintage[w.vintage!] = (byVintage[w.vintage!] ?? 0) + 1;
    }
    if (byVintage.isEmpty) return const SizedBox.shrink();

    final years = byVintage.keys.toList()..sort();
    final maxVal = byVintage.values.reduce(max).toDouble();

    return SizedBox(
      height: 280,
      child: _StatCard(
        title: 'Distribution des millésimes',
        child: BarChart(BarChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: max(1, (years.length / 10).ceilToDouble()),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= years.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('${years[i]}',
                        style: AppText.sans(color: AppColors.text3, fontSize: 9)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: max(1, (maxVal / 4).ceilToDouble()),
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: AppText.sans(color: AppColors.text3, fontSize: 10)),
              ),
            ),
          ),
          maxY: maxVal + 1,
          barGroups: List.generate(years.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: byVintage[years[i]]!.toDouble(),
                color: AppColors.gold,
                width: max(4, 300 / years.length),
                borderRadius: BorderRadius.circular(3),
              ),
            ]);
          }),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.bg3,
              getTooltipItem: (group, _, rod, __) {
                return BarTooltipItem('${years[group.x]}\n${rod.toY.toInt()} bouteilles',
                    AppText.sans(color: AppColors.text, fontSize: 11));
              },
            ),
          ),
        )),
      ),
    );
  }
}

// ── Generic donut for categorical data ──
class _GenericDonutCard extends StatelessWidget {
  final String title;
  final Map<String, int> data;
  const _GenericDonutCard({required this.title, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final sorted = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(8).toList();
    final total = data.values.fold<int>(0, (s, v) => s + v);
    final palette = [
      AppColors.gold, const Color(0xFF7CD492), const Color(0xFF70B8E8),
      const Color(0xFFC490F0), const Color(0xFFE8667A), const Color(0xFFE08A3C),
      const Color(0xFF546E7A), const Color(0xFFF5D060),
    ];
    final sections = List.generate(top.length, (i) => PieChartSectionData(
      value: top[i].value.toDouble(),
      title: '${top[i].value}',
      color: palette[i % palette.length],
      radius: 38,
      titleStyle: AppText.sans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
    ));

    final isMobile = MediaQuery.of(context).size.width < 600;
    final legendItems = List.generate(top.length, (i) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(child: Text('${top[i].key} (${top[i].value})',
            style: AppText.sans(color: AppColors.text2, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ));
    final chart = PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2));

    if (isMobile) {
      return SizedBox(
        height: 360,
        child: _StatCard(
          title: '$title ($total)',
          child: Column(children: [
            SizedBox(height: 180, child: chart),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 4, children: legendItems),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 300,
      child: _StatCard(
        title: '$title ($total)',
        child: Row(children: [
          Expanded(child: chart),
          const SizedBox(width: 16),
          Flexible(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legendItems,
          )),
        ]),
      ),
    );
  }
}

// ── Garde as horizontal bar ──
class _GardeBarCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _GardeBarCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null) { counts['Inconnu'] = (counts['Inconnu'] ?? 0) + 1; continue; }
      final g = GardeInfo.fromWine(w);
      if (g == null) { counts['Inconnu'] = (counts['Inconnu'] ?? 0) + 1; continue; }
      counts[g.label] = (counts[g.label] ?? 0) + 1;
    }
    return _HorizontalBarCard(title: 'Fenêtre de garde', data: counts, barColor: const Color(0xFFF5D060));
  }
}

// ── Acquisition vs Consommation as bar chart ──
class _AcquisitionVsConsommationBarCard extends StatelessWidget {
  final List<Bottle> cave;
  final List<Bottle> drunk;
  final List<Bottle> all;
  const _AcquisitionVsConsommationBarCard({required this.cave, required this.drunk, required this.all});

  @override
  Widget build(BuildContext context) {
    final addedByMonth = <String, int>{};
    final drunkByMonth = <String, int>{};
    for (final b in all) {
      final d = b.createdAt;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      addedByMonth[key] = (addedByMonth[key] ?? 0) + 1;
    }
    for (final b in drunk) {
      final d = b.drunkAt ?? b.createdAt;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      drunkByMonth[key] = (drunkByMonth[key] ?? 0) + 1;
    }
    final allKeys = {...addedByMonth.keys, ...drunkByMonth.keys}.toList()..sort();
    if (allKeys.isEmpty) return const SizedBox.shrink();
    final maxVal = allKeys.map((k) => max(addedByMonth[k] ?? 0, drunkByMonth[k] ?? 0)).reduce(max).toDouble();

    return SizedBox(
      height: 300,
      child: _StatCard(
        title: 'Acquisition vs consommation',
        child: BarChart(BarChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              interval: max(1, (allKeys.length / 6).ceilToDouble()),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= allKeys.length) return const SizedBox.shrink();
                final parts = allKeys[i].split('-');
                return Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text('${parts[1]}/${parts[0].substring(2)}', style: AppText.sans(color: AppColors.text3, fontSize: 9)));
              })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
              interval: max(1, (maxVal / 4).ceilToDouble()),
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppText.sans(color: AppColors.text3, fontSize: 10)))),
          ),
          maxY: maxVal + 1,
          barGroups: List.generate(allKeys.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: (addedByMonth[allKeys[i]] ?? 0).toDouble(), color: AppColors.gold, width: 6, borderRadius: BorderRadius.circular(2)),
              BarChartRodData(toY: (drunkByMonth[allKeys[i]] ?? 0).toDouble(), color: const Color(0xFFE8667A), width: 6, borderRadius: BorderRadius.circular(2)),
            ]);
          }),
          barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(getTooltipColor: (_) => AppColors.bg3)),
        )),
      ),
    );
  }
}

// ── Bottles per month as line ──
class _BottlesPerMonthLineCard extends StatelessWidget {
  final List<Bottle> bottles;
  final String title;
  final bool useCreatedAt;
  const _BottlesPerMonthLineCard({required this.bottles, required this.title, required this.useCreatedAt});

  @override
  Widget build(BuildContext context) {
    final byMonth = <String, int>{};
    for (final b in bottles) {
      final d = useCreatedAt ? b.createdAt : (b.drunkAt ?? b.createdAt);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + 1;
    }
    final keys = byMonth.keys.toList()..sort();
    if (keys.isEmpty) return SizedBox(height: 280, child: _StatCard(title: title, child: const Center(child: Text('Aucune donnée', style: TextStyle(color: AppColors.text3)))));
    final maxVal = byMonth.values.reduce(max).toDouble();
    final spots = List.generate(keys.length, (i) => FlSpot(i.toDouble(), byMonth[keys[i]]!.toDouble()));

    return SizedBox(
      height: 280,
      child: _StatCard(
        title: title,
        child: LineChart(LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= keys.length) return const SizedBox.shrink();
                final parts = keys[i].split('-');
                return Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text('${parts[1]}/${parts[0].substring(2)}', style: AppText.sans(color: AppColors.text3, fontSize: 9)));
              })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              interval: max(1, (maxVal / 4).ceilToDouble()),
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppText.sans(color: AppColors.text3, fontSize: 10)))),
          ),
          minY: 0, maxY: maxVal + 1,
          lineBarsData: [LineChartBarData(
            spots: spots, isCurved: true,
            color: useCreatedAt ? AppColors.gold : const Color(0xFFE8667A),
            barWidth: 2.5, dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: (useCreatedAt ? AppColors.gold : const Color(0xFFE8667A)).withValues(alpha: 0.1)),
          )],
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => AppColors.bg3)),
        )),
      ),
    );
  }
}

// ── Plus-value as line chart ──
class _PlusValueLineCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _PlusValueLineCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final byWine = <String, (double, double, String)>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null) continue;
      final a = b.purchasePrice ?? 0;
      final m = b.marketValue ?? b.purchasePrice ?? 0;
      if (a <= 0 && m <= 0) continue;
      final prev = byWine[b.wineId];
      if (prev != null) byWine[b.wineId] = (prev.$1 + a, prev.$2 + m, w.name);
      else byWine[b.wineId] = (a, m, w.name);
    }
    var sorted = byWine.entries.toList()..sort((a, b) => (b.value.$2 - b.value.$1).compareTo(a.value.$2 - a.value.$1));
    if (sorted.length > 12) sorted = sorted.sublist(0, 12);
    if (sorted.isEmpty) return const SizedBox.shrink();
    final maxVal = sorted.map((e) => max(e.value.$1, e.value.$2)).reduce(max);
    final achatSpots = List.generate(sorted.length, (i) => FlSpot(i.toDouble(), sorted[i].value.$1));
    final marcheSpots = List.generate(sorted.length, (i) => FlSpot(i.toDouble(), sorted[i].value.$2));

    return SizedBox(
      height: 320,
      child: _StatCard(
        title: 'Plus-value (achat vs marché)',
        child: LineChart(LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 50,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= sorted.length) return const SizedBox.shrink();
                final name = sorted[i].value.$3;
                return Padding(padding: const EdgeInsets.only(top: 6),
                  child: RotatedBox(quarterTurns: 1, child: Text(name.length > 14 ? '${name.substring(0, 14)}…' : name,
                    style: AppText.sans(color: AppColors.text3, fontSize: 9))));
              })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
              interval: max(1, (maxVal / 4).ceilToDouble()),
              getTitlesWidget: (v, _) => Text('${v.toInt()} \$', style: AppText.sans(color: AppColors.text3, fontSize: 9)))),
          ),
          minY: 0, maxY: maxVal + maxVal * 0.1,
          lineBarsData: [
            LineChartBarData(spots: achatSpots, isCurved: false, color: AppColors.text3, barWidth: 2, dotData: const FlDotData(show: true)),
            LineChartBarData(spots: marcheSpots, isCurved: false, color: AppColors.gold, barWidth: 2, dotData: const FlDotData(show: true)),
          ],
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => AppColors.bg3)),
        )),
      ),
    );
  }
}

// ── Distribution des prix as line ──
class _PrixDistributionLineCard extends StatelessWidget {
  final List<Bottle> cave;
  const _PrixDistributionLineCard({required this.cave});

  @override
  Widget build(BuildContext context) {
    final ranges = <String, int>{'0-25': 0, '25-50': 0, '50-100': 0, '100-200': 0, '200-500': 0, '500+': 0};
    for (final b in cave) {
      final p = b.purchasePrice ?? b.marketValue;
      if (p == null) continue;
      if (p < 25) ranges['0-25'] = ranges['0-25']! + 1;
      else if (p < 50) ranges['25-50'] = ranges['25-50']! + 1;
      else if (p < 100) ranges['50-100'] = ranges['50-100']! + 1;
      else if (p < 200) ranges['100-200'] = ranges['100-200']! + 1;
      else if (p < 500) ranges['200-500'] = ranges['200-500']! + 1;
      else ranges['500+'] = ranges['500+']! + 1;
    }
    final filtered = ranges.entries.where((e) => e.value > 0).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();
    final maxVal = filtered.map((e) => e.value).reduce(max).toDouble();
    final spots = List.generate(filtered.length, (i) => FlSpot(i.toDouble(), filtered[i].value.toDouble()));

    return SizedBox(
      height: 280,
      child: _StatCard(
        title: 'Distribution des prix (\$)',
        child: LineChart(LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= filtered.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text('${filtered[i].key} \$', style: AppText.sans(color: AppColors.text3, fontSize: 10)));
              })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              interval: max(1, (maxVal / 4).ceilToDouble()),
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppText.sans(color: AppColors.text3, fontSize: 10)))),
          ),
          minY: 0, maxY: maxVal + 1,
          lineBarsData: [LineChartBarData(
            spots: spots, isCurved: true, color: AppColors.gold, barWidth: 2.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppColors.gold.withValues(alpha: 0.1)),
          )],
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => AppColors.bg3)),
        )),
      ),
    );
  }
}

// ── Maturité as bar chart ──
class _MaturiteBarCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _MaturiteBarCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final byYear = <int, int>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null || w.drinkFrom == null) continue;
      byYear[w.drinkFrom!] = (byYear[w.drinkFrom!] ?? 0) + 1;
    }
    if (byYear.isEmpty) return const SizedBox.shrink();
    final years = byYear.keys.toList()..sort();
    final maxVal = byYear.values.reduce(max).toDouble();
    final now = DateTime.now().year;

    return SizedBox(
      height: 280,
      child: _StatCard(
        title: 'Calendrier de maturité',
        child: BarChart(BarChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              interval: max(1, (years.length / 8).ceilToDouble()),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= years.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text('${years[i]}', style: AppText.sans(
                    color: years[i] == now ? AppColors.gold2 : AppColors.text3, fontSize: 10,
                    fontWeight: years[i] == now ? FontWeight.w700 : FontWeight.w400)));
              })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              interval: max(1, (maxVal / 4).ceilToDouble()),
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppText.sans(color: AppColors.text3, fontSize: 10)))),
          ),
          maxY: maxVal + 1,
          barGroups: List.generate(years.length, (i) {
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: byYear[years[i]]!.toDouble(),
                color: years[i] == now ? AppColors.gold : const Color(0xFF7CD492),
                width: max(4, 300 / years.length), borderRadius: BorderRadius.circular(3)),
            ]);
          }),
          barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.bg3,
            getTooltipItem: (group, _, rod, __) => BarTooltipItem('${years[group.x]}\n${rod.toY.toInt()} bouteilles',
              AppText.sans(color: AppColors.text, fontSize: 11)))),
        )),
      ),
    );
  }
}

// ── Vintage distribution as line ──
class _VintageDistributionLineCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _VintageDistributionLineCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final byVintage = <int, int>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null || w.vintage == null) continue;
      byVintage[w.vintage!] = (byVintage[w.vintage!] ?? 0) + 1;
    }
    if (byVintage.isEmpty) return const SizedBox.shrink();
    final years = byVintage.keys.toList()..sort();
    final maxVal = byVintage.values.reduce(max).toDouble();
    final spots = List.generate(years.length, (i) => FlSpot(i.toDouble(), byVintage[years[i]]!.toDouble()));

    return SizedBox(
      height: 280,
      child: _StatCard(
        title: 'Distribution des millésimes',
        child: LineChart(LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: max(1, (maxVal / 4).ceilToDouble()),
            getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 0.5)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              interval: max(1, (years.length / 10).ceilToDouble()),
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= years.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 6),
                  child: Text('${years[i]}', style: AppText.sans(color: AppColors.text3, fontSize: 9)));
              })),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
              interval: max(1, (maxVal / 4).ceilToDouble()),
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: AppText.sans(color: AppColors.text3, fontSize: 10)))),
          ),
          minY: 0, maxY: maxVal + 1,
          lineBarsData: [LineChartBarData(
            spots: spots, isCurved: true, color: AppColors.gold, barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: AppColors.gold.withValues(alpha: 0.1)),
          )],
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => AppColors.bg3)),
        )),
      ),
    );
  }
}

// ── Vintage distribution as donut ──
class _VintageDistributionDonutCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _VintageDistributionDonutCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final byVintage = <int, int>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null || w.vintage == null) continue;
      byVintage[w.vintage!] = (byVintage[w.vintage!] ?? 0) + 1;
    }
    if (byVintage.isEmpty) return const SizedBox.shrink();
    final data = byVintage.entries.map((e) => MapEntry('${e.key}', e.value)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = data.take(10).toList();
    final asMap = {for (final e in top) e.key: e.value};
    return _GenericDonutCard(title: 'Distribution des millésimes', data: asMap);
  }
}

// ── Cépages as horizontal bar ──
class _CepageBarCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _CepageBarCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null || w.grapes.isEmpty) continue;
      for (final g in w.grapes.split(RegExp(r'[,;]'))) {
        final m = RegExp(r'(.+?)(\s+\d+\s*%)?$').firstMatch(g.trim());
        if (m != null) {
          final name = m.group(1)!.trim();
          if (name.isNotEmpty) counts[name] = (counts[name] ?? 0) + 1;
        }
      }
    }
    return _HorizontalBarCard(title: 'Cépages principaux', data: counts, barColor: const Color(0xFF7CD492));
  }
}

Map<String, int> _parseGrapeCounts(Map<String, Wine> wines, List<Bottle> cave) {
  final counts = <String, int>{};
  for (final b in cave) {
    final w = wines[b.wineId];
    if (w == null || w.grapes.isEmpty) continue;
    final grapes = w.grapes.split(RegExp(r'[,;/]'));
    final main = grapes.first
        .trim()
        .replaceAll(RegExp(r'\s*\(\s*\d+\s*%?\s*\)\s*'), '') // remove (85%) or (85)
        .replaceAll(RegExp(r'\s*\d+%?\s*'), '') // remove standalone 85% or 85
        .trim();
    if (main.isEmpty) continue;
    counts[main] = (counts[main] ?? 0) + 1;
  }
  return counts;
}

// ── 21. Cépages donut ──
class _CepageDonutCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _CepageDonutCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final counts = _parseGrapeCounts(wines, cave);
    if (counts.isEmpty) return const SizedBox.shrink();

    var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (s, e) => s + e.value);

    Map<String, int> display;
    if (sorted.length > 8) {
      final top = sorted.sublist(0, 8);
      final other = sorted.sublist(8).fold<int>(0, (s, e) => s + e.value);
      display = {for (final e in top) e.key: e.value, 'Autres': other};
    } else {
      display = {for (final e in sorted) e.key: e.value};
    }

    final palette = [
      const Color(0xFFB23A48),
      const Color(0xFFE6D27A),
      const Color(0xFF7CD492),
      const Color(0xFF70B8E8),
      const Color(0xFFC490F0),
      const Color(0xFFE08A3C),
      const Color(0xFFE89DA6),
      const Color(0xFFB8C9D9),
      AppColors.text3,
    ];

    final entries = display.entries.toList();
    final sections = List.generate(entries.length, (i) => PieChartSectionData(
      value: entries[i].value.toDouble(),
      title: '${entries[i].value}',
      color: palette[i % palette.length],
      radius: 38,
      titleStyle: AppText.sans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
    ));

    final isMobile = MediaQuery.of(context).size.width < 600;
    final legendItems = List.generate(entries.length, (i) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(child: Text('${entries[i].key} (${entries[i].value})',
            style: AppText.sans(color: AppColors.text2, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ));
    final chart = PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2));

    if (isMobile) {
      return SizedBox(
        height: 360,
        child: _StatCard(
          title: 'Cépages principaux ($total)',
          child: Column(children: [
            SizedBox(height: 180, child: chart),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 4, children: legendItems),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 300,
      child: _StatCard(
        title: 'Cépages principaux ($total)',
        child: Row(children: [
          Expanded(child: chart),
          const SizedBox(width: 16),
          Flexible(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legendItems,
          )),
        ]),
      ),
    );
  }
}

// ── 22. Cépages - part en cave (%) ──
class _CepagePartDonutCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _CepagePartDonutCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final counts = _parseGrapeCounts(wines, cave);
    if (counts.isEmpty) return const SizedBox.shrink();

    var sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (s, e) => s + e.value);

    Map<String, int> display;
    if (sorted.length > 8) {
      final top = sorted.sublist(0, 8);
      final other = sorted.sublist(8).fold<int>(0, (s, e) => s + e.value);
      display = {for (final e in top) e.key: e.value, 'Autres': other};
    } else {
      display = {for (final e in sorted) e.key: e.value};
    }

    final palette = [
      const Color(0xFFB23A48),
      const Color(0xFFE6D27A),
      const Color(0xFF7CD492),
      const Color(0xFF70B8E8),
      const Color(0xFFC490F0),
      const Color(0xFFE08A3C),
      const Color(0xFFE89DA6),
      const Color(0xFFB8C9D9),
      AppColors.text3,
    ];

    final entries = display.entries.toList();
    int pct(int v) => (v / total * 100).round();

    final sections = List.generate(entries.length, (i) => PieChartSectionData(
      value: entries[i].value.toDouble(),
      title: '${pct(entries[i].value)}%',
      color: palette[i % palette.length],
      radius: 38,
      titleStyle: AppText.sans(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
    ));

    final isMobile = MediaQuery.of(context).size.width < 600;
    final legendItems = List.generate(entries.length, (i) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Flexible(child: Text('${entries[i].key} (${pct(entries[i].value)}%)',
            style: AppText.sans(color: AppColors.text2, fontSize: 11),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    ));
    final chart = PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2));

    if (isMobile) {
      return SizedBox(
        height: 360,
        child: _StatCard(
          title: 'Cépages - part en cave',
          child: Column(children: [
            SizedBox(height: 180, child: chart),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 4, children: legendItems),
          ]),
        ),
      );
    }
    return SizedBox(
      height: 300,
      child: _StatCard(
        title: 'Cépages - part en cave',
        child: Row(children: [
          Expanded(child: chart),
          const SizedBox(width: 16),
          Flexible(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: legendItems,
          )),
        ]),
      ),
    );
  }
}

// ── Distribution camembert : cépage / pays / région ──
class _DistributionCamembertCard extends StatefulWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _DistributionCamembertCard({required this.wines, required this.cave});

  @override
  State<_DistributionCamembertCard> createState() =>
      _DistributionCamembertCardState();
}

class _DistributionCamembertCardState
    extends State<_DistributionCamembertCard> {
  int _tab = 0;

  static const _palette = [
    Color(0xFFB23A48),
    Color(0xFFE6D27A),
    Color(0xFF7CD492),
    Color(0xFF70B8E8),
    Color(0xFFC490F0),
    Color(0xFFE08A3C),
    Color(0xFFE89DA6),
    Color(0xFFB8C9D9),
    AppColors.text3,
  ];

  Map<String, int> _countByField(String Function(Bottle) field) {
    final map = <String, int>{};
    for (final b in widget.cave) {
      final key = field(b);
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> _topN(Map<String, int> data, int n) {
    final sorted = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length <= n) return {for (final e in sorted) e.key: e.value};
    final top = sorted.sublist(0, n);
    final other = sorted.sublist(n).fold<int>(0, (s, e) => s + e.value);
    return {for (final e in top) e.key: e.value, 'Autres': other};
  }

  Widget _buildDonut(String label, Map<String, int> data) {
    if (data.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 24),
          Text('—', style: AppText.sans(color: AppColors.text3, fontSize: 12)),
        ],
      );
    }
    final display = _topN(data, 6);
    final total = data.values.fold<int>(0, (s, v) => s + v);
    final entries = display.entries.toList();
    final sections = List.generate(
      entries.length,
      (i) => PieChartSectionData(
        value: entries[i].value.toDouble(),
        title: '${entries[i].value}',
        color: _palette[i % _palette.length],
        radius: 28,
        titleStyle: AppText.sans(
            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
    final chart = PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 24,
        sectionsSpace: 2,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(width: 6),
          Text('($total)',
              style: AppText.sans(color: AppColors.text3, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        SizedBox(height: 130, child: chart),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          children: List.generate(
            entries.length,
            (i) => Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: _palette[i % _palette.length],
                      shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(entries[i].key,
                  style:
                      AppText.sans(color: AppColors.text2, fontSize: 10)),
            ]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cepages = _parseGrapeCounts(widget.wines, widget.cave);
    final pays = _countByField(
        (b) => widget.wines[b.wineId]?.country ?? '');
    final regions = _countByField(
        (b) => widget.wines[b.wineId]?.region ?? '');

    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      Map<String, int> activeData;
      String activeLabel;
      switch (_tab) {
        case 1:
          activeData = pays;
          activeLabel = 'Pays';
          break;
        case 2:
          activeData = regions;
          activeLabel = 'Régions';
          break;
        default:
          activeData = cepages;
          activeLabel = 'Cépages';
      }
      return SizedBox(
        height: 340,
        child: _StatCard(
          title: 'Distribution',
          child: Column(children: [
            Row(children: [
              for (final t in [
                (0, 'Cépages'),
                (1, 'Pays'),
                (2, 'Régions'),
              ]) ...[
                _DistribTab(
                  label: t.$2,
                  selected: _tab == t.$1,
                  onTap: () => setState(() => _tab = t.$1),
                ),
                const SizedBox(width: 8),
              ],
            ]),
            const SizedBox(height: 12),
            Expanded(child: _buildDonut(activeLabel, activeData)),
          ]),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: _StatCard(
        title: 'Distribution (cépage / pays / région)',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDonut('Cépages', cepages)),
            const SizedBox(width: 12),
            Expanded(child: _buildDonut('Pays', pays)),
            const SizedBox(width: 12),
            Expanded(child: _buildDonut('Régions', regions)),
          ],
        ),
      ),
    );
  }
}

class _DistribTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DistribTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.15)
              : AppColors.bg3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? AppColors.gold : AppColors.border),
        ),
        child: Text(
          label,
          style: AppText.sans(
            color: selected ? AppColors.gold : AppColors.text2,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


class _CarteMondeCard extends StatelessWidget {
  final Map<String, Wine> wines;
  final List<Bottle> cave;
  const _CarteMondeCard({required this.wines, required this.cave});

  @override
  Widget build(BuildContext context) {
    final byCountry = <String, int>{};
    final byContinent = <WineContinent, int>{};
    int withoutCountry = 0;
    for (final b in cave) {
      final w = wines[b.wineId];
      if (w == null) continue;
      final country = w.country.trim();
      if (country.isEmpty) {
        withoutCountry++;
        continue;
      }
      byCountry[country] = (byCountry[country] ?? 0) + 1;
      final cont = continentForCountry(country);
      byContinent[cont] = (byContinent[cont] ?? 0) + 1;
    }

    if (byCountry.isEmpty) {
      return SizedBox(
        height: 160,
        child: _StatCard(
          title: 'Carte du monde',
          child: Center(
            child: Text(
              'Aucun pays renseigné dans la cave.',
              style: AppText.sans(color: AppColors.text3, fontSize: 12),
            ),
          ),
        ),
      );
    }

    final entries = byCountry.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = entries.first.value;
    final total = cave.length;

    final continentEntries = WineContinent.values
        .where((c) => (byContinent[c] ?? 0) > 0)
        .toList()
      ..sort(
          (a, b) => (byContinent[b] ?? 0).compareTo(byContinent[a] ?? 0));

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'CARTE DU MONDE',
                    style: AppText.sans(
                      color: AppColors.text3,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${byCountry.length} pays · $total bouteilles',
                  style: AppText.sans(color: AppColors.text3, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in continentEntries)
                  _continentChip(c, byContinent[c] ?? 0, total),
                if (withoutCountry > 0)
                  _continentChip(null, withoutCountry, total,
                      labelOverride: 'Sans pays'),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries)
                  _countryRow(e.key, e.value, maxCount, total, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _continentChip(WineContinent? cont, int count, int total,
      {String? labelOverride}) {
    final color = _colorForContinent(cont);
    final pct = total > 0 ? (count / total * 100) : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            labelOverride ?? cont!.label,
            style: AppText.sans(
              color: AppColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count (${pct.toStringAsFixed(0)}%)',
            style: AppText.sans(color: AppColors.text3, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _countryRow(String country, int count, int maxCount, int total,
      bool isMobile) {
    final flag = flagForCountry(country) ?? '🏳️';
    final cont = continentForCountry(country);
    final color = _colorForContinent(cont);
    final ratio = maxCount > 0 ? count / maxCount : 0.0;
    final pct = total > 0 ? (count / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(flag, style: AppText.emoji(fontSize: 18)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: isMobile ? 100 : 140,
            child: Text(
              country,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.sans(color: AppColors.text, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 8, color: AppColors.bg3),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.02, 1.0),
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.55),
                            color,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 64,
            child: Text(
              '$count · ${pct.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: AppText.sans(
                color: AppColors.text2,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForContinent(WineContinent? c) {
    switch (c) {
      case WineContinent.europe:
        return const Color(0xFF70B8E8);
      case WineContinent.ameriques:
        return const Color(0xFF7CD492);
      case WineContinent.oceanie:
        return const Color(0xFFC490F0);
      case WineContinent.afrique:
        return const Color(0xFFE8A04C);
      case WineContinent.asie:
        return const Color(0xFFE8667A);
      case WineContinent.autre:
      case null:
        return AppColors.text3;
    }
  }
}
