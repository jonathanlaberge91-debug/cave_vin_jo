import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../services/cave_service.dart';
import 'add_wine_dialog.dart';
import 'settings_screen.dart';

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
              grouped[wine.id] = _WineRow(wine: wine, bottles: wineBottles);
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

            return SingleChildScrollView(
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
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Cave — ${rows.length} vin${rows.length > 1 ? 's' : ''}',
                            style: AppText.serif(
                              color: AppColors.gold2,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
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
                      _buildTable(rows),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTable(List<_WineRow> rows) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.bg3),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        border: const TableBorder(
          horizontalInside: BorderSide(color: AppColors.border),
        ),
        columnSpacing: 20,
        headingTextStyle: AppText.sans(
          color: AppColors.text3,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
        ),
        columns: const [
          DataColumn(label: Text('PHOTO')),
          DataColumn(label: Text('VIN')),
          DataColumn(label: Text('MILL.')),
          DataColumn(label: Text('PAYS')),
          DataColumn(label: Text('RÉGION')),
          DataColumn(label: Text('GARDE')),
          DataColumn(label: Text('CÉPAGES')),
          DataColumn(label: Text('FORMAT')),
          DataColumn(label: Text('PRIX')),
          DataColumn(label: Text('QTÉ')),
        ],
        rows: rows.map((r) => _buildDataRow(r)).toList(),
      ),
    );
  }

  DataRow _buildDataRow(_WineRow row) {
    final w = row.wine;
    final qty = row.bottles.length;
    final format = row.bottles.first.format.label;
    final price = row.bottles.first.purchasePrice;
    final garde = _gardeLabel(w);

    return DataRow(
      cells: [
        DataCell(
          w.photoUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    w.photoUrl!,
                    width: 36,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoPlaceholder(),
                  ),
                )
              : _photoPlaceholder(),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                w.name,
                style: AppText.serif(
                  color: AppColors.text,
                  fontSize: 14,
                ),
              ),
              if (w.producer.isNotEmpty)
                Text(
                  w.producer,
                  style: AppText.sans(
                    color: AppColors.text3,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        DataCell(
          w.vintage != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  ),
                )
              : Text('—', style: AppText.sans(color: AppColors.text3)),
        ),
        DataCell(Text(
          w.country,
          style: AppText.sans(color: AppColors.text2, fontSize: 13),
        )),
        DataCell(Text(
          w.region,
          style: AppText.sans(color: AppColors.text2, fontSize: 13),
        )),
        DataCell(
          garde != null
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: garde.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    garde.label,
                    style: AppText.sans(
                      color: garde.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : Text('—', style: AppText.sans(color: AppColors.text3)),
        ),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              w.grapes,
              style: AppText.sans(color: AppColors.text2, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(
          format,
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        )),
        DataCell(Text(
          price != null ? '${price.toStringAsFixed(0)} \$' : '—',
          style: AppText.sans(color: AppColors.text2, fontSize: 12),
        )),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border2),
            ),
            child: Text(
              '$qty',
              style: AppText.sans(
                color: AppColors.text2,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 36,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(Icons.wine_bar, color: AppColors.text3, size: 18),
    );
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
