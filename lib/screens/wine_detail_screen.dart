import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../services/actualisation_service.dart';
import '../services/cave_service.dart';
import '../services/wine_pdf_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/wine_type_helpers.dart';
import '../dialogs/edit_bottle_dialog.dart';
import '../dialogs/add_bottles_dialog.dart';
import '../dialogs/drink_bottle_dialog.dart';
import '../theme/date_format.dart';
import '../widgets/native_image.dart';
import 'add_wine_dialog.dart';

Future<void> showWineDetail(
  BuildContext context, {
  required Wine wine,
  required List<Bottle> bottles,
  BottleFormat? format,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (_) => WineDetailDialog(
      wine: wine,
      bottles: bottles,
      format: format ?? bottles.first.format,
    ),
  );
}

class WineDetailDialog extends StatefulWidget {
  final Wine wine;
  final List<Bottle> bottles;
  final BottleFormat format;

  const WineDetailDialog({
    super.key,
    required this.wine,
    required this.bottles,
    required this.format,
  });

  @override
  State<WineDetailDialog> createState() => _WineDetailDialogState();
}

class _WineDetailDialogState extends State<WineDetailDialog> {
  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final modalW = screenW < 920 ? screenW - 32 : 880.0;
    final modalH = screenH * 0.92;

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
        child: StreamBuilder<Wine?>(
          stream: CaveService.wine(widget.wine.id),
          initialData: widget.wine,
          builder: (context, wineSnap) {
            final wine = wineSnap.data ?? widget.wine;
            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: StreamBuilder<List<Bottle>>(
                    stream: CaveService.bottlesByWine(widget.wine.id).map(
                      (list) => list.where((b) => b.format == widget.format).toList(),
                    ),
                    initialData: widget.bottles,
                    builder: (context, snap) {
                      final mine = snap.data ?? const <Bottle>[];
                      if (mine.isEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) Navigator.of(context).maybePop();
                        });
                        return const SizedBox.shrink();
                      }
                      return SingleChildScrollView(
                        child: _DialogBody(wine: wine, bottles: mine),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 98,
                  child: _HeaderAction(
                    icon: Icons.print_outlined,
                    tooltip: 'Fiche imprimable',
                    onTap: () => openWinePrintSheet(wine, widget.bottles),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 56,
                  child: _HeaderAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Modifier le vin',
                    onTap: () => showEditWineDialog(context, wine),
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
            );
          },
        ),
      ),
    );
  }
}

class _HeaderAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HeaderAction> createState() => _HeaderActionState();
}

class _HeaderActionState extends State<_HeaderAction> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
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
              widget.icon,
              size: 15,
              color: _hover ? AppColors.gold2 : AppColors.text2,
            ),
          ),
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

class _DialogBody extends StatefulWidget {
  final Wine wine;
  final List<Bottle> bottles;
  const _DialogBody({required this.wine, required this.bottles});

  @override
  State<_DialogBody> createState() => _DialogBodyState();
}

class _DialogBodyState extends State<_DialogBody> {
  bool _loadingMarket = false;

  Wine get wine => widget.wine;
  List<Bottle> get bottles => widget.bottles;

