import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../models/wish_wine.dart';
import '../models/bottle.dart';
import '../models/cave_column.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/wine_type_helpers.dart';
import 'native_image.dart';

class GardeInfo {
  final String label;
  final Color color;
  final int? drinkFrom;
  final int? drinkPeak;
  final int? drinkTo;

  const GardeInfo(
    this.label,
    this.color, {
    this.drinkFrom,
    this.drinkPeak,
    this.drinkTo,
  });

  /// Format court "24-29-36" (2 derniers chiffres de drinkFrom-Peak-To).
  /// Retourne '' si aucune année. '·' à la place d'une année manquante.
  String get windowShort {
    if (drinkFrom == null && drinkPeak == null && drinkTo == null) {
      return '';
    }
    String s(int? y) =>
        y == null ? '·' : (y % 100).toString().padLeft(2, '0');
    return '${s(drinkFrom)}-${s(drinkPeak)}-${s(drinkTo)}';
  }

  static GardeInfo? fromWine(Wine w, {int gardeOffset = 0}) {
    if (w.drinkFrom == null && w.drinkPeak == null && w.drinkTo == null) {
      return null;
    }
    int? shift(int? v) => v == null ? null : v + gardeOffset;
    return _compute(
      drinkFrom: shift(w.drinkFrom),
      drinkPeak: shift(w.drinkPeak),
      drinkTo: shift(w.drinkTo),
    );
  }

  static GardeInfo? fromWineFormat(Wine w, BottleFormat format) =>
      fromWine(w, gardeOffset: format.gardeOffset);

  static GardeInfo? fromWish(WishWine w) {
    if (w.drinkFrom == null && w.drinkPeak == null && w.drinkTo == null) {
      return null;
    }
    return _compute(
      drinkFrom: w.drinkFrom,
      drinkPeak: w.drinkPeak,
      drinkTo: w.drinkTo,
    );
  }

  static GardeInfo _compute({
    int? drinkFrom,
    int? drinkPeak,
    int? drinkTo,
  }) {
    final now = DateTime.now().year;
    String label;
    Color color;
    if (drinkTo != null && now > drinkTo) {
      label = 'Passé';
      color = const Color(0xFFC62828);
    } else if (drinkFrom != null && now < drinkFrom) {
      label = 'Garde';
      color = const Color(0xFF546E7A);
    } else if (drinkPeak != null &&
        now >= drinkPeak &&
        now <= drinkPeak + 4) {
      label = 'Apogée';
      color = const Color(0xFFD4A843);
    } else if (drinkFrom == null &&
        drinkPeak != null &&
        now < drinkPeak) {
      label = 'Garde';
      color = const Color(0xFF546E7A);
    } else {
      label = 'À boire';
      color = const Color(0xFF2E7D32);
    }
    return GardeInfo(
      label,
      color,
      drinkFrom: drinkFrom,
      drinkPeak: drinkPeak,
      drinkTo: drinkTo,
    );
  }
}

class CellContext {
  final Wine wine;
  final List<Bottle> bottles;
  final int qty;
  final String firstFormat;
  final bool mixedFormats;
  final double? price;
  final bool mixedPrices;
  final GardeInfo? garde;
  final double totalValue;

  const CellContext({
    required this.wine,
    required this.bottles,
    required this.qty,
    required this.firstFormat,
    required this.mixedFormats,
    required this.price,
    required this.mixedPrices,
    required this.garde,
    required this.totalValue,
  });
}

class WineRow {
  final Wine wine;
  final List<Bottle> bottles;
  const WineRow({required this.wine, required this.bottles});
}

