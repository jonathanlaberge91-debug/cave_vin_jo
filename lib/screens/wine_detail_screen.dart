import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../theme/app_text.dart';
import 'home_screen.dart' show AppColors;

const _monthsFr = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String _fmtDate(DateTime d) =>
    '${d.day} ${_monthsFr[d.month - 1]} ${d.year}';

Future<void> showWineDetail(
  BuildContext context, {
  required Wine wine,
  required List<Bottle> bottles,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (_) => WineDetailDialog(wine: wine, bottles: bottles),
  );
}

class WineDetailDialog extends StatelessWidget {
  final Wine wine;
  final List<Bottle> bottles;

  const WineDetailDialog({
    super.key,
    required this.wine,
    required this.bottles,
  });

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final modalW = screenW < 920 ? screenW - 32 : 880.0;
    final modalH = screenH * 0.88;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: modalW,
        constraints: BoxConstraints(maxHeight: modalH),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          border: Border.all(color: AppColors.border2),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 60,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.05),
              blurRadius: 0,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(40, 36, 40, 32),
                child: _DialogBody(wine: wine, bottles: bottles),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: _CloseButton(
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _hover
                ? const Color(0x33C9A84C)
                : AppColors.bg3.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border2),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.close,
            size: 16,
            color: _hover ? AppColors.gold2 : AppColors.text2,
          ),
        ),
      ),
    );
  }
}

class _DialogBody extends StatelessWidget {
  final Wine wine;
  final List<Bottle> bottles;
  const _DialogBody({required this.wine, required this.bottles});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TopRow(wine: wine, bottles: bottles),
        const SizedBox(height: 24),
        _OriginSection(wine: wine, bottles: bottles),
        if (_hasGarde(wine)) ...[
          const SizedBox(height: 26),
          _GardeSection(wine: wine),
        ],
        if (wine.wineDescription.isNotEmpty) ...[
          const SizedBox(height: 26),
          _Section(
            title: 'À propos de ce vin',
            child: _DescriptionText(text: wine.wineDescription),
          ),
        ],
        if (wine.domaineDescription.isNotEmpty) ...[
          const SizedBox(height: 26),
          _Section(
            title: 'Le domaine',
            child: _DescriptionText(text: wine.domaineDescription),
          ),
        ],
        if (wine.critiques.isNotEmpty) ...[
          const SizedBox(height: 26),
          _CritiquesSection(critiques: wine.critiques),
        ],
        const SizedBox(height: 26),
        _BottlesSection(wine: wine, bottles: bottles),
      ],
    );
  }

  bool _hasGarde(Wine w) =>
      w.drinkFrom != null || w.drinkPeak != null || w.drinkTo != null;
}

class _TopRow extends StatelessWidget {
  final Wine wine;
  final List<Bottle> bottles;
  const _TopRow({required this.wine, required this.bottles});

