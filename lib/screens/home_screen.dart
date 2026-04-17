import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import 'add_wine_dialog.dart';

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
        _buildFilterBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildContent(),
          ),
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

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _filterTag('Rouge', active: true),
            _filterTag('Blanc'),
            _filterTag('Rosé'),
            _filterTag('À boire'),
            _filterTag('Apogée'),
            _filterTag('Garde'),
          ],
        ),
      ),
    );
  }

  Widget _filterTag(String label, {bool active = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.gold : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppColors.gold : AppColors.border2,
        ),
      ),
      child: Text(
        label,
        style: AppText.sans(
          color: active ? const Color(0xFF1A1408) : AppColors.text2,
          fontSize: 12,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedIndex == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsGrid(),
          const SizedBox(height: 14),
          _tableCard(),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Text(
          _items[_selectedIndex].label!,
          style: AppText.serif(
            color: AppColors.text2,
            fontSize: 28,
          ),
        ),
      ),
    );
  }

  Widget _statsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: [
            _statCard('BOUTEILLES', '39', 'en cave'),
            _statCard('VALEUR STOCK', '3 800 \$', 'au total'),
            _statCard('VALEUR RÉELLE', '39 648 \$', 'à 139 bouteilles'),
            _statCard('PRÊTES À BOIRE', '20', 'en primeur'),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, String sub) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 11,
              letterSpacing: 0.66,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppText.serif(
              color: AppColors.gold2,
              fontSize: 26,
              height: 1.1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Text(
                  'Cave — 0 résultats',
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
          ),
        ],
      ),
    );
  }
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
