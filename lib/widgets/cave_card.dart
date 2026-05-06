import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/wine_type_helpers.dart';
import 'cave_table.dart';
import 'native_image.dart';

class CaveCardList extends StatelessWidget {
  final List<WineRow> rows;
  final void Function(WineRow) onTap;
  final GardeInfo? Function(Wine) gardeFor;
  final void Function(Bottle bottle)? onDrink;
  final void Function(Wine wine)? onSommelier;

  const CaveCardList({
    super.key,
    required this.rows,
    required this.onTap,
    required this.gardeFor,
    this.onDrink,
    this.onSommelier,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: rows.length,
      itemBuilder: (context, i) => _CaveCard(
        row: rows[i],
        onTap: () => onTap(rows[i]),
        garde: gardeFor(rows[i].wine),
        onDrink: onDrink,
        onSommelier: onSommelier,
      ),
    );
  }
}

class _CaveCard extends StatelessWidget {
  final WineRow row;
  final VoidCallback onTap;
  final GardeInfo? garde;
  final void Function(Bottle bottle)? onDrink;
  final void Function(Wine wine)? onSommelier;

  const _CaveCard({
    required this.row,
    required this.onTap,
    this.garde,
    this.onDrink,
    this.onSommelier,
  });

  @override
  Widget build(BuildContext context) {
    final w = row.wine;
    final bottles = row.bottles;
    final qty = bottles.length;
    final price = bottles.first.purchasePrice;
    final format = bottles.first.format.label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: w.photoUrl != null
                  ? NativeNetworkImage(
                      url: w.photoUrl!,
                      width: 48,
                      height: 64,
                    )
                  : Container(
                      width: 48,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.bg3,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.wine_bar,
                        size: 22,
                        color: wineTypeColor(w.type).withValues(alpha: 0.5),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: wineTypeColor(w.type),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          w.name,
                          style: AppText.serif(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (w.vintage != null) w.vintage.toString(),
                      if (w.region.isNotEmpty) w.region,
                      if (w.appellation.isNotEmpty) w.appellation,
                    ].join(' · '),
                    style: AppText.sans(
                      color: AppColors.text3,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _chip('$qty', Icons.inventory_2_outlined),
                      const SizedBox(width: 6),
                      _chip(format, null),
                      if (price != null) ...[
                        const SizedBox(width: 6),
                        _chip('${price.toStringAsFixed(0)} \$', null),
                      ],
                      if (garde != null) ...[
                        const SizedBox(width: 6),
                        () {
                          final g = garde!;
                          final isApogee = g.label == 'Apogée';
                          const goldDeep = Color(0xFFB8860B);
                          const goldMid = Color(0xFFD4A843);
                          const goldLight = Color(0xFFF5E6A3);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isApogee
                                    ? [goldDeep, goldMid, goldLight]
                                    : [
                                        g.color.withValues(alpha: 0.25),
                                        g.color.withValues(alpha: 0.08),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isApogee
                                    ? goldMid.withValues(alpha: 0.7)
                                    : g.color.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              g.label,
                              style: AppText.sans(
                                color: isApogee ? const Color(0xFF1A1408) : g.color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                          );
                        }(),
                      ],
                      const Spacer(),
                      if (w.rating != null)
                        Text(
                          '${w.rating}',
                          style: AppText.serif(
                            color: AppColors.gold,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: AppColors.text3),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: AppText.sans(
              color: AppColors.text2,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