  @override
  Widget build(BuildContext context) {
    final qty = bottles.length;
    final purchaseTotal = bottles
        .map((b) => b.purchasePrice ?? 0)
        .fold<double>(0, (s, v) => s + v);
    final purchaseCount = bottles.where((b) => b.purchasePrice != null).length;
    final avgPrice = purchaseCount > 0 ? purchaseTotal / purchaseCount : null;
    final totalValue = bottles.fold<double>(
      0,
      (s, b) => s + (b.marketValue ?? b.purchasePrice ?? 0),
    );

    final stats = <_StatTileData>[
      _StatTileData(label: 'Bouteilles', value: '$qty'),
      if (wine.rating != null)
        _StatTileData(label: 'Note', value: '${wine.rating}', suffix: '/100'),
      if (avgPrice != null && avgPrice > 0)
        _StatTileData(
          label: 'Prix moyen',
          value: avgPrice.toStringAsFixed(0),
          suffix: ' \$',
        ),
      if (totalValue > 0)
        _StatTileData(
          label: 'Valeur',
          value: totalValue.toStringAsFixed(0),
          suffix: ' \$',
        ),
    ];

    return Container(
      padding: const EdgeInsets.only(bottom: 22),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BottleVisual(wine: wine),
          const SizedBox(width: 28),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wine.name,
                  style: AppText.serif(
                    color: AppColors.text,
                    fontSize: 38,
                    fontWeight: FontWeight.w500,
                    height: 1.05,
                  ),
                ),
                if (wine.producer.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    wine.producer,
                    style: AppText.serif(
                      color: AppColors.gold2,
                      fontSize: 18,
                      height: 1.1,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TypeChip(type: wine.type),
                    if (wine.vintage != null) _GoldChip(label: '${wine.vintage}'),
                    if (wine.appellation.isNotEmpty)
                      _OutlineChip(label: wine.appellation),
                    _OutlineChip(label: bottles.first.format.label),
                  ],
                ),
                const SizedBox(height: 18),
                _StatsRow(stats: stats),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottleVisual extends StatelessWidget {
  final Wine wine;
  const _BottleVisual({required this.wine});

  @override
  Widget build(BuildContext context) {
    if (wine.photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          wine.photoUrl!,
          width: 100,
          height: 240,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 100,
      height: 240,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF200808),
            Color(0xFF4A1818),
            Color(0xFF6A2020),
            Color(0xFF2A0808),
          ],
          stops: [0, 0.3, 0.7, 1],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(50),
          topRight: Radius.circular(50),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 80, 13, 30),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0E0C0),
            border: Border.all(color: const Color(0xFFC9A84C)),
            borderRadius: BorderRadius.circular(2),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.wine_bar,
            color: AppColors.text3.withValues(alpha: 0.5),
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final WineType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _typeLabel(type),
            style: AppText.sans(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoldChip extends StatelessWidget {
  final String label;
  const _GoldChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x29C9A84C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x66C9A84C)),
      ),
      child: Text(
        label,
        style: AppText.sans(
          color: AppColors.gold2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _OutlineChip extends StatelessWidget {
  final String label;
  const _OutlineChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border2),
      ),
      child: Text(
        label,
        style: AppText.sans(
          color: AppColors.text2,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _StatTileData {
  final String label;
  final String value;
  final String? suffix;
  _StatTileData({required this.label, required this.value, this.suffix});
}

class _StatsRow extends StatelessWidget {
  final List<_StatTileData> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          Expanded(child: _StatTile(data: stats[i])),
          if (i < stats.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  const _StatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.label.toUpperCase(),
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 9,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              text: data.value,
              style: AppText.serif(
                color: AppColors.gold2,
                fontSize: 22,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
              children: [
                if (data.suffix != null)
                  TextSpan(
                    text: data.suffix,
                    style: AppText.sans(
                      color: AppColors.text3,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title.toUpperCase(),
              style: AppText.sans(
                color: AppColors.gold2,
                fontSize: 11,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _OriginSection extends StatelessWidget {
  final Wine wine;
  final List<Bottle> bottles;
  const _OriginSection({required this.wine, required this.bottles});

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      if (wine.country.isNotEmpty) ('Pays', wine.country),
      if (wine.region.isNotEmpty) ('Région', wine.region),
      if (wine.appellation.isNotEmpty) ('Appellation', wine.appellation),
      if (wine.village.isNotEmpty) ('Village', wine.village),
      if (wine.climat.isNotEmpty) ('Climat', wine.climat),
      if (wine.domaine.isNotEmpty) ('Domaine', wine.domaine),
      if (wine.grapes.isNotEmpty) ('Cépages', wine.grapes),
      if (wine.alcohol != null) ('Alcool', '${wine.alcohol!.toStringAsFixed(1)} %'),
    ];
    if (entries.isEmpty && wine.domainAddress.isEmpty) {
      return const SizedBox.shrink();
    }

    return _Section(
      title: 'Origine',
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i += 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _KvLine(label: entries[i].$1, value: entries[i].$2)),
                const SizedBox(width: 36),
                Expanded(
                  child: i + 1 < entries.length
                      ? _KvLine(
                          label: entries[i + 1].$1,
                          value: entries[i + 1].$2,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          if (wine.domainAddress.isNotEmpty)
            _KvLine(label: 'Adresse', value: wine.domainAddress, fullWidth: true),
        ],
      ),
    );
  }
}

class _KvLine extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;
  const _KvLine({
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, style: BorderStyle.solid),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label.toUpperCase(),
              style: AppText.sans(
                color: AppColors.text3,
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppText.serif(
                color: AppColors.text,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GardeSection extends StatelessWidget {
  final Wine wine;
  const _GardeSection({required this.wine});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Période de garde',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: _GardeTimeline(wine: wine),
      ),
    );
  }
}

class _GardeTimeline extends StatelessWidget {
  final Wine wine;
  const _GardeTimeline({required this.wine});

  @override
  Widget build(BuildContext context) {
    final from = wine.drinkFrom;
    final peak = wine.drinkPeak;
    final to = wine.drinkTo;
    final now = DateTime.now().year;

    final years = <int>{now};
    if (from != null) years.add(from);
    if (peak != null) years.add(peak);
    if (to != null) years.add(to);
    final minYear = years.reduce((a, b) => a < b ? a : b) - 1;
    final maxYear = years.reduce((a, b) => a > b ? a : b) + 1;
    final span = (maxYear - minYear).clamp(1, 999).toDouble();

    double pos(int year) => (year - minYear) / span;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 90,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 36,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.bg4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (from != null && to != null)
                Positioned(
                  left: pos(from) * w,
                  width: ((pos(to) - pos(from)) * w).clamp(0, double.infinity),
                  top: 36,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF2E7D32),
                          Color(0xFFF5D060),
                          Color(0xFFC62828),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Positioned(
                left: pos(now) * w - 1,
                top: 24,
                child: Container(
                  width: 2,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.gold2,
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold2.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              if (from != null)
                _marker(
                  x: pos(from) * w,
                  year: from,
                  label: 'À boire dès',
                  color: const Color(0xFF2E7D32),
                ),
              if (peak != null)
                _marker(
                  x: pos(peak) * w,
                  year: peak,
                  label: 'Apogée',
                  color: const Color(0xFFF5D060),
                  large: true,
                ),
              if (to != null)
                _marker(
                  x: pos(to) * w,
                  year: to,
                  label: 'Avant',
                  color: const Color(0xFFC62828),
                ),
              Positioned(
                left: pos(now) * w - 35,
                top: 60,
                child: SizedBox(
                  width: 70,
                  child: Text(
                    'Aujourd\'hui',
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      color: AppColors.gold2,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _marker({
    required double x,
    required int year,
    required String label,
    required Color color,
    bool large = false,
  }) {
    final size = large ? 16.0 : 12.0;
    return Positioned(
      left: x - 35,
      top: 38 - size / 2,
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg3, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$year',
              style: AppText.serif(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppText.sans(
                color: AppColors.text3,
                fontSize: 9,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionText extends StatelessWidget {
  final String text;
  const _DescriptionText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppText.serif(
        color: AppColors.text,
        fontSize: 15,
        height: 1.6,
      ),
    );
  }
}

class _CritiquesSection extends StatelessWidget {
  final List<Critique> critiques;
  const _CritiquesSection({required this.critiques});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Critiques (${critiques.length})',
      child: Column(
        children: [
          for (var i = 0; i < critiques.length; i++) ...[
            _CritiqueCard(critique: critiques[i]),
            if (i < critiques.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CritiqueCard extends StatelessWidget {
  final Critique critique;
  const _CritiqueCard({required this.critique});

  @override
  Widget build(BuildContext context) {
    final hasScore = critique.score.isNotEmpty;
    final hasNote = critique.note.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.format_quote,
                  color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      critique.source.isEmpty ? 'Critique' : critique.source,
                      style: AppText.serif(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (critique.date != null)
                      Text(
                        _fmtDate(critique.date!),
                        style: AppText.sans(
                          color: AppColors.text3,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasScore)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x29C9A84C),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x66C9A84C)),
                  ),
                  child: Text(
                    critique.score,
                    style: AppText.serif(
                      color: AppColors.gold2,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (hasNote) ...[
            const SizedBox(height: 10),
            Text(
              critique.note,
              style: AppText.serif(
                color: AppColors.text2,
                fontSize: 14,
                height: 1.55,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottlesSection extends StatelessWidget {
  final Wine wine;
  final List<Bottle> bottles;
  const _BottlesSection({required this.wine, required this.bottles});

  @override
  Widget build(BuildContext context) {
    final formatLabel = bottles.first.format.label;
    return _Section(
      title: 'Bouteilles (${bottles.length}) — Format $formatLabel',
      child: Column(
        children: [
          for (var i = 0; i < bottles.length; i++) ...[
            _BottleCard(bottle: bottles[i], index: i + 1),
            if (i < bottles.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _BottleCard extends StatelessWidget {
  final Bottle bottle;
  final int index;
  const _BottleCard({required this.bottle, required this.index});

  @override
  Widget build(BuildContext context) {
    final b = bottle;
    final metaParts = <String>[
      if (b.source != null) b.source!.label,
      if (b.purchaseYear != null) 'achetée en ${b.purchaseYear}',
      'ajoutée le ${_fmtDate(b.createdAt)}',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.bg4,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border2),
            ),
            alignment: Alignment.center,
            child: Text(
              '$index',
              style: AppText.serif(
                color: AppColors.gold2,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 13,
                      color: AppColors.text3,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      b.location.isNotEmpty
                          ? 'Emplacement ${b.location}'
                          : 'Sans emplacement',
                      style: AppText.sans(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (metaParts.isNotEmpty)
                  Text(
                    metaParts.join(' · '),
                    style: AppText.sans(
                      color: AppColors.text3,
                      fontSize: 11,
                    ),
                  ),
                if (b.isGift && (b.giftFrom.isNotEmpty || b.giftOccasion.isNotEmpty || b.giftDate != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0x26C9A84C),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        [
                          'CADEAU',
                          if (b.giftFrom.isNotEmpty) 'de ${b.giftFrom}',
                          if (b.giftOccasion.isNotEmpty) b.giftOccasion,
                          if (b.giftDate != null) _fmtDate(b.giftDate!),
                        ].join(' · '),
                        style: AppText.sans(
                          color: AppColors.gold2,
                          fontSize: 9,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (b.purchasePrice != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${b.purchasePrice!.toStringAsFixed(0)} \$',
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (b.marketValue != null && b.marketValue != b.purchasePrice)
                  Text(
                    'val. ${b.marketValue!.toStringAsFixed(0)} \$',
                    style: AppText.sans(
                      color: AppColors.text3,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

Color _typeColor(WineType t) {
  switch (t) {
    case WineType.rouge:
      return const Color(0xFFB23A48);
    case WineType.blanc:
      return const Color(0xFFE6D27A);
    case WineType.rose:
      return const Color(0xFFE89DA6);
    case WineType.orange:
      return const Color(0xFFE08A3C);
    case WineType.petillant:
      return const Color(0xFFB8C9D9);
  }
}

String _typeLabel(WineType t) {
  switch (t) {
    case WineType.rouge:
      return 'ROUGE';
    case WineType.blanc:
      return 'BLANC';
    case WineType.rose:
      return 'ROSÉ';
    case WineType.orange:
      return 'ORANGE';
    case WineType.petillant:
      return 'PÉTILLANT';
  }
}