  @override
  Widget build(BuildContext context) {
    final qty = bottles.length;
    final purchaseTotal = bottles
        .map((b) => b.purchasePrice ?? 0)
        .fold<double>(0, (s, v) => s + v);
    final purchaseCount = bottles.where((b) => b.purchasePrice != null).length;
    final avgPrice = purchaseCount > 0 ? purchaseTotal / purchaseCount : null;
    final hasMarket = bottles.any((b) => b.marketValue != null);
    final marketByFormat = <BottleFormat, double>{};
    for (final b in bottles) {
      if (b.marketValue != null && !marketByFormat.containsKey(b.format)) {
        marketByFormat[b.format] = b.marketValue!;
      }
    }
    final totalValue = bottles.fold<double>(
      0,
      (s, b) => s + (b.marketValue ?? b.purchasePrice ?? 0),
    );

    final stats = <_StatTileData>[
      _StatTileData(label: 'Bouteilles', value: '$qty'),
      if (wine.rating != null)
        _StatTileData(label: 'Note', value: '${wine.rating}', suffix: '/100'),
      for (final e in marketByFormat.entries)
        _StatTileData(
          label: marketByFormat.length > 1
              ? 'Val. ${e.key.label}'
              : 'Val. marché',
          value: e.value.toStringAsFixed(0),
          suffix: ' \$',
        ),
      if (avgPrice != null && avgPrice > 0)
        _StatTileData(
          label: 'Prix payé moy.',
          value: avgPrice.toStringAsFixed(0),
          suffix: ' \$',
        ),
      if (totalValue > 0 && qty > 1)
        _StatTileData(
          label: 'Valeur totale',
          value: totalValue.toStringAsFixed(0),
          suffix: ' \$',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroPhoto(wine: wine),
        LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final hPad = compact ? 20.0 : 40.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wine.name,
                style: AppText.serif(
                  color: AppColors.text,
                  fontSize: compact ? 26 : 36,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
              if (wine.producer.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  wine.producer,
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 17,
                    height: 1.1,
                  ),
                ),
              ],
              const SizedBox(height: 14),
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
              const SizedBox(height: 20),
              _StatsRow(stats: stats),
              if (!hasMarket) ...[
                const SizedBox(height: 10),
                _EstimateMarketButton(
                  loading: _loadingMarket,
                  onTap: () async {
                    setState(() => _loadingMarket = true);
                    await ActualisationService.refreshMarketValue(wine);
                    if (mounted) setState(() => _loadingMarket = false);
                  },
                ),
              ],
              const SizedBox(height: 24),
              _OriginSection(wine: wine, bottles: bottles),
              if (_hasGarde(wine)) ...[
                const SizedBox(height: 26),
                _GardeSection(wine: wine, format: bottles.first.format),
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
          ),
        );
        }),
      ],
    );
  }

  bool _hasGarde(Wine w) =>
      w.drinkFrom != null || w.drinkPeak != null || w.drinkTo != null;
}

