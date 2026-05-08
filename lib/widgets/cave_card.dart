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
  final GardeInfo? Function(WineRow) gardeFor;
  final void Function(List<Bottle> bottles)? onDrink;
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
        garde: gardeFor(rows[i]),
        onDrink: onDrink,
        onSommelier: onSommelier,
      ),
    );
  }
}

String? _flagFor(String country) {
  final c = country.trim().toLowerCase();
  if (c.isEmpty) return null;
  const flags = {
    'france': '🇫🇷',
    'italie': '🇮🇹', 'italy': '🇮🇹',
    'espagne': '🇪🇸', 'spain': '🇪🇸',
    'portugal': '🇵🇹',
    'allemagne': '🇩🇪', 'germany': '🇩🇪',
    'autriche': '🇦🇹', 'austria': '🇦🇹',
    'suisse': '🇨🇭', 'switzerland': '🇨🇭',
    'belgique': '🇧🇪', 'belgium': '🇧🇪',
    'royaume-uni': '🇬🇧', 'angleterre': '🇬🇧', 'united kingdom': '🇬🇧',
    'états-unis': '🇺🇸', 'etats-unis': '🇺🇸', 'usa': '🇺🇸',
        'united states': '🇺🇸', 'amérique': '🇺🇸',
    'canada': '🇨🇦',
    'argentine': '🇦🇷', 'argentina': '🇦🇷',
    'chili': '🇨🇱', 'chile': '🇨🇱',
    'australie': '🇦🇺', 'australia': '🇦🇺',
    'nouvelle-zélande': '🇳🇿', 'nouvelle zelande': '🇳🇿', 'new zealand': '🇳🇿',
    'afrique du sud': '🇿🇦', 'south africa': '🇿🇦',
    'grèce': '🇬🇷', 'grece': '🇬🇷', 'greece': '🇬🇷',
    'hongrie': '🇭🇺', 'hungary': '🇭🇺',
    'liban': '🇱🇧', 'lebanon': '🇱🇧',
    'mexique': '🇲🇽', 'mexico': '🇲🇽',
    'uruguay': '🇺🇾',
    'brésil': '🇧🇷', 'bresil': '🇧🇷', 'brazil': '🇧🇷',
    'japon': '🇯🇵', 'japan': '🇯🇵',
    'chine': '🇨🇳', 'china': '🇨🇳',
    'géorgie': '🇬🇪', 'georgie': '🇬🇪', 'georgia': '🇬🇪',
    'roumanie': '🇷🇴', 'romania': '🇷🇴',
    'bulgarie': '🇧🇬', 'bulgaria': '🇧🇬',
    'croatie': '🇭🇷', 'croatia': '🇭🇷',
    'slovénie': '🇸🇮', 'slovenie': '🇸🇮', 'slovenia': '🇸🇮',
    'turquie': '🇹🇷', 'turkey': '🇹🇷',
    'maroc': '🇲🇦', 'morocco': '🇲🇦',
  };
  for (final entry in flags.entries) {
    if (c.contains(entry.key)) return entry.value;
  }
  return null;
}

bool _isBurgundyRegion(String region) {
  final r = region.toLowerCase();
  return r.contains('bourgogne') ||
      r.contains('burgundy') ||
      r.contains('beaujolais');
}

class _CaveCard extends StatelessWidget {
  final WineRow row;
  final VoidCallback onTap;
  final GardeInfo? garde;
  final void Function(List<Bottle> bottles)? onDrink;
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
    final isGift = bottles.any((b) => b.isGift);
    final flag = _flagFor(w.country);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header : photo + identité + géo ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: w.photoUrl != null
                        ? NativeNetworkImage(
                            url: w.photoUrl!,
                            width: 64,
                            height: 90,
                          )
                        : Container(
                            width: 64,
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.bg3,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.wine_bar,
                              size: 28,
                              color: wineTypeColor(w.type)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom + millésime pill (top-aligned, le nom peut wrap)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: wineTypeColor(w.type),
                                  shape: BoxShape.circle,
                                ),
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
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (w.vintage != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.bg3,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  w.vintage.toString(),
                                  style: AppText.serif(
                                    color: AppColors.gold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Domaine (wrap libre)
                        if (w.domaine.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            w.domaine,
                            style: AppText.sans(
                              color: AppColors.gold2,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                        // Géo line : flag · pays · région · appellation [· climat]
                        const SizedBox(height: 5),
                        _buildGeoLine(w, flag),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Divider ──
            const Divider(height: 1, color: AppColors.border),
            // ── Footer : chips + garde + actions ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip('$qty × $format', Icons.inventory_2_outlined),
                        if (price != null)
                          _chipPrice('${price.toStringAsFixed(0)} \$'),
                        if (isGift) _chipGift(),
                        if (garde != null) _gardeBadge(w),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (onSommelier != null)
                    _ActionButton(
                      icon: Icons.thermostat_outlined,
                      color: const Color(0xFF7CD492),
                      tooltip: 'Sommelier',
                      onTap: () => onSommelier!(w),
                    ),
                  if (onDrink != null) ...[
                    const SizedBox(width: 6),
                    _ActionButton(
                      icon: Icons.wine_bar,
                      color: const Color(0xFFB23A48),
                      tooltip: 'Boire',
                      onTap: () => onDrink!(bottles),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeoLine(Wine w, String? flag) {
    final showClimat = _isBurgundyRegion(w.region) && w.climat.isNotEmpty;
    final parts = <String>[
      if (w.country.isNotEmpty) w.country,
      if (w.region.isNotEmpty) w.region,
      if (w.appellation.isNotEmpty) w.appellation,
    ];
    if (parts.isEmpty && !showClimat) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (flag != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(flag, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 5),
        ],
        Expanded(
          child: Text.rich(
            TextSpan(
              style: AppText.sans(
                color: AppColors.text3,
                fontSize: 11,
                height: 1.35,
              ),
              children: [
                TextSpan(text: parts.join(' · ')),
                if (showClimat) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(
                    text: w.climat,
                    style: AppText.sans(
                      color: AppColors.gold2,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gardeBadge(Wine w) {
    final g = garde!;
    final isApogee = g.label == 'Apogée';
    const goldDeep = Color(0xFFB8860B);
    const goldMid = Color(0xFFD4A843);
    const goldLight = Color(0xFFF5E6A3);

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isApogee
              ? const [goldDeep, goldMid, goldLight]
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

    if (g.windowShort.isEmpty) return badge;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badge,
        const SizedBox(height: 2),
        Text(
          g.windowShort,
          style: AppText.sans(
            color: g.color.withValues(alpha: 0.7),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, IconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
            const SizedBox(width: 4),
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

  Widget _chipPrice(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: AppText.sans(
          color: AppColors.gold,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _chipGift() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE89DA6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: const Color(0xFFE89DA6).withValues(alpha: 0.4)),
      ),
      child: const Text('🎁', style: TextStyle(fontSize: 11)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }
}
