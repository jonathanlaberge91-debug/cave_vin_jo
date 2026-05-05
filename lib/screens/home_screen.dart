import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/cave_table.dart';
import '../widgets/cave_card.dart';
import '../models/cave_column.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../services/cave_preferences_service.dart';
import '../services/cave_service.dart';
import 'add_wine_dialog.dart';
import 'cellier_screen.dart';
import 'settings_screen.dart';
import 'wine_detail_screen.dart';
import 'pairing_screen.dart';
import 'carte_screen.dart';
import 'stats_screen.dart';
import 'wine_cellar_screen.dart';
import 'govee_sensors_screen.dart';
import '../dialogs/drink_bottle_dialog.dart';
import '../dialogs/sommelier_dialog.dart';
import '../theme/date_format.dart';
import '../theme/wine_type_helpers.dart';
import '../models/drunk_column.dart';
import '../models/wish_wine.dart';
import '../models/wish_column.dart';
import '../services/wishlist_service.dart';
import '../dialogs/add_wish_dialog.dart';
import '../widgets/offline_banner.dart';
import '../widgets/cascade_filter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  bool _mobileSearchOpen = false;
  int _settingsSub = 0;
  CascadeFilterState _cascadeFilter = const CascadeFilterState();

  static const _settingsSubs = [
    (Icons.table_chart_outlined, 'Cave'),
    (Icons.grid_view_rounded, 'Celliers'),
    (Icons.wine_bar_outlined, 'Bouteilles bues'),
    (Icons.favorite_border, 'Liste de souhaits'),
    (Icons.bar_chart_outlined, 'Statistiques'),
    (Icons.key_outlined, 'Clés API'),
    (Icons.refresh_outlined, 'Actualisation'),
  ];

  final List<_NavEntry> _entries = [
    _NavEntry.item(icon: Icons.wine_bar, label: 'Ma Cave'),
    _NavEntry.item(icon: Icons.grid_view_rounded, label: 'Cellier'),
    _NavEntry.item(icon: Icons.add_circle_outline, label: 'Ajouter'),
    _NavEntry.sep(),
    _NavEntry.item(icon: Icons.local_bar_outlined, label: 'Bouteilles bues'),
    _NavEntry.item(icon: Icons.restaurant_outlined, label: 'Accords mets-vins'),
    _NavEntry.item(icon: Icons.thermostat_outlined, label: 'Wine CellR'),
    _NavEntry.item(icon: Icons.sensors_outlined, label: 'Capteurs Govee'),
    _NavEntry.item(icon: Icons.bar_chart_outlined, label: 'Statistiques'),
    _NavEntry.item(icon: Icons.map_outlined, label: 'Carte des domaines'),
    _NavEntry.item(icon: Icons.favorite_border, label: 'Liste de souhaits'),
    _NavEntry.sep(),
    _NavEntry.item(icon: Icons.settings_outlined, label: 'Paramètres'),
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

  List<Widget> _buildNavItems() {
    final items = <Widget>[];
    int itemIndex = 0;

    for (int i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.isSeparator) {
        items.add(Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.border,
        ));
        continue;
      }

      final currentItemIndex = itemIndex;
      items.add(_NavItem(
        icon: entry.icon!,
        label: entry.label!,
        selected: currentItemIndex == _selectedIndex,
        onTap: () {
          if (MediaQuery.of(context).size.width <= 900) {
            Navigator.pop(context);
          }
          if (entry.label == 'Ajouter') {
            _openAddWine();
          } else {
            setState(() => _selectedIndex = currentItemIndex);
          }
        },
      ));

      itemIndex++;
    }

    return items;
  }

  bool get _isSettingsSelected =>
      _items[_selectedIndex].label == 'Paramètres';

  Widget _buildSettingsSubMenu() {
    return Container(
      width: 180,
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
            child: Text(
              'PARAMÈTRES',
              style: AppText.sans(
                color: AppColors.text3,
                fontSize: 10,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: [
                for (int s = 0; s < _settingsSubs.length; s++)
                  _NavSubItem(
                    icon: _settingsSubs[s].$1,
                    label: _settingsSubs[s].$2,
                    selected: _settingsSub == s,
                    onTap: () => setState(() => _settingsSub = s),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
              title: _mobileSearchOpen
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                      style: AppText.sans(color: AppColors.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Rechercher…',
                        hintStyle: AppText.sans(color: AppColors.text3, fontSize: 14),
                        border: InputBorder.none,
                      ),
                    )
                  : const _AppBranding(compact: true),
              actions: [
                IconButton(
                  icon: Icon(
                    _mobileSearchOpen ? Icons.close : Icons.search,
                    color: AppColors.text,
                  ),
                  onPressed: () {
                    setState(() {
                      _mobileSearchOpen = !_mobileSearchOpen;
                      if (!_mobileSearchOpen) {
                        _searchController.clear();
                        _searchQuery = '';
                      }
                    });
                  },
                ),
              ],
            ),
      drawer: isWide ? null : Drawer(child: _buildSidebar()),
      floatingActionButton: (!isWide && _items[_selectedIndex].label == 'Ma Cave')
          ? FloatingActionButton(
              onPressed: _openAddWine,
              backgroundColor: AppColors.gold,
              child: const Icon(Icons.add, color: AppColors.bg),
            )
          : null,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Row(
              children: [
                if (isWide) _buildSidebar(),
                if (isWide && _isSettingsSelected) _buildSettingsSubMenu(),
                Expanded(child: _buildMain()),
              ],
            ),
          ),
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
            child: const _AppBranding(compact: false),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 10),
              children: _buildNavItems(),
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
            _items[_selectedIndex].label == 'Paramètres'
                ? 'Paramètres — ${_settingsSubs[_settingsSub].$2}'
                : _items[_selectedIndex].label!,
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
    if (label == 'Cellier') return CellierScreen(filter: _cascadeFilter, onFilterChanged: (f) => setState(() => _cascadeFilter = f));
    if (label == 'Bouteilles bues') return _buildDrunkPage();
    if (label == 'Accords mets-vins') return const PairingScreen();
    if (label == 'Wine CellR') return const WineCellarScreen();
    if (label == 'Capteurs Govee') return const GoveeSensorsScreen();
    if (label == 'Statistiques') return const StatsScreen();
    if (label == 'Carte des domaines') return const CarteScreen();
    if (label == 'Liste de souhaits') return const _WishlistPage();
    if (label == 'Paramètres') return SettingsScreen(section: _settingsSub);
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

  Widget _buildDrunkPage() => const _DrunkPage();

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

            final grouped = <String, WineRow>{};
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
                grouped[key] = WineRow(wine: wine, bottles: entry.value);
              }
            }

            var rows = grouped.values.toList();

            final allFilterData = rows.map((r) => CascadeFilterData(
              country: r.wine.country,
              region: r.wine.region,
              appellation: r.wine.appellation,
              climat: r.wine.climat,
            )).toList();

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

            if (!_cascadeFilter.isEmpty) {
              rows = rows.where((r) => _cascadeFilter.matchesWine(
                country: r.wine.country,
                region: r.wine.region,
                appellation: r.wine.appellation,
                climat: r.wine.climat,
              )).toList();
            }

            final isMobile = MediaQuery.of(context).size.width < 600;
            final hasFilterData = allFilterData.any((e) => e.country.isNotEmpty);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasFilterData)
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.bg2,
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: CascadeFilterBar(
                      filter: _cascadeFilter,
                      allItems: allFilterData,
                      onChanged: (f) => setState(() => _cascadeFilter = f),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 0 : 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isMobile ? Colors.transparent : AppColors.bg2,
                        borderRadius: BorderRadius.circular(isMobile ? 0 : 14),
                        border: isMobile ? null : Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          if (!isMobile)
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
                                  const Icon(Icons.wine_bar, size: 48, color: AppColors.text3),
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
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth < 600) {
                                    return CaveCardList(
                                      rows: rows,
                                      onTap: _openWineDetail,
                                      gardeFor: _gardeLabel,
                                      onDrink: (bottle) => showDrinkBottleDialog(context, bottle),
                                      onSommelier: (wine) => showSommelierDialog(context, wine),
                                    );
                                  }
                                  return _buildCaveTable(rows);
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCaveTable(List<WineRow> rows) {
    return ValueListenableBuilder<Set<CaveColumn>>(
      valueListenable: CavePreferencesService.visible,
      builder: (context, visibleSet, _) {
        final cols = CaveColumn.values
            .where((c) => visibleSet.contains(c))
            .toList();

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.bg3,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: LayoutBuilder(
                builder: (context, c) => CaveRowLayout(
                  width: c.maxWidth,
                  child: _buildHeaderCells(cols),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final row = rows[i];
                  return CaveDataRow(
                    row: row,
                    columns: cols,
                    onTap: () => _openWineDetail(row),
                    gardeFor: _gardeLabel,
                    onDrink: (bottle) => showDrinkBottleDialog(context, bottle),
                    onSommelier: (wine) => showSommelierDialog(context, wine),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openWineDetail(WineRow row) {
    showWineDetail(context, wine: row.wine, bottles: row.bottles);
  }

  List<Widget> _buildHeaderCells(List<CaveColumn> cols) {
    final headerStyle = AppText.sans(
      color: AppColors.text3,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    );
    final cells = cols.map((c) {
      final text = Text(c.label, style: headerStyle);
      if (c.width != null) return SizedBox(width: c.width, child: text);
      return Expanded(flex: c.flex ?? 1, child: text);
    }).toList();
    cells.add(const SizedBox(width: 30));
    cells.add(const SizedBox(width: 30));
    return cells;
  }

  GardeInfo? _gardeLabel(Wine w) => GardeInfo.fromWine(w);
}

class _NavEntry {
  final IconData? icon;
  final String? label;
  final bool isSeparator;

  const _NavEntry.item({required IconData this.icon, required String this.label})
      : isSeparator = false;

  const _NavEntry.sep()
      : icon = null,
        label = null,
        isSeparator = true;
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
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
                child: Icon(widget.icon, size: 18, color: color),
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
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _NavSubItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavSubItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavSubItem> createState() => _NavSubItemState();
}

class _NavSubItemState extends State<_NavSubItem> {
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
          padding: const EdgeInsets.fromLTRB(15, 10, 14, 10),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: Icon(widget.icon, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppText.sans(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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

class _DrunkPage extends StatefulWidget {
  const _DrunkPage();

  @override
  State<_DrunkPage> createState() => _DrunkPageState();
}

class _DrunkPageState extends State<_DrunkPage> {
  late final Stream<List<Wine>> _wineStream;
  late final Stream<List<Bottle>> _bottleStream;
  CascadeFilterState _cascadeFilter = const CascadeFilterState();

  @override
  void initState() {
    super.initState();
    _wineStream = CaveService.wines();
    _bottleStream = CaveService.bottlesDrunk();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Wine>>(
      stream: _wineStream,
      builder: (context, wineSnap) {
        final wines = wineSnap.data ?? [];
        final winesById = {for (final w in wines) w.id: w};

        return StreamBuilder<List<Bottle>>(
          stream: _bottleStream,
          builder: (context, bottleSnap) {
            if (bottleSnap.connectionState == ConnectionState.waiting &&
                bottleSnap.data == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }
            var bottles = bottleSnap.data ?? [];

            final allFilterData = bottles
                .map((b) => winesById[b.wineId])
                .whereType<Wine>()
                .map((w) => CascadeFilterData(
                      country: w.country,
                      region: w.region,
                      appellation: w.appellation,
                      climat: w.climat,
                    ))
                .toList();

            if (!_cascadeFilter.isEmpty) {
              bottles = bottles.where((b) {
                final w = winesById[b.wineId];
                if (w == null) return false;
                return _cascadeFilter.matchesWine(
                  country: w.country,
                  region: w.region,
                  appellation: w.appellation,
                  climat: w.climat,
                );
              }).toList();
            }

            if (bottles.isEmpty && (bottleSnap.data ?? []).isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.local_bar_outlined, size: 48, color: AppColors.text3),
                      const SizedBox(height: 14),
                      Text(
                        'Aucune bouteille bue',
                        style: AppText.serif(
                            color: AppColors.text2, fontSize: 22),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ValueListenableBuilder<Set<DrunkColumn>>(
              valueListenable: CavePreferencesService.drunkVisible,
              builder: (context, visibleCols, _) {
                final isMobile = MediaQuery.of(context).size.width < 600;
                final cols = isMobile
                    ? [DrunkColumn.photo, DrunkColumn.name, DrunkColumn.drunkRating, DrunkColumn.drunkDate]
                    : DrunkColumn.values.where((c) => visibleCols.contains(c)).toList();
                final hasFilterData = allFilterData.any((e) => e.country.isNotEmpty);
                return Column(
                  children: [
                    if (hasFilterData)
                      Container(
                        decoration: const BoxDecoration(
                          color: AppColors.bg2,
                          border: Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: CascadeFilterBar(
                          filter: _cascadeFilter,
                          allItems: allFilterData,
                          onChanged: (f) => setState(() => _cascadeFilter = f),
                        ),
                      ),
                    if (!isMobile) ...[
                      Container(
                        color: AppColors.bg2,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: _DrunkHeader(columns: cols),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                    ],
                    Expanded(
                      child: ListView.builder(
                        itemCount: bottles.length,
                        itemBuilder: (context, i) {
                          final b = bottles[i];
                          final w = winesById[b.wineId];
                          return _DrunkRow(
                            bottle: b,
                            wine: w,
                            columns: cols,
                            onTap: w != null
                                ? () => showWineDetail(context,
                                    wine: w,
                                    bottles: bottles
                                        .where((x) => x.wineId == w.id && x.format == b.format)
                                        .toList(),
                                    format: b.format)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _WishlistPage extends StatefulWidget {
  const _WishlistPage();

  @override
  State<_WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<_WishlistPage> {
  late final Stream<List<WishWine>> _stream;
  CascadeFilterState _cascadeFilter = const CascadeFilterState();

  @override
  void initState() {
    super.initState();
    _stream = WishlistService.wishes();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WishWine>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            snap.data == null) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }
        final allWishes = snap.data ?? [];

        final allFilterData = allWishes.map((w) => CascadeFilterData(
          country: w.country,
          region: w.region,
          appellation: w.appellation,
          climat: w.climat,
        )).toList();

        var wishes = allWishes;
        if (!_cascadeFilter.isEmpty) {
          wishes = wishes.where((w) => _cascadeFilter.matchesWine(
            country: w.country,
            region: w.region,
            appellation: w.appellation,
            climat: w.climat,
          )).toList();
        }

        return ValueListenableBuilder<Set<WishColumn>>(
          valueListenable: CavePreferencesService.wishVisible,
          builder: (context, visibleCols, _) {
            final cols = WishColumn.values
                .where((c) => visibleCols.contains(c))
                .toList();
            final hasFilterData = allFilterData.any((e) => e.country.isNotEmpty);
            return Column(
              children: [
                if (hasFilterData)
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.bg2,
                      border: Border(bottom: BorderSide(color: AppColors.border)),
                    ),
                    child: CascadeFilterBar(
                      filter: _cascadeFilter,
                      allItems: allFilterData,
                      onChanged: (f) => setState(() => _cascadeFilter = f),
                    ),
                  ),
                Container(
                  color: AppColors.bg2,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: _WishHeader(columns: cols)),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                Container(
                  color: AppColors.bg2,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => showAddWishDialog(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: Text('Ajouter un souhait',
                            style: AppText.sans(
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: const Color(0xFF1A1408),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${wishes.length} vin${wishes.length > 1 ? 's' : ''}',
                        style: AppText.sans(
                            color: AppColors.text3, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (wishes.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_border, size: 48, color: AppColors.text3),
                          const SizedBox(height: 14),
                          Text(
                            'Aucun vin dans la liste',
                            style: AppText.serif(
                                color: AppColors.text2, fontSize: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ajoute des vins que tu aimerais avoir',
                            style: AppText.sans(
                                color: AppColors.text3, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: wishes.length,
                      itemBuilder: (context, i) {
                        return _WishRow(
                          wish: wishes[i],
                          columns: cols,
                          onTap: () =>
                              showEditWishDialog(context, wishes[i]),
                          onDelete: () =>
                              WishlistService.deleteWish(wishes[i].id),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _WishHeader extends StatelessWidget {
  final List<WishColumn> columns;
  const _WishHeader({required this.columns});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final col in columns)
          if (col == WishColumn.photo)
            const SizedBox(width: 62)
          else if (col.flex != null)
            Expanded(
              flex: col.flex!,
              child: Text(
                col.label.toUpperCase(),
                style: AppText.sans(
                  color: AppColors.text3,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            )
          else
            SizedBox(
              width: col.width!,
              child: Text(
                col.label.toUpperCase(),
                style: AppText.sans(
                  color: AppColors.text3,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ),
      ],
    );
  }
}

class _WishRow extends StatefulWidget {
  final WishWine wish;
  final List<WishColumn> columns;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _WishRow({
    required this.wish,
    required this.columns,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_WishRow> createState() => _WishRowState();
}

class _WishRowState extends State<_WishRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _hover ? const Color(0x0FC9A84C) : Colors.transparent,
            border: const Border(
                bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              for (final col in widget.columns)
                _buildCell(col),
              Tooltip(
                message: 'Supprimer',
                child: GestureDetector(
                  onTap: widget.onDelete,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border2),
                    ),
                    child: const Icon(Icons.delete_outline,
                        size: 13, color: AppColors.text3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(WishColumn col) {
    final w = widget.wish;
    if (col == WishColumn.photo) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 50,
          height: 50,
          child: w.photoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(w.photoUrl!, fit: BoxFit.cover),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Icon(Icons.wine_bar,
                        color: AppColors.text3, size: 16),
                  ),
                ),
        ),
      );
    }
    final child = _cellContent(col);
    if (col.flex != null) {
      return Expanded(flex: col.flex!, child: child);
    }
    return SizedBox(width: col.width!, child: child);
  }

  Widget _cellContent(WishColumn col) {
    final w = widget.wish;
    switch (col) {
      case WishColumn.photo:
        return const SizedBox.shrink();
      case WishColumn.name:
        return Text(
          w.name,
          style: AppText.serif(
            color: AppColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        );
      case WishColumn.producer:
        return Text(w.producer.isEmpty ? '—' : w.producer,
            style: AppText.sans(color: AppColors.text2, fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case WishColumn.vintage:
        return Text(w.vintage != null ? '${w.vintage}' : '—',
            style: AppText.sans(color: AppColors.text2, fontSize: 12));
      case WishColumn.type:
        final tc = wineTypeColor(w.type);
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: tc.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tc.withValues(alpha: 0.35)),
            ),
            child: Text(wineTypeLabel(w.type),
                style: AppText.sans(
                    color: tc,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ),
        );
      case WishColumn.appellation:
        return Text(w.appellation.isEmpty ? '—' : w.appellation,
            style: AppText.sans(color: AppColors.text2, fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case WishColumn.region:
        return Text(w.region.isEmpty ? '—' : w.region,
            style: AppText.sans(color: AppColors.text2, fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case WishColumn.country:
        return Text(w.country.isEmpty ? '—' : w.country,
            style: AppText.sans(color: AppColors.text2, fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case WishColumn.village:
        return Text(w.village.isEmpty ? '—' : w.village,
            style: AppText.sans(color: AppColors.text2, fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case WishColumn.climat:
        return Text(w.climat.isEmpty ? '—' : w.climat,
            style: AppText.sans(color: AppColors.text2, fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case WishColumn.domaine:
        return Text(w.domaine.isEmpty ? '—' : w.domaine,
            style: AppText.sans(color: AppColors.text2, fontSize: 12),
            overflow: TextOverflow.ellipsis);
      case WishColumn.domainAddress:
        return Text(w.domainAddress.isEmpty ? '—' : w.domainAddress,
            style: AppText.sans(color: AppColors.text2, fontSize: 11),
            overflow: TextOverflow.ellipsis);
      case WishColumn.grapes:
        return Text(w.grapes.isEmpty ? '—' : w.grapes,
            style: AppText.sans(color: AppColors.text3, fontSize: 11),
            overflow: TextOverflow.ellipsis);
      case WishColumn.alcohol:
        return Text(
            w.alcohol != null ? '${w.alcohol!.toStringAsFixed(1)}%' : '—',
            style: AppText.sans(color: AppColors.text2, fontSize: 12));
      case WishColumn.rating:
        return Text(w.rating != null ? '${w.rating}/100' : '—',
            style: AppText.sans(color: AppColors.text2, fontSize: 12));
      case WishColumn.garde:
        final g = GardeInfo.fromWish(w);
        if (g == null) {
          return Text('—',
              style: AppText.sans(color: AppColors.text3, fontSize: 11));
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: g.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: g.color.withValues(alpha: 0.35)),
            ),
            child: Text(g.label,
                style: AppText.sans(
                    color: g.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        );
      case WishColumn.drinkFrom:
        return Text(w.drinkFrom != null ? '${w.drinkFrom}' : '—',
            style: AppText.sans(color: AppColors.text2, fontSize: 12));
      case WishColumn.apogee:
        return Text(w.drinkPeak != null ? '${w.drinkPeak}' : '—',
            style: AppText.sans(color: AppColors.text2, fontSize: 12));
      case WishColumn.drinkTo:
        return Text(w.drinkTo != null ? '${w.drinkTo}' : '—',
            style: AppText.sans(color: AppColors.text2, fontSize: 12));
      case WishColumn.marketValue:
        return Text(
            w.marketValue != null
                ? '${w.marketValue!.toStringAsFixed(0)} \$'
                : '—',
            style: AppText.sans(color: AppColors.text2, fontSize: 12));
      case WishColumn.personalNote:
        return Text(w.personalNote.isEmpty ? '—' : w.personalNote,
            style: AppText.sans(color: AppColors.text2, fontSize: 11),
            overflow: TextOverflow.ellipsis);
      case WishColumn.createdAt:
        return Text(fmtDate(w.createdAt),
            style: AppText.sans(color: AppColors.text3, fontSize: 11));
    }
  }
}

class _DrunkHeader extends StatelessWidget {
  final List<DrunkColumn> columns;
  const _DrunkHeader({required this.columns});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final col in columns) ...[
          if (col == DrunkColumn.photo)
            const SizedBox(width: 54)
          else if (col.flex != null)
            Expanded(
              flex: col.flex!,
              child: _hdr(col.label.toUpperCase()),
            )
          else
            SizedBox(
              width: col.width!,
              child: _hdr(col.label.toUpperCase()),
            ),
        ],
        const SizedBox(width: 32),
      ],
    );
  }

  Widget _hdr(String label) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppText.sans(
        color: AppColors.text3,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _DrunkRow extends StatefulWidget {
  final Bottle bottle;
  final Wine? wine;
  final List<DrunkColumn> columns;
  final VoidCallback? onTap;
  const _DrunkRow({
    required this.bottle,
    this.wine,
    required this.columns,
    this.onTap,
  });

  @override
  State<_DrunkRow> createState() => _DrunkRowState();
}

class _DrunkRowState extends State<_DrunkRow> {
  bool _hover = false;

  Widget _photo(Wine? w) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 42,
        height: 42,
        child: w?.photoUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(w!.photoUrl!, fit: BoxFit.cover),
              )
            : Container(
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Icon(Icons.wine_bar, color: AppColors.text3, size: 16),
                ),
              ),
      ),
    );
  }

  Widget _editButton(Bottle b) => Tooltip(
        message: 'Modifier',
        child: GestureDetector(
          onTap: () => showDrinkBottleDialog(context, b),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.bg3,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border2),
            ),
            child: const Icon(Icons.edit_outlined, size: 13, color: AppColors.text3),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = widget.bottle;
    final w = widget.wine;
    final isMobile = MediaQuery.of(context).size.width < 600;

    final decoration = BoxDecoration(
      color: _hover ? const Color(0x0FC9A84C) : Colors.transparent,
      border: const Border(bottom: BorderSide(color: AppColors.border)),
    );

    if (isMobile) {
      final meta = <String>[
        if (w?.producer != null && w!.producer.isNotEmpty) w.producer,
        if (w?.vintage != null) '${w!.vintage}',
        if (b.drunkAt != null) fmtDate(b.drunkAt!),
      ].join(' · ');

      return MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: InkWell(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: decoration,
            child: Row(
              children: [
                _photo(w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              w?.name ?? '—',
                              style: AppText.serif(
                                color: AppColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (b.drunkRating != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              '${b.drunkRating}/100',
                              style: AppText.sans(
                                color: AppColors.gold2,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          meta,
                          style: AppText.sans(color: AppColors.text3, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _editButton(b),
              ],
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: decoration,
          child: Row(
            children: [
              for (final col in widget.columns)
                _buildCell(col, b, w),
              _editButton(b),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(DrunkColumn col, Bottle b, Wine? w) {
    if (col == DrunkColumn.photo) return _photo(w);
    final child = _cellContent(col, b, w);
    if (col.flex != null) return Expanded(flex: col.flex!, child: child);
    return SizedBox(width: col.width!, child: child);
  }

  Widget _cellContent(DrunkColumn col, Bottle b, Wine? w) {
    switch (col) {
      case DrunkColumn.photo:
        return const SizedBox.shrink();
      case DrunkColumn.name:
        return Text(
          w?.name ?? '—',
          style: AppText.serif(
            color: AppColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.producer:
        return Text(
          w?.producer ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.vintage:
        return Text(
          w?.vintage != null ? '${w!.vintage}' : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        );
      case DrunkColumn.type:
        if (w == null) return const SizedBox.shrink();
        final tc = wineTypeColor(w.type);
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: tc.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: tc.withValues(alpha: 0.35)),
            ),
            child: Text(
              wineTypeLabel(w.type),
              style: AppText.sans(
                color: tc,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        );
      case DrunkColumn.appellation:
        return Text(
          w?.appellation ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.region:
        return Text(
          w?.region ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.country:
        return Text(
          w?.country ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.village:
        return Text(
          w?.village ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.climat:
        return Text(
          w?.climat ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.domaine:
        return Text(
          w?.domaine ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.domainAddress:
        return Text(
          w?.domainAddress ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.grapes:
        return Text(
          w?.grapes ?? '—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.alcohol:
        return Text(
          w?.alcohol != null ? '${w!.alcohol!.toStringAsFixed(1)}%' : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        );
      case DrunkColumn.rating:
        return Text(
          w?.rating != null ? '${w!.rating}/100' : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        );
      case DrunkColumn.gardeStatus:
        if (w == null) return const SizedBox.shrink();
        final g = GardeInfo.fromWine(w);
        if (g == null) return Text('—', style: AppText.sans(color: AppColors.text3, fontSize: 11));
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: g.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: g.color.withValues(alpha: 0.35)),
            ),
            child: Text(
              g.label,
              style: AppText.sans(
                color: g.color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      case DrunkColumn.drinkFrom:
        return Text(
          w?.drinkFrom != null ? '${w!.drinkFrom}' : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        );
      case DrunkColumn.apogee:
        return Text(
          w?.drinkPeak != null ? '${w!.drinkPeak}' : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        );
      case DrunkColumn.drinkTo:
        return Text(
          w?.drinkTo != null ? '${w!.drinkTo}' : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        );
      case DrunkColumn.format:
        return Text(
          b.format.label,
          style: AppText.sans(color: AppColors.text3, fontSize: 11),
        );
      case DrunkColumn.price:
        return Text(
          b.purchasePrice != null
              ? '${b.purchasePrice!.toStringAsFixed(0)} \$'
              : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        );
      case DrunkColumn.source:
        return Text(
          b.source?.label ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.purchaseYear:
        return Text(
          b.purchaseYear != null ? '${b.purchaseYear}' : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        );
      case DrunkColumn.marketValue:
        return Text(
          b.marketValue != null
              ? '${b.marketValue!.toStringAsFixed(0)} \$'
              : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        );
      case DrunkColumn.drunkRating:
        if (b.drunkRating == null) {
          return Text('—',
              style: AppText.sans(color: AppColors.text3, fontSize: 12));
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${b.drunkRating}/100',
              style: AppText.sans(
                color: AppColors.gold2,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      case DrunkColumn.drunkDate:
        return Text(
          b.drunkAt != null ? fmtDate(b.drunkAt!) : '—',
          style: AppText.sans(color: AppColors.text3, fontSize: 11),
        );
      case DrunkColumn.drunkLocation:
        return Text(
          b.drunkLocation ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        );
      case DrunkColumn.drunkNote:
        return Text(
          b.drunkNote ?? '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        );
    }
  }
}

class _AppBranding extends StatelessWidget {
  final bool compact;
  const _AppBranding({required this.compact});

  @override
  Widget build(BuildContext context) {
    final logoH = compact ? 32.0 : 48.0;
    final fontSize = compact ? 16.0 : 20.0;

    return Row(
      children: [
        Image.asset(
          'assets/images/logo_small.png',
          height: logoH,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
        ),
        SizedBox(width: compact ? 10 : 12),
        Expanded(
          child: Text(
            'Cave de\nJonathan Laberge',
            style: AppText.serif(
              color: AppColors.gold2,
              fontSize: fontSize,
              height: 1.15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
