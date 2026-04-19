import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../services/cave_service.dart';
import 'add_wine_dialog.dart';
import 'settings_screen.dart';
import 'wine_detail_screen.dart';

class AppColors {
  static const bg = Color(0xFF0E0C0A);
  static const bg2 = Color(0xFF161310);
  static const bg3 = Color(0xFF1E1A16);
  static const bg4 = Color(0xFF252018);
  static const gold = Color(0xFFC9A84C);
  static const gold2 = Color(0xFFE8C97A);
  static const text = Color(0xFFE8E0D0);
  static const text2 = Color(0xFFA09070);
  static const text3 = Color(0xFF6A5A40);
  static const border = Color(0x26B48C50);
  static const border2 = Color(0x4DB48C50);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  final List<_NavEntry> _entries = [
    _NavEntry.item(emoji: '🍷', label: 'Ma Cave'),
    _NavEntry.item(emoji: '🗄️', label: 'Cellier'),
    _NavEntry.item(emoji: '✦', label: 'Ajouter'),
    _NavEntry.sep(),
    _NavEntry.item(emoji: '🫗', label: 'Bouteilles bues'),
    _NavEntry.item(emoji: '🍽️', label: 'Accords mets-vins'),
    _NavEntry.item(emoji: '🔔', label: 'Alertes'),
    _NavEntry.item(emoji: '◈', label: 'Statistiques'),
    _NavEntry.item(emoji: '🌍', label: 'Carte des domaines'),
    _NavEntry.item(emoji: '✨', label: 'Liste de souhaits'),
    _NavEntry.sep(),
    _NavEntry.item(emoji: '⚙', label: 'Paramètres'),
  ];

  List<_NavEntry> get _items =>
      _entries.where((e) => !e.isSeparator).toList();

