import 'package:flutter/material.dart';
import '../models/cave_column.dart';
import '../models/cellar.dart';
import '../models/drunk_column.dart';
import '../models/market_history.dart';
import '../models/garde_history.dart';
import '../models/stat_item.dart';
import '../models/wine.dart';
import '../models/wish_column.dart';
import '../services/actualisation_service.dart';
import '../services/cave_preferences_service.dart';
import '../services/cave_service.dart';
import '../services/cellar_service.dart';
import '../services/gemini_service.dart';
import '../services/govee_service.dart';
import '../services/maps_service.dart';
import '../dialogs/cellar_form_dialog.dart';
import '../theme/app_text.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatelessWidget {
  final int section;
  const SettingsScreen({super.key, this.section = 0});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: switch (section) {
        0 => const _SettingsSection(
            title: 'Cave',
            description:
                'Personnalise les colonnes affichées dans le tableau « Ma Cave ».',
            child: _CaveContent(),
          ),
        1 => const _SettingsSection(
            title: 'Celliers',
            description:
                'Gère tes celliers : renomme, modifie ou supprime.',
            child: _CellarSettingsContent(),
          ),
        2 => _SettingsSection(
            title: 'Bouteilles bues',
            description:
                'Personnalise les colonnes affichées dans le tableau des bouteilles bues.',
            child: _DrunkColumnsContent(),
          ),
        3 => const _SettingsSection(
            title: 'Liste de souhaits',
            description:
                'Personnalise les colonnes affichées dans la liste de souhaits.',
            child: _WishColumnsContent(),
          ),
        4 => const _SettingsSection(
            title: 'Statistiques',
            description:
                'Personnalise l\'ordre des statistiques et masque les informations financières.',
            child: _StatsSettingsContent(),
          ),
        5 => const _SettingsSection(
            title: 'Clés API',
            description:
                'Services tiers utilisés par l\'application (analyse de photos, recherche, etc.).',
            child: _ApiKeysContent(),
          ),
        _ => const _SettingsSection(
            title: 'Actualisation',
            icon: Icons.refresh_outlined,
            description:
                'Relance des estimations Gemini pour la valeur marché et la période de garde de tes vins.',
            child: _ActualisationContent(),
          ),
      },
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final IconData? icon;

  const _SettingsSection({
    required this.title,
    this.description,
    required this.child,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: AppColors.gold),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      title.toUpperCase(),
                      style: AppText.sans(
                        color: AppColors.text3,
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: AppText.sans(
                      color: AppColors.text3,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SettingsSubsection extends StatelessWidget {
  final String title;
  final String? description;
  final Widget child;
  final List<Widget> trailing;

  const _SettingsSubsection({
    required this.title,
    this.description,
    required this.child,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppText.serif(
                  color: AppColors.gold2,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...trailing,
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: AppText.sans(color: AppColors.text3, fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ApiKeysContent extends StatefulWidget {
  const _ApiKeysContent();

  @override
  State<_ApiKeysContent> createState() => _ApiKeysContentState();
}

class _ApiKeysContentState extends State<_ApiKeysContent> {
  final _geminiKey = TextEditingController(text: GeminiService.apiKey ?? '');
  final _mapsKey = TextEditingController(text: MapsService.apiKey ?? '');
  final _goveeKey = TextEditingController(text: GoveeService.apiKey ?? '');
  bool _obscureGemini = true;
  bool _obscureMaps = true;
  bool _obscureGovee = true;
  bool _savedGemini = false;
  bool _savedMaps = false;
  bool _savedGovee = false;

  @override
  void dispose() {
    _geminiKey.dispose();
    _mapsKey.dispose();
    _goveeKey.dispose();
    super.dispose();
  }

  void _saveGemini() {
    final key = _geminiKey.text.trim();
    GeminiService.apiKey = key.isEmpty ? null : key;
    setState(() => _savedGemini = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedGemini = false);
    });
  }

  void _saveMaps() {
    final key = _mapsKey.text.trim();
    MapsService.apiKey = key.isEmpty ? null : key;
    setState(() => _savedMaps = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedMaps = false);
    });
  }

  void _saveGovee() {
    final key = _goveeKey.text.trim();
    GoveeService.apiKey = key.isEmpty ? null : key;
    setState(() => _savedGovee = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedGovee = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsSubsection(
          title: 'Google Gemini',
          description:
              'Utilisé pour remplir automatiquement les fiches de vin (identification, fenêtre de dégustation, descriptions).',
          child: _buildKeyField(
            controller: _geminiKey,
            hint: 'Coller votre clé API Gemini ici…',
            obscure: _obscureGemini,
            onToggle: () => setState(() => _obscureGemini = !_obscureGemini),
            onSave: _saveGemini,
            saved: _savedGemini,
            configured: GeminiService.isConfigured,
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSubsection(
          title: 'Google Maps',
          description:
              'Utilisé pour la carte des domaines. Nécessite les APIs « Maps JavaScript API » et « Geocoding API » activées dans Google Cloud Console.',
          child: _buildKeyField(
            controller: _mapsKey,
            hint: 'Coller votre clé API Google Maps ici…',
            obscure: _obscureMaps,
            onToggle: () => setState(() => _obscureMaps = !_obscureMaps),
            onSave: _saveMaps,
            saved: _savedMaps,
            configured: MapsService.isConfigured,
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSubsection(
          title: 'Govee',
          description:
              'Capteurs de température et humidité Govee. Clé disponible sur developer.govee.com.',
          child: _buildKeyField(
            controller: _goveeKey,
            hint: 'Coller votre clé API Govee ici…',
            obscure: _obscureGovee,
            onToggle: () => setState(() => _obscureGovee = !_obscureGovee),
            onSave: _saveGovee,
            saved: _savedGovee,
            configured: GoveeService.isConfigured,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required VoidCallback onSave,
    required bool saved,
    required bool configured,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                style: AppText.sans(color: AppColors.text, fontSize: 13),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bg3,
                  hintText: hint,
                  hintStyle:
                      AppText.sans(color: AppColors.text3, fontSize: 12),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.gold),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.text3,
                      size: 18,
                    ),
                    onPressed: onToggle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF1A1408),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                saved ? 'Sauvegardé' : 'Sauvegarder',
                style: AppText.sans(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              configured
                  ? Icons.check_circle
                  : Icons.warning_amber_rounded,
              size: 14,
              color: configured
                  ? const Color(0xFF4A7C59)
                  : const Color(0xFFE07060),
            ),
            const SizedBox(width: 6),
            Text(
              configured ? 'Clé configurée' : 'Aucune clé configurée',
              style: AppText.sans(
                color: configured
                    ? const Color(0xFF6AAA7A)
                    : const Color(0xFFE07060),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CaveContent extends StatelessWidget {
  const _CaveContent();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<CaveColumn>>(
      valueListenable: CavePreferencesService.visible,
      builder: (context, visible, _) {
        return _SettingsSubsection(
          title: 'Colonnes du tableau',
          description:
              'Active les colonnes que tu veux voir. Photo, Vin et Qté sont toujours affichées.',
          trailing: [
            TextButton(
              onPressed: () => CavePreferencesService.resetToDefaults(),
              child: Text(
                'Réinitialiser',
                style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < ColumnGroup.values.length; i++) ...[
                _ColumnGroupBlock(
                  group: ColumnGroup.values[i],
                  visible: visible,
                ),
                if (i < ColumnGroup.values.length - 1)
                  const SizedBox(height: 14),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ColumnGroupBlock extends StatelessWidget {
  final ColumnGroup group;
  final Set<CaveColumn> visible;

  const _ColumnGroupBlock({required this.group, required this.visible});

  @override
  Widget build(BuildContext context) {
    final cols =
        CaveColumn.values.where((c) => c.group == group).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.label.toUpperCase(),
          style: AppText.sans(
            color: AppColors.text3,
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: cols.map((c) {
            return _ColumnChip(
              column: c,
              active: visible.contains(c),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ColumnChip extends StatelessWidget {
  final CaveColumn column;
  final bool active;

  const _ColumnChip({required this.column, required this.active});

  @override
  Widget build(BuildContext context) {
    final disabled = column.essential;
    final label = column.label.isEmpty ? 'Photo' : column.label;
    final bg = active
        ? (disabled
            ? AppColors.bg3
            : const Color(0x29C9A84C))
        : AppColors.bg3;
    final border = active && !disabled
        ? const Color(0x66C9A84C)
        : AppColors.border;
    final fg = active
        ? (disabled ? AppColors.text2 : AppColors.gold2)
        : AppColors.text3;

    return InkWell(
      onTap: disabled
          ? null
          : () {
              final next = {...CavePreferencesService.visible.value};
              if (active) {
                next.remove(column);
              } else {
                next.add(column);
              }
              CavePreferencesService.setVisible(next);
            },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? (disabled ? Icons.lock : Icons.check)
                  : Icons.add,
              size: 12,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.sans(
                color: fg,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrunkColumnsContent extends StatelessWidget {
  const _DrunkColumnsContent();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<DrunkColumn>>(
      valueListenable: CavePreferencesService.drunkVisible,
      builder: (context, visible, _) {
        return _SettingsSubsection(
          title: 'Colonnes du tableau',
          description:
              'Active les colonnes que tu veux voir. Photo et Vin sont toujours affichées.',
          trailing: [
            TextButton(
              onPressed: () => CavePreferencesService.resetDrunkToDefaults(),
              child: Text(
                'Réinitialiser',
                style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < DrunkColumnGroup.values.length; i++) ...[
                _DrunkColumnGroupBlock(
                  group: DrunkColumnGroup.values[i],
                  visible: visible,
                ),
                if (i < DrunkColumnGroup.values.length - 1)
                  const SizedBox(height: 14),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DrunkColumnGroupBlock extends StatelessWidget {
  final DrunkColumnGroup group;
  final Set<DrunkColumn> visible;

  const _DrunkColumnGroupBlock({required this.group, required this.visible});

  @override
  Widget build(BuildContext context) {
    final cols = DrunkColumn.values.where((c) => c.group == group).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.label.toUpperCase(),
          style: AppText.sans(
            color: AppColors.text3,
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: cols.map((c) {
            return _DrunkColumnChip(
              column: c,
              active: visible.contains(c),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _DrunkColumnChip extends StatelessWidget {
  final DrunkColumn column;
  final bool active;

  const _DrunkColumnChip({required this.column, required this.active});

  @override
  Widget build(BuildContext context) {
    final disabled = column.essential;
    final label = column.label.isEmpty ? 'Photo' : column.label;
    final bg = active
        ? (disabled ? AppColors.bg3 : const Color(0x29C9A84C))
        : AppColors.bg3;
    final border =
        active && !disabled ? const Color(0x66C9A84C) : AppColors.border;
    final fg = active
        ? (disabled ? AppColors.text2 : AppColors.gold2)
        : AppColors.text3;

    return InkWell(
      onTap: disabled
          ? null
          : () {
              final next = {...CavePreferencesService.drunkVisible.value};
              if (active) {
                next.remove(column);
              } else {
                next.add(column);
              }
              CavePreferencesService.setDrunkVisible(next);
            },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? (disabled ? Icons.lock : Icons.check) : Icons.add,
              size: 12,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.sans(
                color: fg,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishColumnsContent extends StatelessWidget {
  const _WishColumnsContent();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<WishColumn>>(
      valueListenable: CavePreferencesService.wishVisible,
      builder: (context, visible, _) {
        return _SettingsSubsection(
          title: 'Colonnes du tableau',
          description:
              'Active les colonnes que tu veux voir. Photo et Vin sont toujours affichées.',
          trailing: [
            TextButton(
              onPressed: () => CavePreferencesService.resetWishToDefaults(),
              child: Text(
                'Réinitialiser',
                style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < WishColumnGroup.values.length; i++) ...[
                _WishColumnGroupBlock(
                  group: WishColumnGroup.values[i],
                  visible: visible,
                ),
                if (i < WishColumnGroup.values.length - 1)
                  const SizedBox(height: 14),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _WishColumnGroupBlock extends StatelessWidget {
  final WishColumnGroup group;
  final Set<WishColumn> visible;

  const _WishColumnGroupBlock({required this.group, required this.visible});

  @override
  Widget build(BuildContext context) {
    final cols = WishColumn.values.where((c) => c.group == group).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.label.toUpperCase(),
          style: AppText.sans(
            color: AppColors.text3,
            fontSize: 9,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: cols.map((c) {
            return _WishColumnChip(
              column: c,
              active: visible.contains(c),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _WishColumnChip extends StatelessWidget {
  final WishColumn column;
  final bool active;

  const _WishColumnChip({required this.column, required this.active});

  @override
  Widget build(BuildContext context) {
    final disabled = column.essential;
    final label = column.label.isEmpty ? 'Photo' : column.label;
    final bg = active
        ? (disabled ? AppColors.bg3 : const Color(0x29C9A84C))
        : AppColors.bg3;
    final border =
        active && !disabled ? const Color(0x66C9A84C) : AppColors.border;
    final fg = active
        ? (disabled ? AppColors.text2 : AppColors.gold2)
        : AppColors.text3;

    return InkWell(
      onTap: disabled
          ? null
          : () {
              final next = {...CavePreferencesService.wishVisible.value};
              if (active) {
                next.remove(column);
              } else {
                next.add(column);
              }
              CavePreferencesService.setWishVisible(next);
            },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? (disabled ? Icons.lock : Icons.check) : Icons.add,
              size: 12,
              color: fg,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppText.sans(
                color: fg,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CellarSettingsContent extends StatelessWidget {
  const _CellarSettingsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ZoomControl(),
        const SizedBox(height: 20),
        StreamBuilder<List<Cellar>>(
          stream: CellarService.watch(),
          builder: (context, snap) {
            final cellars = snap.data ?? [];
            if (cellars.isEmpty) {
              return Text(
                'Aucun cellier configuré.',
                style: AppText.sans(color: AppColors.text3, fontSize: 13),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < cellars.length; i++) ...[
                  _CellarSettingsRow(cellar: cellars[i]),
                  if (i < cellars.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ZoomControl extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CavePreferencesService.cellarZoom,
      builder: (context, zoom, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.zoom_in, size: 16, color: AppColors.text3),
              const SizedBox(width: 10),
              Text(
                'Taille des cases',
                style: AppText.sans(color: AppColors.text2, fontSize: 13),
              ),
              const Spacer(),
              _zoomButton(
                icon: Icons.remove,
                enabled: zoom > 1,
                onTap: () => CavePreferencesService.setCellarZoom(zoom - 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$zoom',
                  style: AppText.sans(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _zoomButton(
                icon: Icons.add,
                enabled: zoom < 10,
                onTap: () => CavePreferencesService.setCellarZoom(zoom + 1),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _zoomButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? AppColors.text2 : AppColors.text3,
        ),
      ),
    );
  }
}

class _CellarSettingsRow extends StatelessWidget {
  final Cellar cellar;
  const _CellarSettingsRow({required this.cellar});

  @override
  Widget build(BuildContext context) {
    final c = cellar;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x1FC9A84C),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x40C9A84C)),
              ),
              child: Text(
                'N°${c.number}',
                style: AppText.sans(
                  color: AppColors.gold2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name.isEmpty ? 'Cellier ${c.number}' : c.name,
                    style: AppText.serif(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${c.cols} colonnes × ${c.rows} rangées · ${c.totalSlots} cases',
                    style: AppText.sans(color: AppColors.text3, fontSize: 11),
                  ),
                ],
              ),
            ),
            _actionButton(
              context: context,
              icon: Icons.edit_outlined,
              tooltip: 'Modifier',
              onTap: () => _onEdit(context, c),
            ),
            const SizedBox(width: 6),
            _actionButton(
              context: context,
              icon: Icons.delete_outline,
              tooltip: 'Supprimer',
              danger: true,
              onTap: () => _onDelete(context, c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? const Color(0xFFE07060) : AppColors.text2;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.bg4,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border2),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  Future<void> _onEdit(BuildContext context, Cellar c) async {
    final result = await showDialog<CellarFormResult>(
      context: context,
      builder: (_) => CellarFormDialog(
        title: 'Modifier le cellier',
        initialNumber: c.number,
        initialName: c.name,
        initialCols: c.cols,
        initialRows: c.rows,
      ),
    );
    if (result == null) return;
    if (result.number != c.number) {
      final taken = await CellarService.isNumberTaken(result.number, exceptId: c.id);
      if (!context.mounted) return;
      if (taken) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF6E2A20),
            content: Text('Le numéro ${result.number} est déjà utilisé.',
                style: AppText.sans(color: AppColors.text)),
          ),
        );
        return;
      }
    }
    await CellarService.update(
      c.id,
      number: result.number,
      name: result.name,
      cols: result.cols,
      rows: result.rows,
    );
  }

  Future<void> _onDelete(BuildContext context, Cellar c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border2),
        ),
        title: Text(
          'Supprimer le cellier ?',
          style: AppText.serif(color: AppColors.gold2, fontSize: 18),
        ),
        content: Text(
          'Le cellier ${c.number}${c.name.isEmpty ? '' : ' (${c.name})'} sera supprimé. Cette action est irréversible.',
          style: AppText.sans(color: AppColors.text2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler',
                style: AppText.sans(color: AppColors.text2, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer',
                style: AppText.sans(
                    color: const Color(0xFFE07060),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CellarService.delete(c.id);
  }
}

class _StatsSettingsContent extends StatefulWidget {
  const _StatsSettingsContent();

  @override
  State<_StatsSettingsContent> createState() => _StatsSettingsContentState();
}

class _StatsSettingsContentState extends State<_StatsSettingsContent> {
  late List<List<StatItem>> _layout;
  late bool _hidePrices;
  late Map<StatItem, StatChartType> _chartTypes;

  @override
  void initState() {
    super.initState();
    _layout = CavePreferencesService.statsLayout.value
        .map((r) => List<StatItem>.from(r))
        .toList();
    _hidePrices = CavePreferencesService.statsHidePrices.value;
    _chartTypes = Map.from(CavePreferencesService.statsChartTypes.value);
  }

  void _save() {
    CavePreferencesService.setStatsLayout(_layout);
    // Keep statsOrder in sync (flat)
    CavePreferencesService.setStatsOrder(_layout.expand((r) => r).toList());
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final row = _layout.removeAt(oldIndex);
      _layout.insert(newIndex, row);
    });
    _save();
  }

  void _mergeWithNext(int rowIndex) {
    if (rowIndex >= _layout.length - 1) return;
    if (_layout[rowIndex].length >= 3) return;
    setState(() {
      final next = _layout.removeAt(rowIndex + 1);
      final space = 3 - _layout[rowIndex].length;
      _layout[rowIndex].addAll(next.take(space));
      if (next.length > space) {
        _layout.insert(rowIndex + 1, next.sublist(space));
      }
    });
    _save();
  }

  void _splitItem(int rowIndex, int itemIndex) {
    if (_layout[rowIndex].length <= 1) return;
    setState(() {
      final item = _layout[rowIndex].removeAt(itemIndex);
      _layout.insert(rowIndex + 1, [item]);
    });
    _save();
  }

  void _cycleChartType(StatItem item) {
    final allowed = item.allowedTypes;
    if (allowed.length < 2) return;
    final current = _chartTypes[item] ?? item.chartType;
    final idx = allowed.indexOf(current);
    final next = allowed[(idx + 1) % allowed.length];
    setState(() {
      if (next == item.chartType) {
        _chartTypes.remove(item);
      } else {
        _chartTypes[item] = next;
      }
    });
    CavePreferencesService.setStatsChartType(item, next);
  }

  void _toggleHidePrices(bool? val) {
    setState(() => _hidePrices = val ?? false);
    CavePreferencesService.setStatsHidePrices(_hidePrices);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SettingsSubsection(
          title: 'Masquer les prix',
          description: 'Cache toutes les statistiques liées aux prix et valeurs financières.',
          child: InkWell(
            onTap: () => _toggleHidePrices(!_hidePrices),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _hidePrices,
                      onChanged: _toggleHidePrices,
                      activeColor: AppColors.gold,
                      checkColor: const Color(0xFF1A1408),
                      side: const BorderSide(color: AppColors.text3),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Masquer valeur de la cave, plus-value et distribution des prix',
                      style: AppText.sans(
                        color: _hidePrices ? AppColors.gold2 : AppColors.text2,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSubsection(
          title: 'Disposition des statistiques',
          description: 'Glisse les rangées pour réorganiser. Utilise les boutons pour grouper ou séparer.',
          trailing: [
            TextButton(
              onPressed: () {
                setState(() {
                  _layout = StatItem.defaultLayout
                      .map((r) => List<StatItem>.from(r))
                      .toList();
                  _hidePrices = false;
                  _chartTypes = {};
                });
                CavePreferencesService.resetStatsToDefaults();
              },
              child: Text(
                'Réinitialiser',
                style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          child: ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _layout.length,
            onReorder: _onReorder,
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => Transform.scale(
                    scale: 1.02,
                    child: child,
                  ),
                  child: child,
                ),
              );
            },
            itemBuilder: (context, rowIndex) {
              final row = _layout[rowIndex];
              final canMerge = rowIndex < _layout.length - 1 && row.length < 3;
              return _StatRowTile(
                key: ValueKey(row.map((e) => e.name).join(',')),
                rowIndex: rowIndex,
                items: row,
                hidePrices: _hidePrices,
                chartTypes: _chartTypes,
                canMerge: canMerge,
                onMerge: () => _mergeWithNext(rowIndex),
                onSplit: (itemIndex) => _splitItem(rowIndex, itemIndex),
                onCycleType: _cycleChartType,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatRowTile extends StatelessWidget {
  final int rowIndex;
  final List<StatItem> items;
  final bool hidePrices;
  final Map<StatItem, StatChartType> chartTypes;
  final bool canMerge;
  final VoidCallback onMerge;
  final void Function(int) onSplit;
  final void Function(StatItem) onCycleType;

  const _StatRowTile({
    super.key,
    required this.rowIndex,
    required this.items,
    required this.hidePrices,
    required this.chartTypes,
    required this.canMerge,
    required this.onMerge,
    required this.onSplit,
    required this.onCycleType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: rowIndex,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: AppColors.text3,
                    ),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        _StatItemChip(
                          item: items[i],
                          hidden: hidePrices && items[i].isPriceRelated,
                          currentType: chartTypes[items[i]] ?? items[i].chartType,
                          canSplit: items.length > 1,
                          onSplit: () => onSplit(i),
                          onCycleType: () => onCycleType(items[i]),
                        ),
                    ],
                  ),
                ),
                if (canMerge)
                  Tooltip(
                    message: 'Grouper avec la rangée suivante',
                    child: InkWell(
                      onTap: onMerge,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.add_circle_outline,
                          size: 18,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItemChip extends StatelessWidget {
  final StatItem item;
  final bool hidden;
  final StatChartType currentType;
  final bool canSplit;
  final VoidCallback onSplit;
  final VoidCallback onCycleType;

  const _StatItemChip({
    required this.item,
    required this.hidden,
    required this.currentType,
    required this.canSplit,
    required this.onSplit,
    required this.onCycleType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: hidden ? Colors.transparent : const Color(0x0FC9A84C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hidden ? AppColors.border : const Color(0x33C9A84C),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: item.allowedTypes.length > 1 ? onCycleType : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0x22C9A84C),
                borderRadius: BorderRadius.circular(3),
                border: item.allowedTypes.length > 1
                    ? Border.all(color: AppColors.gold.withValues(alpha: 0.4))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentType.label,
                    style: AppText.sans(
                      color: hidden ? AppColors.text3 : AppColors.gold,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (item.allowedTypes.length > 1) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.swap_horiz, size: 8,
                        color: hidden ? AppColors.text3 : AppColors.gold),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            item.label,
            style: AppText.sans(
              color: hidden ? AppColors.text3 : AppColors.text2,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (item.isPriceRelated) ...[
            const SizedBox(width: 4),
            Text(
              '\$',
              style: AppText.sans(
                color: hidden ? AppColors.text3 : AppColors.gold2,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (hidden) ...[
            const SizedBox(width: 4),
            const Icon(Icons.visibility_off, size: 12, color: AppColors.text3),
          ],
          if (canSplit) ...[
            const SizedBox(width: 4),
            InkWell(
              onTap: onSplit,
              child: const Icon(Icons.close, size: 12, color: AppColors.text3),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActualisationContent extends StatefulWidget {
  const _ActualisationContent();

  @override
  State<_ActualisationContent> createState() => _ActualisationContentState();
}

class _ActualisationContentState extends State<_ActualisationContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Wine> _wines = [];
  final Map<String, MarketHistoryEntry?> _latestMarket = {};
  final Map<String, GardeHistoryEntry?> _latestGarde = {};
  bool _loading = true;

  bool _bulkMarketRunning = false;
  int _bulkMarketDone = 0;
  int _bulkMarketTotal = 0;

  bool _bulkGardeRunning = false;
  int _bulkGardeDone = 0;
  int _bulkGardeTotal = 0;

  final Set<String> _refreshingMarket = {};
  final Set<String> _refreshingGarde = {};

  bool _autoRefreshEnabled = false;
  int _autoRefreshPercent = 10;
  String _autoRefreshPeriod = 'month';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _autoRefreshEnabled = CavePreferencesService.autoRefreshEnabled.value;
    _autoRefreshPercent = CavePreferencesService.autoRefreshPercent.value;
    _autoRefreshPeriod = CavePreferencesService.autoRefreshPeriod.value;
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final wineSnap = await CaveService.wines().first;
    final (marketList, gardeList) = await (
      Future.wait(wineSnap.map((w) => ActualisationService.getMarketHistory(w.id))),
      Future.wait(wineSnap.map((w) => ActualisationService.getGardeHistory(w.id))),
    ).wait;
    if (!mounted) return;
    setState(() {
      _wines = wineSnap;
      for (var i = 0; i < wineSnap.length; i++) {
        _latestMarket[wineSnap[i].id] = marketList[i].isNotEmpty ? marketList[i].first : null;
        _latestGarde[wineSnap[i].id] = gardeList[i].isNotEmpty ? gardeList[i].first : null;
      }
      _loading = false;
    });
  }

  Future<void> _refreshOne(Wine wine, {required bool isMarket}) async {
    final refreshing = isMarket ? _refreshingMarket : _refreshingGarde;
    setState(() => refreshing.add(wine.id));
    try {
      await ActualisationService.seedIfNeeded(wine);
      if (isMarket) {
        await ActualisationService.refreshMarketValue(wine);
        final mh = await ActualisationService.getMarketHistory(wine.id);
        if (mounted) setState(() => _latestMarket[wine.id] = mh.isNotEmpty ? mh.first : null);
      } else {
        await ActualisationService.refreshGarde(wine);
        final gh = await ActualisationService.getGardeHistory(wine.id);
        if (mounted) setState(() => _latestGarde[wine.id] = gh.isNotEmpty ? gh.first : null);
      }
    } catch (_) {}
    if (mounted) setState(() => refreshing.remove(wine.id));
  }

  Future<void> _bulkRefreshMarket() async {
    setState(() {
      _bulkMarketRunning = true;
      _bulkMarketDone = 0;
      _bulkMarketTotal = _wines.length;
    });
    await ActualisationService.refreshAllMarketValues(
      _wines,
      onProgress: (done, _) {
        if (mounted) setState(() => _bulkMarketDone = done);
      },
    );
    final marketList = await Future.wait(_wines.map((w) => ActualisationService.getMarketHistory(w.id)));
    if (mounted) {
      setState(() {
        for (var i = 0; i < _wines.length; i++) {
          _latestMarket[_wines[i].id] = marketList[i].isNotEmpty ? marketList[i].first : null;
        }
        _bulkMarketRunning = false;
      });
    }
  }

  Future<void> _bulkRefreshGarde() async {
    setState(() {
      _bulkGardeRunning = true;
      _bulkGardeDone = 0;
      _bulkGardeTotal = _wines.length;
    });
    await ActualisationService.refreshAllGarde(
      _wines,
      onProgress: (done, _) {
        if (mounted) setState(() => _bulkGardeDone = done);
      },
    );
    final gardeList = await Future.wait(_wines.map((w) => ActualisationService.getGardeHistory(w.id)));
    if (mounted) {
      setState(() {
        for (var i = 0; i < _wines.length; i++) {
          _latestGarde[_wines[i].id] = gardeList[i].isNotEmpty ? gardeList[i].first : null;
        }
        _bulkGardeRunning = false;
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String? _marketSubtitle(MarketHistoryEntry? e) =>
      e != null ? '${e.value.toStringAsFixed(2)} \$ · ${_formatDate(e.timestamp)}' : null;

  String? _gardeSubtitle(GardeHistoryEntry? e) {
    if (e == null) return null;
    final parts = <String>[];
    if (e.drinkFrom != null) parts.add('De ${e.drinkFrom}');
    if (e.drinkPeak != null) parts.add('Apogée ${e.drinkPeak}');
    if (e.drinkTo != null) parts.add('Jusqu\'à ${e.drinkTo}');
    return '${parts.isEmpty ? '—' : parts.join(' · ')} · ${_formatDate(e.timestamp)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.gold2,
            unselectedLabelColor: AppColors.text3,
            labelStyle: AppText.sans(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: AppText.sans(fontSize: 13),
            dividerHeight: 0,
            tabs: const [
              Tab(text: 'Valeur marché'),
              Tab(text: 'Période de garde'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _tabController.index == 0 ? _buildTab(isMarket: true) : _buildTab(isMarket: false),
        ),
        const SizedBox(height: 20),
        _buildAutoRefreshSection(),
      ],
    );
  }

  Widget _buildTab({required bool isMarket}) {
    final bulkRunning = isMarket ? _bulkMarketRunning : _bulkGardeRunning;
    final bulkDone = isMarket ? _bulkMarketDone : _bulkGardeDone;
    final bulkTotal = isMarket ? _bulkMarketTotal : _bulkGardeTotal;
    final refreshing = isMarket ? _refreshingMarket : _refreshingGarde;
    return Column(
      key: ValueKey(isMarket),
      children: [
        Row(children: [
          const Spacer(),
          _bulkButton(
            running: bulkRunning,
            done: bulkDone,
            total: bulkTotal,
            onTap: isMarket ? _bulkRefreshMarket : _bulkRefreshGarde,
          ),
        ]),
        const SizedBox(height: 12),
        if (bulkRunning) ...[
          _progressBar(bulkDone, bulkTotal),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < _wines.length; i++) ...[
          _HistoryWineRow(
            wine: _wines[i],
            subtitle: isMarket
                ? _marketSubtitle(_latestMarket[_wines[i].id])
                : _gardeSubtitle(_latestGarde[_wines[i].id]),
            refreshing: refreshing.contains(_wines[i].id),
            isMarket: isMarket,
            onRefresh: () => _refreshOne(_wines[i], isMarket: isMarket),
          ),
          if (i < _wines.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildAutoRefreshSection() {
    return _SettingsSubsection(
      title: 'Refresh automatique',
      description:
          'Actualise automatiquement un pourcentage de tes vins à intervalle régulier via Cloud Function.',
      child: Column(
        children: [
          InkWell(
            onTap: () {
              final newVal = !_autoRefreshEnabled;
              setState(() => _autoRefreshEnabled = newVal);
              CavePreferencesService.setAutoRefreshEnabled(newVal);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: IgnorePointer(
                      child: Checkbox(
                        value: _autoRefreshEnabled,
                        onChanged: null,
                        activeColor: AppColors.gold,
                        checkColor: const Color(0xFF1A1408),
                        side: const BorderSide(color: AppColors.text3),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Activer le refresh automatique',
                    style: AppText.sans(
                      color: _autoRefreshEnabled ? AppColors.gold2 : AppColors.text2,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_autoRefreshEnabled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dropdownField<int>(
                    value: _autoRefreshPercent,
                    items: const [5, 10, 20, 25],
                    itemLabel: (v) => '$v %',
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _autoRefreshPercent = v);
                      CavePreferencesService.setAutoRefreshPercent(v);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _dropdownField<String>(
                    value: _autoRefreshPeriod,
                    items: const ['week', 'month'],
                    itemLabel: (v) => v == 'week' ? 'Semaine' : 'Mois',
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _autoRefreshPeriod = v);
                      CavePreferencesService.setAutoRefreshPeriod(v);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bulkButton({
    required bool running,
    required int done,
    required int total,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: running ? null : onTap,
      icon: running
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
            )
          : const Icon(Icons.refresh, size: 14),
      label: Text(
        running ? '$done / $total' : 'Actualiser tout',
        style: AppText.sans(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold.withValues(alpha: 0.15),
        foregroundColor: AppColors.gold2,
        disabledBackgroundColor: AppColors.bg3,
        disabledForegroundColor: AppColors.text3,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        elevation: 0,
      ),
    );
  }

  Widget _progressBar(int done, int total) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: total > 0 ? done / total : 0.0,
        minHeight: 6,
        backgroundColor: AppColors.bg3,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
      ),
    );
  }

  Widget _dropdownField<T>({
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: AppColors.bg2,
          style: AppText.sans(color: AppColors.text, fontSize: 13),
          icon: const Icon(Icons.expand_more, size: 18, color: AppColors.text3),
          items: items.map((v) => DropdownMenuItem<T>(
            value: v,
            child: Text(itemLabel(v), style: AppText.sans(color: AppColors.text2, fontSize: 13)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _HistoryWineRow extends StatefulWidget {
  final Wine wine;
  final String? subtitle;
  final bool refreshing;
  final bool isMarket;
  final VoidCallback onRefresh;

  const _HistoryWineRow({
    required this.wine,
    required this.subtitle,
    required this.refreshing,
    required this.isMarket,
    required this.onRefresh,
  });

  @override
  State<_HistoryWineRow> createState() => _HistoryWineRowState();
}

class _HistoryWineRowState extends State<_HistoryWineRow> {
  bool _expanded = false;
  bool _loading = false;
  List<MarketHistoryEntry> _marketHistory = [];
  List<GardeHistoryEntry> _gardeHistory = [];

  Future<void> _loadHistory() async {
    if (_loading) return;
    setState(() => _loading = true);
    if (widget.isMarket) {
      final entries = await ActualisationService.getMarketHistory(widget.wine.id);
      if (mounted) setState(() { _marketHistory = entries; _loading = false; });
    } else {
      final entries = await ActualisationService.getGardeHistory(widget.wine.id);
      if (mounted) setState(() { _gardeHistory = entries; _loading = false; });
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtSource(String s) =>
      s == 'initial' ? 'Initial' : s == 'auto' ? 'Auto' : 'Gemini';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.wine.name}${widget.wine.vintage != null ? ' ${widget.wine.vintage}' : ''}',
                        style: AppText.serif(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle ?? 'Aucune estimation',
                        style: AppText.sans(
                          color: widget.subtitle != null ? AppColors.gold2 : AppColors.text3,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    final nowExpanded = !_expanded;
                    setState(() => _expanded = nowExpanded);
                    if (nowExpanded) _loadHistory();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.bg4,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border2),
                    ),
                    child: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 15,
                      color: AppColors.text2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _refreshButton(refreshing: widget.refreshing, onTap: widget.onRefresh),
              ],
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: AppColors.border),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(14),
                child: Center(child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                )),
              )
            else if (widget.isMarket)
              _marketHistory.isEmpty
                  ? _emptyHistory()
                  : Column(children: [
                      for (int i = 0; i < _marketHistory.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: AppColors.border),
                        _MarketHistoryRow(
                          entry: _marketHistory[i],
                          prev: i + 1 < _marketHistory.length ? _marketHistory[i + 1] : null,
                          date: _fmtDate(_marketHistory[i].timestamp),
                          source: _fmtSource(_marketHistory[i].source),
                        ),
                      ],
                    ])
            else
              _gardeHistory.isEmpty
                  ? _emptyHistory()
                  : Column(children: [
                      for (int i = 0; i < _gardeHistory.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: AppColors.border),
                        _GardeHistoryRow(
                          entry: _gardeHistory[i],
                          date: _fmtDate(_gardeHistory[i].timestamp),
                          source: _fmtSource(_gardeHistory[i].source),
                        ),
                      ],
                    ]),
          ],
        ],
      ),
    );
  }

  Widget _emptyHistory() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Text('Aucun historique', style: AppText.sans(color: AppColors.text3, fontSize: 12)),
  );
}

class _MarketHistoryRow extends StatelessWidget {
  final MarketHistoryEntry entry;
  final MarketHistoryEntry? prev;
  final String date;
  final String source;

  const _MarketHistoryRow({
    required this.entry,
    required this.date,
    required this.source,
    this.prev,
  });

  @override
  Widget build(BuildContext context) {
    final delta = prev != null ? entry.value - prev!.value : null;
    final up = delta != null && delta > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(date, style: AppText.sans(color: AppColors.text3, fontSize: 11)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bg4,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(source, style: AppText.sans(color: AppColors.text3, fontSize: 10)),
          ),
          const Spacer(),
          if (delta != null && delta != 0) ...[
            Icon(
              up ? Icons.arrow_upward : Icons.arrow_downward,
              size: 11,
              color: up ? const Color(0xFF7CD492) : const Color(0xFFE8667A),
            ),
            const SizedBox(width: 2),
            Text(
              '${delta.abs().toStringAsFixed(0)} \$',
              style: AppText.sans(
                color: up ? const Color(0xFF7CD492) : const Color(0xFFE8667A),
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Text(
            '${entry.value.toStringAsFixed(0)} \$',
            style: AppText.serif(color: AppColors.gold2, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _GardeHistoryRow extends StatelessWidget {
  final GardeHistoryEntry entry;
  final String date;
  final String source;

  const _GardeHistoryRow({
    required this.entry,
    required this.date,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (entry.drinkFrom != null) '${entry.drinkFrom}',
      if (entry.drinkPeak != null) '${entry.drinkPeak}',
      if (entry.drinkTo != null) '${entry.drinkTo}',
    ];
    final range = parts.join(' → ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Text(date, style: AppText.sans(color: AppColors.text3, fontSize: 11)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bg4,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(source, style: AppText.sans(color: AppColors.text3, fontSize: 10)),
          ),
          const Spacer(),
          Text(
            range,
            style: AppText.serif(color: AppColors.gold2, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

Widget _refreshButton({required bool refreshing, required VoidCallback onTap}) {
  return InkWell(
    onTap: refreshing ? null : onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.bg4,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border2),
      ),
      child: refreshing
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
            )
          : const Icon(Icons.refresh, size: 15, color: AppColors.text2),
    ),
  );
}