class _HeroPhoto extends StatelessWidget {
  final Wine wine;
  const _HeroPhoto({required this.wine});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (wine.photoUrl != null)
            NativeNetworkImage(
              url: wine.photoUrl!,
              width: double.infinity,
              height: 400,
              fit: BoxFit.contain,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2A1010),
                    Color(0xFF1A0808),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.wine_bar,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  size: 80,
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    AppColors.bg2.withValues(alpha: 0.6),
                    AppColors.bg2,
                  ],
                  stops: const [0.0, 0.4, 0.75, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final WineType type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = wineTypeColor(type);
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
            wineTypeLabel(type),
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

class _EstimateMarketButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _EstimateMarketButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold),
              )
            else
              const Icon(Icons.trending_up, size: 15, color: AppColors.gold),
            const SizedBox(width: 8),
            Text(
              loading ? 'Estimation...' : 'Estimer la valeur marchande',
              style: const TextStyle(color: AppColors.gold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<_StatTileData> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 400;
      if (!compact || stats.length <= 2) {
        return Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              Expanded(child: _StatTile(data: stats[i], compact: compact)),
              if (i < stats.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      }
      return Column(
        children: [
          for (var i = 0; i < stats.length; i += 2) ...[
            Row(
              children: [
                Expanded(child: _StatTile(data: stats[i], compact: true)),
                const SizedBox(width: 10),
                Expanded(
                  child: i + 1 < stats.length
                      ? _StatTile(data: stats[i + 1], compact: true)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            if (i + 2 < stats.length) const SizedBox(height: 10),
          ],
        ],
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  final _StatTileData data;
  final bool compact;
  const _StatTile({required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14, vertical: 12),
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
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              text: data.value,
              style: AppText.serif(
                color: AppColors.gold2,
                fontSize: compact ? 18 : 22,
                fontWeight: FontWeight.w500,
                height: 1.1,
              ),
              children: [
                if (data.suffix != null)
                  TextSpan(
                    text: data.suffix,
                    style: AppText.sans(
                      color: AppColors.text3,
                      fontSize: compact ? 10 : 11,
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

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 420;
      return _Section(
        title: 'Origine',
        child: Column(
          children: [
            if (compact)
              for (final e in entries)
                _KvLine(label: e.$1, value: e.$2, compactLabel: true)
            else
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
              _KvLine(label: 'Adresse', value: wine.domainAddress, fullWidth: true, compactLabel: compact),
          ],
        ),
      );
    });
  }
}

class _KvLine extends StatelessWidget {
  final String label;
  final String value;
  final bool fullWidth;
  final bool compactLabel;
  const _KvLine({
    required this.label,
    required this.value,
    this.fullWidth = false,
    this.compactLabel = false,
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
            width: compactLabel ? 92 : 110,
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
          const SizedBox(width: 12),
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

class _GardeSection extends StatefulWidget {
  final Wine wine;
  final BottleFormat format;
  const _GardeSection({required this.wine, required this.format});

  @override
  State<_GardeSection> createState() => _GardeSectionState();
}

class _GardeSectionState extends State<_GardeSection> {
  @override
  Widget build(BuildContext context) {
    final offset = widget.format.gardeOffset;
    return _Section(
      title: 'Période de garde${offset != 0 ? ' (${offset > 0 ? '+' : ''}$offset ans, ${widget.format.label})' : ''}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: _GardeTimeline(wine: widget.wine, gardeOffset: offset),
      ),
    );
  }
}

class _GardeTimeline extends StatelessWidget {
  final Wine wine;
  final int gardeOffset;
  const _GardeTimeline({required this.wine, this.gardeOffset = 0});

  @override
  Widget build(BuildContext context) {
    int? shift(int? v) => v != null ? v + gardeOffset : null;
    final from = shift(wine.drinkFrom);
    final peak = shift(wine.drinkPeak);
    final to = shift(wine.drinkTo);
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
        final nowX = pos(now) * w;
        final markerXs = [
          if (from != null) pos(from) * w,
          if (peak != null) pos(peak) * w,
          if (to != null) pos(to) * w,
        ];
        final nowLabelAbove = markerXs.any((mx) => (nowX - mx).abs() < 55);
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
                left: nowX - 1,
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
                left: nowX - 35,
                top: nowLabelAbove ? 4 : 60,
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
                        fmtDate(critique.date!),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < bottles.length; i++) ...[
            _BottleCard(
              bottle: bottles[i],
              index: i + 1,
              onEdit: () => showEditBottle(context, bottles[i]),
              onDelete: () => _confirmDeleteBottle(context, bottles[i]),
              onDrink: () => showDrinkBottleDialog(context, bottles[i]),
            ),
            if (i < bottles.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => showAddBottles(context, wine),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x66C9A84C)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: AppColors.gold2, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Ajouter une bouteille',
                      style: AppText.sans(
                        color: AppColors.gold2,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteBottle(BuildContext context, Bottle bottle) async {
  final confirm = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border2),
      ),
      title: Text(
        'Supprimer la bouteille ?',
        style: AppText.serif(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        bottle.location.isEmpty
            ? 'Cette bouteille sera supprimée définitivement.'
            : 'La bouteille à l\'emplacement « ${bottle.location} » sera supprimée définitivement.',
        style: AppText.sans(color: AppColors.text2, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Annuler', style: AppText.sans(color: AppColors.text2)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB23A48),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Supprimer',
            style: AppText.sans(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    ),
  );
  if (confirm != true) return;
  try {
    await CaveService.deleteBottle(bottle.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.gold,
          content: Text(
            'Bouteille supprimée',
            style: AppText.sans(
              color: const Color(0xFF1A1408),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB23A48),
          content: Text(
            'Erreur : $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }
}

class _BottleCard extends StatelessWidget {
  final Bottle bottle;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDrink;
  const _BottleCard({
    required this.bottle,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    required this.onDrink,
  });

  @override
  Widget build(BuildContext context) {
    final b = bottle;
    final metaParts = <String>[
      if (b.source != null) b.source!.label,
      if (b.purchaseYear != null) 'achetée en ${b.purchaseYear}',
      'ajoutée le ${fmtDate(b.createdAt)}',
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne principale : numéro + contenu + prix
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                        const Icon(Icons.place_outlined, size: 13, color: AppColors.text3),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            b.location.isNotEmpty
                                ? 'Emplacement ${b.location}'
                                : 'Sans emplacement',
                            style: AppText.sans(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        metaParts.join(' · '),
                        style: AppText.sans(color: AppColors.text3, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (b.isGift && (b.giftFrom.isNotEmpty || b.giftOccasion.isNotEmpty || b.giftDate != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0x26C9A84C),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            [
                              'CADEAU',
                              if (b.giftFrom.isNotEmpty) 'de ${b.giftFrom}',
                              if (b.giftOccasion.isNotEmpty) b.giftOccasion,
                              if (b.giftDate != null) fmtDate(b.giftDate!),
                            ].join(' · '),
                            style: AppText.sans(
                              color: AppColors.gold2,
                              fontSize: 9,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w700,
                            ),
                            softWrap: true,
                          ),
                        ),
                      ),
                    if (b.status == BottleStatus.drunk)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0x1A8B5CF6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x338B5CF6)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  _DrunkChip(label: 'BUE', icon: Icons.wine_bar),
                                  if (b.drunkAt != null)
                                    _DrunkChip(label: fmtDate(b.drunkAt!), icon: Icons.calendar_today_outlined),
                                  if (b.drunkRating != null)
                                    _DrunkChip(label: '${b.drunkRating}/100', icon: Icons.star_outline),
                                  if (b.drunkLocation != null && b.drunkLocation!.isNotEmpty)
                                    _DrunkChip(label: b.drunkLocation!, icon: Icons.location_on_outlined),
                                ],
                              ),
                              if (b.drunkNote != null && b.drunkNote!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    b.drunkNote!,
                                    style: AppText.sans(color: const Color(0xCC8B5CF6), fontSize: 11),
                                    softWrap: true,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (b.purchasePrice != null) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${b.purchasePrice!.toStringAsFixed(0)} \$',
                      style: AppText.serif(
                        color: AppColors.gold2,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (b.marketValue != null && b.marketValue != b.purchasePrice)
                      Text(
                        'val. ${b.marketValue!.toStringAsFixed(0)} \$',
                        style: AppText.sans(color: AppColors.text3, fontSize: 10),
                      ),
                  ],
                ),
              ],
            ],
          ),
          // Ligne d'actions en bas à droite
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (bottle.status != BottleStatus.drunk)
                _BottleAction(
                  icon: Icons.wine_bar_outlined,
                  tooltip: 'Bue',
                  onTap: onDrink,
                )
              else
                _BottleAction(
                  icon: Icons.rate_review_outlined,
                  tooltip: 'Modifier dégustation',
                  onTap: onDrink,
                ),
              const SizedBox(width: 6),
              _BottleAction(icon: Icons.edit_outlined, tooltip: 'Modifier', onTap: onEdit),
              const SizedBox(width: 6),
              _BottleAction(icon: Icons.delete_outline, tooltip: 'Supprimer', danger: true, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _DrunkChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _DrunkChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFF8B5CF6)),
        const SizedBox(width: 3),
        Text(
          label,
          style: AppText.sans(color: const Color(0xFF8B5CF6), fontSize: 11),
        ),
      ],
    );
  }
}

class _BottleAction extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback onTap;
  const _BottleAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_BottleAction> createState() => _BottleActionState();
}

// ─────────────────────────────────────────────────────────────────────────────

class _BottleActionState extends State<_BottleAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.danger ? const Color(0xFFB23A48) : AppColors.gold2;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _hover
                  ? baseColor.withValues(alpha: 0.18)
                  : AppColors.bg4.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(
                color: _hover
                    ? baseColor.withValues(alpha: 0.6)
                    : AppColors.border2,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: 16,
              color: _hover ? baseColor : AppColors.text2,
            ),
          ),
        ),
      ),
    );
  }
}