  void _openAddWine() {
    showAddWineDialog(context);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: isWide
          ? null
          : AppBar(
              backgroundColor: AppColors.bg2,
              iconTheme: const IconThemeData(color: AppColors.text),
              title: Text(
                _items[_selectedIndex].label!,
                style: AppText.serif(
                  color: AppColors.gold2,
                  fontSize: 22,
                ),
              ),
            ),
      drawer: isWide ? null : Drawer(child: _buildSidebar()),
      body: Row(
        children: [
          if (isWide) _buildSidebar(),
          Expanded(child: _buildMain()),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cave de\nJonathan Laberge',
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 24,
                    height: 1.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'GESTIONNAIRE DE VINS',
                  style: AppText.sans(
                    color: AppColors.text3,
                    fontSize: 10,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                if (entry.isSeparator) {
                  return Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    color: AppColors.border,
                  );
                }
                final itemIndex = _entries
                    .take(index + 1)
                    .where((e) => !e.isSeparator)
                    .length -
                    1;
                final selected = itemIndex == _selectedIndex;
                return _NavItem(
                  emoji: entry.emoji!,
                  label: entry.label!,
                  selected: selected,
                  onTap: () {
                    if (MediaQuery.of(context).size.width <= 900) {
                      Navigator.pop(context);
                    }
                    if (entry.label == 'Ajouter') {
                      _openAddWine();
                    } else {
                      setState(() => _selectedIndex = itemIndex);
                    }
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Prêt',
                  style: AppText.sans(
                    color: AppColors.text3,
                    fontSize: 11,
                  ),
                ),
                _smallButton('↻', onTap: () {}),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallButton(String label, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border2),
        ),
        child: Text(
          label,
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildMain() {
    return Column(
      children: [
        _buildTopbar(),
        Expanded(
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildTopbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            _items[_selectedIndex].label!,
            style: AppText.serif(
              color: AppColors.gold2,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  style: AppText.sans(
                    color: AppColors.text,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Rechercher…',
                    hintStyle: AppText.sans(
                      color: AppColors.text3,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search, color: AppColors.text3, size: 18),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _ctaButton('+ Ajouter', onTap: _openAddWine),
        ],
      ),
    );
  }

  Widget _ctaButton(String label, {required VoidCallback onTap}) {
    return Material(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: AppText.sans(
              color: const Color(0xFF1A1408),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final label = _items[_selectedIndex].label!;
    if (label == 'Ma Cave') return _buildCavePage();
    if (label == 'Paramètres') return const SettingsScreen();
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          label,
          style: AppText.serif(
            color: AppColors.text2,
            fontSize: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildCavePage() {
    return StreamBuilder<List<Wine>>(
      stream: CaveService.wines(),
      builder: (context, wineSnap) {
        if (wineSnap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }
        final wines = wineSnap.data ?? [];

        return StreamBuilder<List<Bottle>>(
          stream: CaveService.bottlesInCave(),
          builder: (context, bottleSnap) {
            final bottles = bottleSnap.data ?? [];

            final grouped = <String, _WineRow>{};
            for (final wine in wines) {
              final wineBottles = bottles
                  .where((b) => b.wineId == wine.id)
                  .toList();
              if (wineBottles.isEmpty) continue;
              final byFormat = <BottleFormat, List<Bottle>>{};
              for (final b in wineBottles) {
                byFormat.putIfAbsent(b.format, () => []).add(b);
              }
              for (final entry in byFormat.entries) {
                final key = '${wine.id}::${entry.key.name}';
                grouped[key] = _WineRow(wine: wine, bottles: entry.value);
              }
            }

            var rows = grouped.values.toList();

            if (_searchQuery.isNotEmpty) {
              rows = rows.where((r) {
                final w = r.wine;
                final search = _searchQuery;
                return w.name.toLowerCase().contains(search) ||
                    w.producer.toLowerCase().contains(search) ||
                    w.country.toLowerCase().contains(search) ||
                    w.region.toLowerCase().contains(search) ||
                    w.appellation.toLowerCase().contains(search) ||
                    w.grapes.toLowerCase().contains(search) ||
                    w.domaine.toLowerCase().contains(search) ||
                    w.village.toLowerCase().contains(search) ||
                    (w.vintage?.toString().contains(search) ?? false);
              }).toList();
            }

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Cave',
                            style: AppText.serif(
                              color: AppColors.gold2,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bg3,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.border2),
                            ),
                            child: Text(
                              '${rows.length} vin${rows.length > 1 ? 's' : ''}',
                              style: AppText.sans(
                                color: AppColors.text2,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Text('🍷', style: AppText.emoji(fontSize: 48)),
                            const SizedBox(height: 14),
                            Text(
                              'Aucun vin dans la cave',
                              style: AppText.serif(
                                color: AppColors.text2,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(child: _buildCaveTable(rows)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCaveTable(List<_WineRow> rows) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: AppColors.bg3,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: LayoutBuilder(
            builder: (context, c) => _CaveRowLayout(
              width: c.maxWidth,
              child: _buildHeaderCells(c.maxWidth),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              return _CaveDataRow(
                row: row,
                onTap: () => _openWineDetail(row),
                gardeFor: _gardeLabel,
              );
            },
          ),
        ),
      ],
    );
  }

  void _openWineDetail(_WineRow row) {
    showWineDetail(context, wine: row.wine, bottles: row.bottles);
  }

  List<Widget> _buildHeaderCells(double w) {
    final cols = _CaveColumns.forWidth(w);
    final headers = <(String, double?, int?)>[
      ('', cols.photoW, null),
      ('VIN', null, 4),
      if (cols.showType) ('TYPE', cols.typeW, null),
      ('MILL.', cols.vintageW, null),
      if (cols.showAppellation) ('APPELLATION', null, 3),
      ('RÉGION', null, 3),
      if (cols.showDomaine) ('DOMAINE', null, 2),
      if (cols.showGrapes) ('CÉPAGES', null, 3),
      if (cols.showRating) ('NOTE', cols.ratingW, null),
      ('GARDE', cols.gardeW, null),
      if (cols.showApogee) ('APOGÉE', cols.apogeeW, null),
      if (cols.showFormat) ('FORMAT', cols.formatW, null),
      if (cols.showPrice) ('PRIX', cols.priceW, null),
      if (cols.showValue) ('VALEUR', cols.valueW, null),
      ('QTÉ', cols.qtyW, null),
    ];
    final headerStyle = AppText.sans(
      color: AppColors.text3,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    );
    return headers.map((h) {
      final text = Text(h.$1, style: headerStyle);
      if (h.$2 != null) return SizedBox(width: h.$2, child: text);
      return Expanded(flex: h.$3 ?? 1, child: text);
    }).toList();
  }

  _GardeInfo? _gardeLabel(Wine w) {
    if (w.drinkFrom == null && w.drinkPeak == null && w.drinkTo == null) {
      return null;
    }
    final now = DateTime.now().year;
    if (w.drinkTo != null && now > w.drinkTo!) {
      return _GardeInfo('Passé', const Color(0xFFC62828));
    }
    if (w.drinkPeak != null && (now - w.drinkPeak!).abs() <= 2) {
      return _GardeInfo('Apogée', const Color(0xFFF5D060));
    }
    if (w.drinkFrom != null && now >= w.drinkFrom!) {
      return _GardeInfo('À boire', const Color(0xFF2E7D32));
    }
    if (w.drinkFrom != null && now < w.drinkFrom!) {
      return _GardeInfo('Garde', const Color(0xFF546E7A));
    }
    return _GardeInfo('À boire', const Color(0xFF2E7D32));
  }
}

class _GardeInfo {
  final String label;
  final Color color;
  const _GardeInfo(this.label, this.color);
}

class _WineRow {
  final Wine wine;
  final List<Bottle> bottles;
  const _WineRow({required this.wine, required this.bottles});
}

class _NavEntry {
  final String? emoji;
  final String? label;
  final bool isSeparator;

  const _NavEntry.item({required String this.emoji, required String this.label})
      : isSeparator = false;

  const _NavEntry.sep()
      : emoji = null,
        label = null,
        isSeparator = true;
}

class _NavItem extends StatefulWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final bg = selected
        ? const Color(0x14C9A84C)
        : _hover
            ? const Color(0x0FC9A84C)
            : Colors.transparent;
    final color = selected
        ? AppColors.gold2
        : _hover
            ? AppColors.text
            : AppColors.text2;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.gold : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(15, 10, 18, 10),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: Text(
                  widget.emoji,
                  style: AppText.emoji(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppText.sans(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaveColumns {
  final double photoW = 44;
  final double typeW = 74;
  final double vintageW = 56;
  final double ratingW = 50;
  final double gardeW = 80;
  final double formatW = 70;
  final double priceW = 72;
  final double valueW = 78;
  final double apogeeW = 60;
  final double qtyW = 46;

  final bool showType;
  final bool showAppellation;
  final bool showGrapes;
  final bool showRating;
  final bool showFormat;
  final bool showPrice;
  final bool showApogee;
  final bool showValue;
  final bool showDomaine;

  _CaveColumns._({
    required this.showType,
    required this.showAppellation,
    required this.showGrapes,
    required this.showRating,
    required this.showFormat,
    required this.showPrice,
    required this.showApogee,
    required this.showValue,
    required this.showDomaine,
  });

  factory _CaveColumns.forWidth(double w) {
    return _CaveColumns._(
      showType: w >= 480,
      showFormat: w >= 560,
      showPrice: w >= 640,
      showRating: w >= 720,
      showAppellation: w >= 820,
      showGrapes: w >= 920,
      showApogee: w >= 1020,
      showValue: w >= 1120,
      showDomaine: w >= 1240,
    );
  }
}

class _CaveRowLayout extends StatelessWidget {
  final double width;
  final List<Widget> child;
  const _CaveRowLayout({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var i = 0; i < child.length; i++) ...[
          child[i],
          if (i < child.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }
}

class _CaveDataRow extends StatefulWidget {
  final _WineRow row;
  final VoidCallback onTap;
  final _GardeInfo? Function(Wine) gardeFor;

  const _CaveDataRow({
    required this.row,
    required this.onTap,
    required this.gardeFor,
  });

  @override
  State<_CaveDataRow> createState() => _CaveDataRowState();
}

class _CaveDataRowState extends State<_CaveDataRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.row.wine;
    final bottles = widget.row.bottles;
    final qty = bottles.length;
    final firstFormat = bottles.first.format.label;
    final formats = bottles.map((b) => b.format.label).toSet();
    final mixedFormats = formats.length > 1;
    final price = bottles.first.purchasePrice;
    final pricesAll = bottles
        .map((b) => b.purchasePrice)
        .whereType<double>()
        .toList();
    final mixedPrices = pricesAll.toSet().length > 1;
    final garde = widget.gardeFor(w);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              final cols = _CaveColumns.forWidth(c.maxWidth);
              final totalValue = bottles.fold<double>(
                0,
                (s, b) => s + (b.marketValue ?? b.purchasePrice ?? 0),
              );
              return _CaveRowLayout(
                width: c.maxWidth,
                child: [
                  SizedBox(width: cols.photoW, child: _photoCell(w)),
                  Expanded(flex: 4, child: _vinCell(w)),
                  if (cols.showType)
                    SizedBox(width: cols.typeW, child: _typeCell(w)),
                  SizedBox(width: cols.vintageW, child: _vintageCell(w)),
                  if (cols.showAppellation)
                    Expanded(flex: 3, child: _textCell(w.appellation)),
                  Expanded(flex: 3, child: _regionCell(w)),
                  if (cols.showDomaine)
                    Expanded(flex: 2, child: _textCell(w.domaine)),
                  if (cols.showGrapes)
                    Expanded(flex: 3, child: _textCell(w.grapes)),
                  if (cols.showRating)
                    SizedBox(width: cols.ratingW, child: _ratingCell(w)),
                  SizedBox(width: cols.gardeW, child: _gardeCell(garde)),
                  if (cols.showApogee)
                    SizedBox(width: cols.apogeeW, child: _apogeeCell(w)),
                  if (cols.showFormat)
                    SizedBox(
                      width: cols.formatW,
                      child: _formatCell(firstFormat, mixedFormats),
                    ),
                  if (cols.showPrice)
                    SizedBox(
                      width: cols.priceW,
                      child: _priceCell(price, mixedPrices),
                    ),
                  if (cols.showValue)
                    SizedBox(
                      width: cols.valueW,
                      child: _valueCell(totalValue),
                    ),
                  SizedBox(width: cols.qtyW, child: _qtyCell(qty)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _photoCell(Wine w) {
    if (w.photoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          w.photoUrl!,
          width: 32,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _ph(),
        ),
      );
    }
    return _ph();
  }

  Widget _ph() => Container(
        width: 32,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border),
        ),
        child: const Icon(Icons.wine_bar, color: AppColors.text3, size: 16),
      );

  Widget _vinCell(Wine w) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          w.name,
          style: AppText.serif(
            color: AppColors.text,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (w.producer.isNotEmpty)
          Text(
            w.producer,
            style: AppText.sans(color: AppColors.text3, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _typeCell(Wine w) {
    final color = _wineTypeColor(w.type);
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
              _wineTypeLabel(w.type),
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
      ),
    );
  }

  Widget _textCell(String value) {
    if (value.isEmpty) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    return Text(
      value,
      style: AppText.sans(color: AppColors.text2, fontSize: 12),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _regionCell(Wine w) {
    final parts = [w.region, w.country].where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          w.region.isNotEmpty ? w.region : w.country,
          style: AppText.sans(
            color: AppColors.text,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (w.region.isNotEmpty && w.country.isNotEmpty)
          Text(
            w.country,
            style: AppText.sans(color: AppColors.text3, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _ratingCell(Wine w) {
    if (w.rating == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, color: AppColors.gold2, size: 12),
        const SizedBox(width: 3),
        Text(
          '${w.rating}',
          style: AppText.sans(
            color: AppColors.gold2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _apogeeCell(Wine w) {
    if (w.drinkPeak == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    return Text(
      '${w.drinkPeak}',
      style: AppText.sans(
        color: AppColors.text2,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _valueCell(double total) {
    if (total <= 0) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    return Text(
      '${total.toStringAsFixed(0)} \$',
      style: AppText.sans(
        color: AppColors.gold2,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _gardeCell(_GardeInfo? garde) {
    if (garde == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: garde.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        garde.label,
        style: AppText.sans(
          color: garde.color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
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

  Widget _priceCell(double? price, bool mixed) {
    if (price == null) {
      return Text('—',
          style: AppText.sans(color: AppColors.text3, fontSize: 12));
    }
    return Text(
      mixed
          ? '~${price.toStringAsFixed(0)} \$'
          : '${price.toStringAsFixed(0)} \$',
      style: AppText.sans(
        color: AppColors.text,
        fontSize: 12,
        fontWeight: FontWeight.w500,
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

  Color _wineTypeColor(WineType t) {
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

  String _wineTypeLabel(WineType t) {
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
        return 'BULLES';
    }
  }
}