class CaveRowLayout extends StatelessWidget {
  final double width;
  final List<Widget> child;
  const CaveRowLayout({super.key, required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < child.length; i++) ...[
          child[i],
          if (i < child.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class CaveDataRow extends StatefulWidget {
  final WineRow row;
  final List<CaveColumn> columns;
  final VoidCallback onTap;
  final GardeInfo? Function(WineRow) gardeFor;
  final void Function(List<Bottle> bottles)? onDrink;
  final void Function(Wine wine)? onSommelier;

  const CaveDataRow({
    super.key,
    required this.row,
    required this.columns,
    required this.onTap,
    required this.gardeFor,
    this.onDrink,
    this.onSommelier,
  });

  @override
  State<CaveDataRow> createState() => _CaveDataRowState();
}

class _CaveDataRowState extends State<CaveDataRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.row.wine;
    final bottles = widget.row.bottles;
    final qty = bottles.length;
    final firstFormat = bottles.first.format.label;
    final formats = bottles.map((b) => b.format.label).toSet();
    final mixedFormats = formats.length > 1;
    final pricesAll = bottles
        .map((b) => b.purchasePrice)
        .whereType<double>()
        .toList();
    final price = pricesAll.isEmpty
        ? null
        : pricesAll.reduce((a, b) => a + b) / pricesAll.length;
    final mixedPrices = pricesAll.toSet().length > 1;
    final garde = widget.gardeFor(widget.row);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x14C9A84C) : Colors.transparent,
            border: Border(
              bottom: const BorderSide(color: AppColors.border),
              left: BorderSide(
                color: _hover ? AppColors.gold : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final totalValue = bottles.fold<double>(
                0,
                (s, b) => s + (b.marketValue ?? b.purchasePrice ?? 0),
              );
              final ctx = CellContext(
                wine: w,
                bottles: bottles,
                qty: qty,
                firstFormat: firstFormat,
                mixedFormats: mixedFormats,
                price: price,
                mixedPrices: mixedPrices,
                garde: garde,
                totalValue: totalValue,
              );
              final cells = widget.columns.map((col) {
                final cell = _cellFor(col, ctx);
                if (col.width != null) {
                  return SizedBox(width: col.width, child: cell);
                }
                return Expanded(flex: col.flex ?? 1, child: cell);
              }).toList();
              if (widget.onSommelier != null) {
                cells.add(SizedBox(
                  width: 30,
                  child: Tooltip(
                    message: 'Sommelier',
                    child: GestureDetector(
                      onTap: () => widget.onSommelier!(w),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF64B478).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF64B478).withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.thermostat_outlined, size: 14, color: Color(0xFF7CD492)),
                      ),
                    ),
                  ),
                ));
              }
              if (widget.onDrink != null) {
                cells.add(SizedBox(
                  width: 30,
                  child: Tooltip(
                    message: 'Bue',
                    child: GestureDetector(
                      onTap: () => widget.onDrink!(bottles),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB23A48).withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFB23A48).withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.liquor, size: 14, color: Color(0xFFE8667A)),
                      ),
                    ),
                  ),
                ));
              }
              return CaveRowLayout(width: c.maxWidth, child: cells);
            },
          ),
        ),
      ),
    );
  }

  Widget _cellFor(CaveColumn col, CellContext ctx) {
    switch (col) {
      case CaveColumn.photo:
        return _photoCell(ctx.wine);
      case CaveColumn.name:
        return _vinCell(ctx.wine, ctx.bottles.any((b) => b.isGift));
      case CaveColumn.type:
        return _typeCell(ctx.wine);
      case CaveColumn.vintage:
        return _vintageCell(ctx.wine);
      case CaveColumn.appellation:
        return _textCell(ctx.wine.appellation);
      case CaveColumn.region:
        return _regionCell(ctx.wine);
      case CaveColumn.country:
        return _textCell(ctx.wine.country);
      case CaveColumn.village:
        return _textCell(ctx.wine.village);
      case CaveColumn.climat:
        return _textCell(ctx.wine.climat);
      case CaveColumn.domaine:
        return _textCell(ctx.wine.domaine);
      case CaveColumn.domainAddress:
        return _textCell(ctx.wine.domainAddress);
      case CaveColumn.grapes:
        return _textCell(ctx.wine.grapes);
      case CaveColumn.alcohol:
        return _alcoholCell(ctx.wine);
      case CaveColumn.rating:
        return _ratingCell(ctx.wine);
      case CaveColumn.garde:
        return _gardeCell(ctx.garde, ctx.wine);
      case CaveColumn.drinkFrom:
        return _yearCell(ctx.wine.drinkFrom);
      case CaveColumn.apogee:
        return _yearCell(ctx.wine.drinkPeak, gold: true);
      case CaveColumn.drinkTo:
        return _yearCell(ctx.wine.drinkTo);
      case CaveColumn.format:
        return _formatCell(ctx.firstFormat, ctx.mixedFormats);
      case CaveColumn.source:
        return _sourceCell(ctx.bottles);
      case CaveColumn.purchaseYear:
        return _purchaseYearCell(ctx.bottles);
      case CaveColumn.price:
        return _priceCell(ctx.price, ctx.bottles);
      case CaveColumn.marketValue:
        return _marketValueCell(ctx.bottles);
      case CaveColumn.totalValue:
        return _valueCell(ctx.totalValue);
      case CaveColumn.location:
        return _locationCell(ctx.bottles);
      case CaveColumn.createdAt:
        return _createdAtCell(ctx.bottles);
      case CaveColumn.qty:
        return _qtyCell(ctx.qty);
    }
  }

  Widget _photoCell(Wine w) {
    final thumb = Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: w.thumbOrFull == null
            ? _ph()
            : NativeNetworkImage(
                url: w.thumbOrFull!,
                width: 42,
                height: 56,
              ),
      ),
    );
    // L'aperçu flottant agrandi utilise l'originale HD, pas la miniature.
    if (w.photoUrl == null) return thumb;
    return _PhotoHoverPreview(photoUrl: w.photoUrl!, child: thumb);
  }

  Widget _ph() => Container(
        width: 42,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.wine_bar, color: AppColors.text3, size: 16),
      );

  Widget _vinCell(Wine w, [bool isGift = false]) {
    final dotColor = wineTypeColor(w.type);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      w.name,
                      style: AppText.serif(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isGift) const Text('🎁', style: TextStyle(fontSize: 11)),
                ],
              ),
              if (w.producer.isNotEmpty)
                Text(
                  w.producer,
                  style: AppText.sans(color: AppColors.text3, fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _typeCell(Wine w) {
    final color = wineTypeColor(w.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              wineTypeLabel(w.type),
              style: AppText.sans(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vintageCell(Wine w) {
    if (w.vintage == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x1FC9A84C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x40C9A84C)),
      ),
      child: Text(
        '${w.vintage}',
        style: AppText.sans(
          color: AppColors.gold2,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _textCell(String value) {
    if (value.isEmpty) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    return Text(
      value,
      style: AppText.sans(color: AppColors.text2, fontSize: 11),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _regionCell(Wine w) {
    final label = w.region.isNotEmpty ? w.region : w.country;
    if (label.isEmpty) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    return Text(
      label,
      style: AppText.sans(
        color: AppColors.text,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _ratingCell(Wine w) {
    if (w.rating == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, color: AppColors.gold2, size: 11),
        const SizedBox(width: 3),
        Text(
          '${w.rating}',
          style: AppText.sans(
            color: AppColors.gold2,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _valueCell(double total) {
    if (total <= 0) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    return Text(
      '${total.toStringAsFixed(0)} \$',
      style: AppText.sans(
        color: AppColors.gold2,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _gardeCell(GardeInfo? garde, Wine w) {
    if (garde == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    final lines = <String>[];
    if (w.drinkFrom != null) lines.add('À boire dès : ${w.drinkFrom}');
    if (w.drinkPeak != null) lines.add('Apogée : ${w.drinkPeak}');
    if (w.drinkTo != null) lines.add('Fin de garde : ${w.drinkTo}');
    final isApogee = garde.label == 'Apogée';
    const goldDeep = Color(0xFFB8860B);
    const goldMid = Color(0xFFD4A843);
    const goldLight = Color(0xFFF5E6A3);
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isApogee
              ? [goldDeep, goldMid, goldLight]
              : [
                  garde.color.withValues(alpha: 0.25),
                  garde.color.withValues(alpha: 0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isApogee
              ? goldMid.withValues(alpha: 0.7)
              : garde.color.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        garde.label,
        style: AppText.sans(
          color: isApogee ? const Color(0xFF1A1408) : garde.color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final badgeWithWindow = garde.windowShort.isEmpty
        ? badge
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              badge,
              const SizedBox(height: 2),
              Text(
                garde.windowShort,
                style: AppText.sans(
                  color: garde.color.withValues(alpha: 0.7),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          );
    if (lines.isEmpty) return badgeWithWindow;
    return Tooltip(
      preferBelow: false,
      verticalOffset: 20,
      waitDuration: const Duration(milliseconds: 200),
      exitDuration: Duration.zero,
      showDuration: Duration.zero,
      richMessage: WidgetSpan(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < lines.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _gardeTooltipRow(lines[i]),
              ],
            ],
          ),
        ),
      ),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.zero,
      child: badgeWithWindow,
    );
  }

  Widget _gardeTooltipRow(String line) {
    final parts = line.split(' : ');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parts[0],
          style: AppText.sans(
            color: AppColors.text3,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          parts[1],
          style: AppText.sans(
            color: AppColors.gold2,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _formatCell(String label, bool mixed) {
    return Text(
      mixed ? 'Mixte' : label,
      style: AppText.sans(
        color: mixed ? AppColors.gold2 : AppColors.text2,
        fontSize: 11,
        fontWeight: mixed ? FontWeight.w600 : FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _priceCell(double? price, List<Bottle> bottles) {
    if (price == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    final prices = bottles
        .where((b) => b.purchasePrice != null)
        .map((b) => '${b.format.label} — ${b.purchasePrice!.toStringAsFixed(0)} \$')
        .toList();
    final label = '${price.toStringAsFixed(0)} \$';
    if (prices.length <= 1) {
      return Text(
        label,
        style: AppText.sans(
          color: AppColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Tooltip(
      richMessage: TextSpan(
        children: [
          for (var i = 0; i < prices.length; i++) ...[
            TextSpan(text: prices[i]),
            if (i < prices.length - 1) const TextSpan(text: '\n'),
          ],
        ],
        style: AppText.sans(color: AppColors.text, fontSize: 11),
      ),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      waitDuration: const Duration(milliseconds: 300),
      child: Text(
        '~$label',
        style: AppText.sans(
          color: AppColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _qtyCell(int qty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border2),
      ),
      child: Text(
        '$qty',
        style: AppText.sans(
          color: AppColors.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _alcoholCell(Wine w) {
    if (w.alcohol == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    return Text(
      '${w.alcohol!.toStringAsFixed(1)} %',
      style: AppText.sans(color: AppColors.text2, fontSize: 11),
    );
  }

  Widget _yearCell(int? year, {bool gold = false}) {
    if (year == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    return Text(
      '$year',
      style: AppText.sans(
        color: gold ? AppColors.gold2 : AppColors.text2,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _sourceCell(List<Bottle> bottles) {
    final sources = bottles.map((b) => b.source).toSet();
    if (sources.isEmpty || (sources.length == 1 && sources.first == null)) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    if (sources.length > 1) {
      return Text('Mixte',
          style: AppText.sans(
              color: AppColors.gold2,
              fontSize: 11,
              fontWeight: FontWeight.w600));
    }
    return Text(
      sources.first ?? '—',
      style: AppText.sans(color: AppColors.text2, fontSize: 11),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _purchaseYearCell(List<Bottle> bottles) {
    final years = bottles.map((b) => b.purchaseYear).whereType<int>().toSet();
    if (years.isEmpty) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    if (years.length > 1) {
      return Text('Mixte',
          style: AppText.sans(
              color: AppColors.gold2,
              fontSize: 11,
              fontWeight: FontWeight.w600));
    }
    return Text('${years.first}',
        style: AppText.sans(color: AppColors.text2, fontSize: 11));
  }

  Widget _marketValueCell(List<Bottle> bottles) {
    final values =
        bottles.map((b) => b.marketValue).whereType<double>().toList();
    if (values.isEmpty) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    final avg = values.reduce((a, b) => a + b) / values.length;
    return Text(
      '${avg.toStringAsFixed(0)} \$',
      style: AppText.sans(
        color: AppColors.text,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _locationCell(List<Bottle> bottles) {
    final locs = bottles
        .map((b) => b.location)
        .where((l) => l.isNotEmpty)
        .toSet();
    if (locs.isEmpty) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    if (locs.length > 1) {
      return Text(
        '${locs.length} cases',
        style: AppText.sans(
          color: AppColors.gold2,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Text(
      locs.first,
      style: AppText.sans(
        color: AppColors.text2,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _createdAtCell(List<Bottle> bottles) {
    final dates = bottles.map((b) => b.createdAt).toList();
    if (dates.isEmpty) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
    dates.sort();
    final d = dates.first;
    return Text(
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}',
      style: AppText.sans(color: AppColors.text2, fontSize: 11),
    );
  }
}

class _PhotoHoverPreview extends StatefulWidget {
  final String photoUrl;
  final Widget child;
  const _PhotoHoverPreview({required this.photoUrl, required this.child});

  @override
  State<_PhotoHoverPreview> createState() => _PhotoHoverPreviewState();
}

class _PhotoHoverPreviewState extends State<_PhotoHoverPreview> {
  OverlayEntry? _overlay;
  Offset _cursor = Offset.zero;

  void _show() {
    _overlay = OverlayEntry(builder: (_) {
      final screenH = MediaQuery.of(context).size.height;
      const previewW = 240.0;
      const previewH = 320.0;
      var top = _cursor.dy - previewH / 2;
      if (top < 8) top = 8;
      if (top + previewH > screenH - 8) top = screenH - previewH - 8;
      final left = _cursor.dx - previewW - 20;

      return Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: previewW,
              height: previewH,
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: NativeNetworkImage(
                  url: widget.photoUrl,
                  width: previewW,
                  height: previewH,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlay!);
  }

  void _hide() {
    _overlay?.remove();
    _overlay = null;
  }

  void _updatePosition(PointerEvent event) {
    _cursor = event.position;
    _overlay?.markNeedsBuild();
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (e) {
        _cursor = e.position;
        _show();
      },
      onHover: _updatePosition,
      onExit: (_) => _hide(),
      child: widget.child,
    );
  }
}
