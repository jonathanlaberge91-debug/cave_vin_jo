import 'package:flutter/material.dart';
import '../models/bottle.dart';
import '../models/cave_column.dart';
import '../models/cellar.dart';
import '../models/drunk_column.dart';
import '../models/market_history.dart';
import '../models/garde_history.dart';
import '../models/stat_item.dart';
import '../models/wine.dart';
import '../models/wish_column.dart';
import '../services/actualisation_service.dart';
import '../services/backup_service.dart';
import '../services/cave_preferences_service.dart';
import '../services/drive_backup_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/cave_service.dart';
import '../services/cellar_service.dart';
import '../services/gemini_service.dart';
import '../services/govee_service.dart';
import '../services/groq_service.dart';
import '../services/history_service.dart';
import '../services/mistral_service.dart';
import '../services/maps_service.dart';
import '../services/wine_pdf_service.dart';
import '../dialogs/cellar_form_dialog.dart';
import '../theme/app_text.dart';
import '../theme/app_colors.dart';
import 'govee_sensors_screen.dart';
import 'wine_cellar_screen.dart';

class SettingsScreen extends StatelessWidget {
  final int section;
  const SettingsScreen({super.key, this.section = 0});

  @override
  Widget build(BuildContext context) {
    if (section == 6) return const GoveeSensorsScreen();
    if (section == 7) return const WineCellarScreen();
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
        9 => const _SettingsSection(
            title: 'Export',
            icon: Icons.download_outlined,
            description:
                'Exporte l\'inventaire de ta cave en CSV (tableur) ou en PDF (rapport imprimable).',
            child: _ExportContent(),
          ),
        10 => const _SettingsSection(
            title: 'Historique',
            icon: Icons.history_outlined,
            description:
                'Annule une suppression ou la mise en « bue » d\'une bouteille. Les actions des 30 derniers jours sont conservées.',
            child: _HistoryContent(),
          ),
        11 => const _SettingsSection(
            title: 'Sécurité',
            icon: Icons.lock_outline,
            description:
                'Verrouille l\'app avec ton empreinte ou Face ID au démarrage.',
            child: _SecurityContent(),
          ),
        12 => const _SettingsSection(
            title: 'Compte',
            icon: Icons.account_circle_outlined,
            description:
                'Compte Google connecté à cette cave.',
            child: _AccountContent(),
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

class _SettingsSubsection extends StatefulWidget {
  final String title;
  final String? description;
  final Widget child;
  final List<Widget> trailing;
  final bool collapsible;

  const _SettingsSubsection({
    required this.title,
    this.description,
    required this.child,
    this.trailing = const [],
    this.collapsible = false,
  });

  @override
  State<_SettingsSubsection> createState() => _SettingsSubsectionState();
}

class _SettingsSubsectionState extends State<_SettingsSubsection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.collapsible) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: AppText.serif(color: AppColors.gold2, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ...widget.trailing,
            ],
          ),
          if (widget.description != null) ...[
            const SizedBox(height: 4),
            Text(widget.description!, style: AppText.sans(color: AppColors.text3, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          widget.child,
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(10))
                : BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: AppText.serif(color: AppColors.gold2, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        if (widget.description != null && !_expanded) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.description!,
                            style: AppText.sans(color: AppColors.text3, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  ...widget.trailing,
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.text3,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: widget.child,
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _confirmReset(BuildContext context, VoidCallback onConfirm) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border2),
      ),
      title: Text(
        'Réinitialiser les colonnes ?',
        style: AppText.serif(color: AppColors.gold2, fontSize: 18),
      ),
      content: Text(
        'Les colonnes affichées seront remises aux valeurs par défaut.',
        style: AppText.sans(color: AppColors.text2, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Annuler', style: AppText.sans(color: AppColors.text2, fontSize: 13)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Réinitialiser', style: AppText.sans(color: const Color(0xFFE07060), fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
  if (ok == true) onConfirm();
}

class _ApiKeysContent extends StatefulWidget {
  const _ApiKeysContent();

  @override
  State<_ApiKeysContent> createState() => _ApiKeysContentState();
}

class _ApiKeysContentState extends State<_ApiKeysContent> {
  final _geminiKey = TextEditingController(text: GeminiService.apiKey ?? '');
  final _groqKey = TextEditingController(text: GroqService.apiKey ?? '');
  final _mistralKey =
      TextEditingController(text: MistralService.apiKey ?? '');
  final _mapsKey = TextEditingController(text: MapsService.apiKey ?? '');
  final _goveeKey = TextEditingController(text: GoveeService.apiKey ?? '');
  bool _obscureGemini = true;
  bool _obscureGroq = true;
  bool _obscureMistral = true;
  bool _obscureMaps = true;
  bool _obscureGovee = true;
  bool _savedGemini = false;
  bool _savedGroq = false;
  bool _savedMistral = false;
  bool _savedMaps = false;
  bool _savedGovee = false;

  @override
  void dispose() {
    _geminiKey.dispose();
    _groqKey.dispose();
    _mistralKey.dispose();
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

  void _saveGroq() {
    final key = _groqKey.text.trim();
    GroqService.apiKey = key.isEmpty ? null : key;
    setState(() => _savedGroq = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedGroq = false);
    });
  }

  void _saveMistral() {
    final key = _mistralKey.text.trim();
    MistralService.apiKey = key.isEmpty ? null : key;
    setState(() => _savedMistral = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedMistral = false);
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
              'IA principale : remplit les fiches de vin (identification, fenêtre de dégustation, descriptions, critiques).',
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
          title: 'Groq (recoupage IA #1)',
          description:
              'Optionnel. 2e IA gratuite (Llama) qui croise les résultats de Gemini. Crée ta clé sur console.groq.com/keys. Photo + texte.',
          child: _buildKeyField(
            controller: _groqKey,
            hint: 'Coller votre clé API Groq ici…',
            obscure: _obscureGroq,
            onToggle: () => setState(() => _obscureGroq = !_obscureGroq),
            onSave: _saveGroq,
            saved: _savedGroq,
            configured: GroqService.isConfigured,
          ),
        ),
        const SizedBox(height: 24),
        _SettingsSubsection(
          title: 'Mistral (recoupage IA #2)',
          description:
              'Optionnel. 3e IA gratuite (Mistral Large + Pixtral). Sans carte de crédit. Photo + texte. Crée ta clé sur console.mistral.ai → API Keys.',
          child: _buildKeyField(
            controller: _mistralKey,
            hint: 'Coller votre clé API Mistral ici…',
            obscure: _obscureMistral,
            onToggle: () =>
                setState(() => _obscureMistral = !_obscureMistral),
            onSave: _saveMistral,
            saved: _savedMistral,
            configured: MistralService.isConfigured,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: CavePreferencesService.hidePrices,
          builder: (context, hide, _) {
            return _ToggleRow(
              label: 'Cacher les prix',
              subtitle: 'Masque toutes les informations financières dans l\'app.',
              value: hide,
              onChanged: (v) => CavePreferencesService.setHidePrices(v),
            );
          },
        ),
        const SizedBox(height: 16),
        ValueListenableBuilder<Set<CaveColumn>>(
          valueListenable: CavePreferencesService.visible,
          builder: (context, visible, _) {
            return _SettingsSubsection(
          title: 'Colonnes du tableau',
          description:
              'Active les colonnes que tu veux voir. Photo, Vin et Qté sont toujours affichées.',
          collapsible: true,
          trailing: [
            TextButton(
              onPressed: () => _confirmReset(context, CavePreferencesService.resetToDefaults),
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
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.label, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppText.sans(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: AppText.sans(color: AppColors.text3, fontSize: 11)),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.gold,
              activeTrackColor: AppColors.gold.withValues(alpha: 0.3),
              inactiveThumbColor: AppColors.text3,
              inactiveTrackColor: AppColors.bg4,
            ),
          ],
        ),
      ),
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
          collapsible: true,
          trailing: [
            TextButton(
              onPressed: () => _confirmReset(context, CavePreferencesService.resetDrunkToDefaults),
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
          collapsible: true,
          trailing: [
            TextButton(
              onPressed: () => _confirmReset(context, CavePreferencesService.resetWishToDefaults),
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

  Future<void> _onAdd(BuildContext context, List<Cellar> cellars) async {
    int nextNumber = 1;
    for (final c in cellars) {
      if (c.number >= nextNumber) nextNumber = c.number + 1;
    }
    final result = await showDialog<CellarFormResult>(
      context: context,
      builder: (_) => CellarFormDialog(
        title: 'Ajouter un cellier',
        initialNumber: nextNumber,
        initialName: '',
        initialCols: 12,
        initialRows: 8,
      ),
    );
    if (result == null) return;
    final taken = await CellarService.isNumberTaken(result.number);
    if (!context.mounted) return;
    if (taken) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF6E2A20),
          content: Text(
            'Le numéro ${result.number} est déjà utilisé.',
            style: AppText.sans(color: AppColors.text),
          ),
        ),
      );
      return;
    }
    await CellarService.add(
      number: result.number,
      name: result.name,
      cols: result.cols,
      rows: result.rows,
    );
  }

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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _onAdd(context, cellars),
                  icon: const Icon(Icons.add, size: 14),
                  label: Text(
                    'Ajouter un cellier',
                    style: AppText.sans(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                    foregroundColor: AppColors.gold2,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                    ),
                    elevation: 0,
                  ),
                ),
                if (cellars.isEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Aucun cellier configuré.',
                    style: AppText.sans(color: AppColors.text3, fontSize: 13),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  for (var i = 0; i < cellars.length; i++) ...[
                    _CellarSettingsRow(cellar: cellars[i]),
                    if (i < cellars.length - 1) const SizedBox(height: 10),
                  ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Infos',
                  style: AppText.sans(
                    color: AppColors.text3,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                _infoGrid(c),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoGrid(Cellar c) {
    final rows = <({String label, String value})>[
      (label: 'ID Firestore', value: c.id),
      (label: 'Numéro', value: '${c.number}'),
      (label: 'Nom', value: c.name.isEmpty ? '—' : c.name),
      (label: 'Colonnes', value: '${c.cols}'),
      (label: 'Rangées', value: '${c.rows}'),
      (label: 'Cases totales', value: '${c.totalSlots}'),
      (label: 'Créé le', value: _formatDate(c.createdAt)),
      (label: 'Tuya Device ID', value: c.tuyaDeviceId ?? 'Non configuré'),
      (label: 'Tuya Local Key', value: c.tuyaLocalKey ?? 'Non configuré'),
      if (c.tuyaIp != null) (label: 'Tuya IP', value: c.tuyaIp!),
      if (c.tuyaVersion != null) (label: 'Tuya Version', value: c.tuyaVersion!),
      if (c.goveeTopDevice != null)
        (label: 'Govee haut', value: c.goveeTopDevice!),
      if (c.goveeBottomDevice != null)
        (label: 'Govee bas', value: c.goveeBottomDevice!),
      if (c.goveeTopDevice == null && c.goveeBottomDevice == null)
        (label: 'Capteurs Govee', value: 'Aucun'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: [
        for (final r in rows)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.bg4,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${r.label} ',
                  style: AppText.sans(color: AppColors.text3, fontSize: 10),
                ),
                Text(
                  r.value,
                  style: AppText.sans(
                    color: AppColors.text2,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final y = dt.year;
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d/$mo/$y $h:$mi';
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
        initialGoveeTop: c.goveeTopDevice,
        initialGoveeBottom: c.goveeBottomDevice,
        initialTuyaDeviceId: c.tuyaDeviceId,
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
      goveeTopDevice: result.goveeTopDevice,
      goveeBottomDevice: result.goveeBottomDevice,
      tuyaDeviceId: result.tuyaDeviceId,
      clearGoveeTop: result.goveeTopDevice == null,
      clearGoveeBottom: result.goveeBottomDevice == null,
      clearTuyaDeviceId: result.tuyaDeviceId == null,
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

class _WineEntry {
  final Wine wine;
  final BottleFormat format;
  final List<Bottle> bottles;
  _WineEntry({required this.wine, required this.format, required this.bottles});
}

class _ActualisationContent extends StatefulWidget {
  const _ActualisationContent();

  @override
  State<_ActualisationContent> createState() => _ActualisationContentState();
}

class _ActualisationContentState extends State<_ActualisationContent>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<_WineEntry> _rows = [];
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

  List<Wine> get _uniqueWines {
    final seen = <String>{};
    return _rows.where((r) => seen.add(r.wine.id)).map((r) => r.wine).toList();
  }

  Future<void> _load() async {
    final (wineSnap, bottleSnap) = await (
      CaveService.wines().first,
      CaveService.bottlesInCave().first,
    ).wait;

    final rows = <_WineEntry>[];
    for (final wine in wineSnap) {
      final wineBottles = bottleSnap.where((b) => b.wineId == wine.id).toList();
      if (wineBottles.isEmpty) continue;
      final byFormat = <BottleFormat, List<Bottle>>{};
      for (final b in wineBottles) {
        byFormat.putIfAbsent(b.format, () => []).add(b);
      }
      for (final entry in byFormat.entries) {
        rows.add(_WineEntry(wine: wine, format: entry.key, bottles: entry.value));
      }
    }

    final uniqueIds = rows.map((r) => r.wine.id).toSet().toList();
    final (marketList, gardeList) = await (
      Future.wait(uniqueIds.map((id) => ActualisationService.getMarketHistory(id))),
      Future.wait(uniqueIds.map((id) => ActualisationService.getGardeHistory(id))),
    ).wait;
    if (!mounted) return;
    setState(() {
      _rows = rows;
      for (var i = 0; i < uniqueIds.length; i++) {
        _latestMarket[uniqueIds[i]] = marketList[i].isNotEmpty ? marketList[i].first : null;
        _latestGarde[uniqueIds[i]] = gardeList[i].isNotEmpty ? gardeList[i].first : null;
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
    final wines = _uniqueWines;
    setState(() {
      _bulkMarketRunning = true;
      _bulkMarketDone = 0;
      _bulkMarketTotal = wines.length;
    });
    await ActualisationService.refreshAllMarketValues(
      wines,
      onProgress: (done, _) {
        if (mounted) setState(() => _bulkMarketDone = done);
      },
    );
    final marketList = await Future.wait(wines.map((w) => ActualisationService.getMarketHistory(w.id)));
    if (mounted) {
      setState(() {
        for (var i = 0; i < wines.length; i++) {
          _latestMarket[wines[i].id] = marketList[i].isNotEmpty ? marketList[i].first : null;
        }
        _bulkMarketRunning = false;
      });
    }
  }

  Future<void> _bulkRefreshGarde() async {
    final wines = _uniqueWines;
    setState(() {
      _bulkGardeRunning = true;
      _bulkGardeDone = 0;
      _bulkGardeTotal = wines.length;
    });
    await ActualisationService.refreshAllGarde(
      wines,
      onProgress: (done, _) {
        if (mounted) setState(() => _bulkGardeDone = done);
      },
    );
    final gardeList = await Future.wait(wines.map((w) => ActualisationService.getGardeHistory(w.id)));
    if (mounted) {
      setState(() {
        for (var i = 0; i < wines.length; i++) {
          _latestGarde[wines[i].id] = gardeList[i].isNotEmpty ? gardeList[i].first : null;
        }
        _bulkGardeRunning = false;
      });
    }
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  double _marketMultiplier(BottleFormat f) {
    switch (f) {
      case BottleFormat.ml375:  return 0.55;
      case BottleFormat.ml750:  return 1.0;
      case BottleFormat.ml1500: return 2.5;
      case BottleFormat.ml3000: return 6.0;
      case BottleFormat.ml6000: return 14.0;
    }
  }

  String? _marketSubtitle(MarketHistoryEntry? e, BottleFormat format) {
    if (e == null) return null;
    final val = (e.value * _marketMultiplier(format)).toStringAsFixed(0);
    return '$val \$ · ${_formatDate(e.timestamp)}';
  }

  String? _gardeSubtitle(GardeHistoryEntry? e, BottleFormat format) {
    if (e == null) return null;
    final offset = format.gardeOffset;
    final parts = <String>[];
    if (e.drinkFrom != null) parts.add('De ${e.drinkFrom! + offset}');
    if (e.drinkPeak != null) parts.add('Apogée ${e.drinkPeak! + offset}');
    if (e.drinkTo != null) parts.add('Jusqu\'à ${e.drinkTo! + offset}');
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
        for (var i = 0; i < _rows.length; i++) ...[
          _HistoryWineRow(
            wine: _rows[i].wine,
            format: _rows[i].format,
            subtitle: isMarket
                ? _marketSubtitle(_latestMarket[_rows[i].wine.id], _rows[i].format)
                : _gardeSubtitle(_latestGarde[_rows[i].wine.id], _rows[i].format),
            refreshing: refreshing.contains(_rows[i].wine.id),
            isMarket: isMarket,
            onRefresh: () => _refreshOne(_rows[i].wine, isMarket: isMarket),
          ),
          if (i < _rows.length - 1) const SizedBox(height: 6),
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
  final BottleFormat format;
  final String? subtitle;
  final bool refreshing;
  final bool isMarket;
  final VoidCallback onRefresh;

  const _HistoryWineRow({
    required this.wine,
    required this.format,
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

  double _formatMultiplier(BottleFormat f) {
    switch (f) {
      case BottleFormat.ml375:  return 0.55;
      case BottleFormat.ml750:  return 1.0;
      case BottleFormat.ml1500: return 2.5;
      case BottleFormat.ml3000: return 6.0;
      case BottleFormat.ml6000: return 14.0;
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
                        '${widget.wine.name}${widget.wine.vintage != null ? ' ${widget.wine.vintage}' : ''} · ${widget.format.label}',
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
                          formatMultiplier: _formatMultiplier(widget.format),
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
                          gardeOffset: widget.format.gardeOffset,
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
  final double formatMultiplier;

  const _MarketHistoryRow({
    required this.entry,
    required this.date,
    required this.source,
    this.prev,
    this.formatMultiplier = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final val = entry.value * formatMultiplier;
    final prevVal = prev != null ? prev!.value * formatMultiplier : null;
    final delta = prevVal != null ? val - prevVal : null;
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
            '${val.toStringAsFixed(0)} \$',
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
  final int gardeOffset;

  const _GardeHistoryRow({
    required this.entry,
    required this.date,
    required this.source,
    this.gardeOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    int? shift(int? v) => v != null ? v + gardeOffset : null;
    final parts = <String>[
      if (entry.drinkFrom != null) '${shift(entry.drinkFrom)}',
      if (entry.drinkPeak != null) '${shift(entry.drinkPeak)}',
      if (entry.drinkTo != null) '${shift(entry.drinkTo)}',
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

class _ExportContent extends StatefulWidget {
  const _ExportContent();

  @override
  State<_ExportContent> createState() => _ExportContentState();
}

class _ExportContentState extends State<_ExportContent> {
  bool _exportingCsv = false;
  bool _exportingPdf = false;
  bool _backingUp = false;

  Future<void> _doExportCsv() async {
    setState(() => _exportingCsv = true);
    try {
      final (wines, bottles) = await (
        CaveService.wines().first,
        CaveService.bottlesInCave().first,
      ).wait;
      exportInventoryCsv(wines, bottles);
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _doExportPdf() async {
    setState(() => _exportingPdf = true);
    try {
      final (wines, bottles) = await (
        CaveService.wines().first,
        CaveService.bottlesInCave().first,
      ).wait;
      exportInventoryPdf(wines, bottles);
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _doBackup() async {
    setState(() => _backingUp = true);
    try {
      final result = await BackupService.performBackup();
      if (!mounted) return;
      String msg;
      Color color;
      switch (result) {
        case BackupResult.driveUploaded:
          msg = 'Backup uploadé sur Google Drive.';
          color = AppColors.gold;
          break;
        case BackupResult.downloaded:
          msg = 'Backup téléchargé localement.';
          color = AppColors.gold;
          break;
        case BackupResult.failed:
          msg = 'Échec du backup.';
          color = const Color(0xFFB23A48);
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: color,
          content: Text(msg,
              style: TextStyle(
                  color: result == BackupResult.failed
                      ? Colors.white
                      : const Color(0xFF1A1408))),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB23A48),
          content: Text(
            'Erreur backup : $e',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _exportButton(
          icon: Icons.table_chart_outlined,
          title: 'Exporter CSV',
          subtitle: 'Tableur compatible Excel, Google Sheets…',
          loading: _exportingCsv,
          onTap: _doExportCsv,
        ),
        const SizedBox(height: 12),
        _exportButton(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Exporter PDF inventaire',
          subtitle: 'Tableau imprimable, format A4 paysage',
          loading: _exportingPdf,
          onTap: _doExportPdf,
        ),
        const SizedBox(height: 24),
        Container(
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
                children: [
                  const Icon(Icons.cloud_download_outlined,
                      size: 18, color: AppColors.gold),
                  const SizedBox(width: 8),
                  Text(
                    'Backup complet (JSON)',
                    style: AppText.serif(
                      color: AppColors.gold2,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Sauvegarde tous tes vins, bouteilles, celliers, wishlist et paramètres dans un seul fichier JSON. Connecte Google Drive ci-dessous pour un upload automatique dans le dossier "Cave a Vin Backups".',
                style: AppText.sans(color: AppColors.text3, fontSize: 12),
              ),
              const SizedBox(height: 14),
              const _DriveConnectPanel(),
              const SizedBox(height: 14),
              ValueListenableBuilder<DateTime?>(
                valueListenable: BackupService.lastBackupAt,
                builder: (_, last, __) {
                  final txt = last == null
                      ? 'Aucun backup effectué'
                      : 'Dernier backup : ${_relTime(last)}';
                  return Text(
                    txt,
                    style: AppText.sans(
                        color: AppColors.text3, fontSize: 11),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _exportButton(
                      icon: Icons.download_outlined,
                      title: 'Sauvegarder maintenant',
                      subtitle: 'Télécharge un fichier .json',
                      loading: _backingUp,
                      onTap: _doBackup,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: BackupService.autoBackupEnabled,
                builder: (_, enabled, __) {
                  return InkWell(
                    onTap: () => BackupService.setAutoBackup(!enabled),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            enabled
                                ? Icons.toggle_on
                                : Icons.toggle_off_outlined,
                            color: enabled
                                ? AppColors.gold
                                : AppColors.text3,
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Backup automatique quotidien',
                                  style: AppText.sans(
                                    color: AppColors.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Au lancement de l\'app, si > 24 h depuis le dernier backup',
                                  style: AppText.sans(
                                      color: AppColors.text3,
                                      fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _relTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 30) return 'il y a ${diff.inDays} j';
    return '${t.day}/${t.month}/${t.year}';
  }

  Widget _exportButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
                    )
                  : Icon(icon, size: 20, color: AppColors.gold),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.serif(
                      color: AppColors.gold2,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppText.sans(color: AppColors.text3, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: loading ? AppColors.text3 : AppColors.text2,
            ),
          ],
        ),
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

class _DriveConnectPanel extends StatefulWidget {
  const _DriveConnectPanel();
  @override
  State<_DriveConnectPanel> createState() => _DriveConnectPanelState();
}

class _DriveConnectPanelState extends State<_DriveConnectPanel> {
  late final TextEditingController _ctrl;
  bool _saving = false;
  bool _connecting = false;
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: DriveBackupService.clientId ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _saveClientId() async {
    setState(() => _saving = true);
    try {
      await DriveBackupService.setClientId(_ctrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.gold,
          content: Text(
            _ctrl.text.trim().isEmpty
                ? 'Client ID effacé.'
                : 'Client ID enregistré. Clique sur Connecter.',
            style: const TextStyle(color: Color(0xFF1A1408)),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      final ok = await DriveBackupService.connect();
      if (!mounted) return;
      final err = DriveBackupService.lastError.value;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? AppColors.gold : const Color(0xFFB23A48),
          duration: Duration(seconds: ok ? 3 : 10),
          content: Text(
            ok
                ? 'Connecté à Google Drive.'
                : 'Connexion échouée — ${err ?? "raison inconnue"}',
            style: TextStyle(
                color: ok ? const Color(0xFF1A1408) : Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _disconnect() async {
    await DriveBackupService.disconnect();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Color(0xFF7C7468),
        content: Text('Déconnecté de Google Drive.',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.cloud_outlined,
                size: 16, color: AppColors.gold),
            const SizedBox(width: 6),
            Text(
              'Google Drive',
              style: AppText.sans(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            ValueListenableBuilder<bool>(
              valueListenable: DriveBackupService.isConnected,
              builder: (_, connected, __) {
                return ValueListenableBuilder<String?>(
                  valueListenable: DriveBackupService.currentEmail,
                  builder: (_, email, __) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: connected
                            ? const Color(0x227CD492)
                            : AppColors.bg3,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: connected
                              ? const Color(0xFF7CD492)
                              : AppColors.border2,
                        ),
                      ),
                      child: Text(
                        connected
                            ? (email ?? 'connecté')
                            : 'non connecté',
                        style: AppText.sans(
                          color: connected
                              ? const Color(0xFF7CD492)
                              : AppColors.text3,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            style: AppText.sans(color: AppColors.text, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'OAuth Client ID (...apps.googleusercontent.com)',
              hintStyle:
                  AppText.sans(color: AppColors.text3, fontSize: 11),
              filled: true,
              fillColor: AppColors.bg3,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _miniBtn(
              label: _saving ? '…' : 'Enregistrer',
              icon: Icons.save_outlined,
              onTap: _saving ? null : _saveClientId,
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: DriveBackupService.isConfigured,
              builder: (_, configured, __) {
                return ValueListenableBuilder<bool>(
                  valueListenable: DriveBackupService.isConnected,
                  builder: (_, connected, __) {
                    if (connected) {
                      return _miniBtn(
                        label: 'Déconnecter',
                        icon: Icons.logout,
                        onTap: _disconnect,
                      );
                    }
                    return _miniBtn(
                      label: _connecting ? '…' : 'Connecter',
                      icon: Icons.login,
                      primary: true,
                      onTap: (configured && !_connecting) ? _connect : null,
                    );
                  },
                );
              },
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _showHelp = !_showHelp),
              child: Row(
                children: [
                  Icon(_showHelp
                      ? Icons.help
                      : Icons.help_outline,
                      size: 14, color: AppColors.text3),
                  const SizedBox(width: 3),
                  Text('Aide',
                      style: AppText.sans(
                          color: AppColors.text3, fontSize: 11)),
                ],
              ),
            ),
          ]),
          if (_showHelp) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Setup Google Drive (5 min)',
                      style: AppText.sans(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  _helpStep('1.',
                      'Va sur console.cloud.google.com → APIs & Services → Library → cherche "Google Drive API" → Enable'),
                  _helpStep('2.',
                      'Va dans OAuth consent screen → choisis "External" → remplis nom + email → ajoute toi-même comme test user'),
                  _helpStep('3.',
                      'Va dans Credentials → Create Credentials → OAuth Client ID → Type: Web application'),
                  _helpStep(
                      '4.',
                      'Authorized JavaScript origins : https://cave-vin-jo.web.app et http://localhost'),
                  _helpStep('5.',
                      'Copie le Client ID (xxx.apps.googleusercontent.com) et colle-le ici'),
                  _helpStep('6.',
                      'Enregistre, recharge la page (l\'init du SDK Google se fait au démarrage), puis clique Connecter'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _helpStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 16,
            child: Text(num,
                style: AppText.sans(
                    color: AppColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(text,
                style: AppText.sans(
                    color: AppColors.text2, fontSize: 11, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
    bool primary = false,
  }) {
    final disabled = onTap == null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: disabled
              ? AppColors.bg3
              : primary
                  ? AppColors.gold.withValues(alpha: 0.15)
                  : AppColors.bg3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: disabled
                ? AppColors.border2
                : primary
                    ? AppColors.gold
                    : AppColors.border,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 12,
              color: disabled
                  ? AppColors.text3
                  : primary
                      ? AppColors.gold
                      : AppColors.text2),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.sans(
              color: disabled
                  ? AppColors.text3
                  : primary
                      ? AppColors.gold
                      : AppColors.text2,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HistoryEntry>>(
      stream: HistoryService.recent(limit: 100),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }
        final entries = snap.data!;
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Aucune action récente.',
              style: AppText.sans(color: AppColors.text3, fontSize: 12),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              _HistoryRow(entry: entries[i]),
              if (i < entries.length - 1)
                Container(height: 1, color: AppColors.border),
            ],
          ],
        );
      },
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final HistoryEntry entry;
  const _HistoryRow({required this.entry});

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _undoing = false;

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    if (diff == 0) return "Aujourd'hui · $hh:$mm";
    if (diff == 1) return 'Hier · $hh:$mm';
    if (diff < 7) return 'Il y a $diff j · $hh:$mm';
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year} · $hh:$mm';
  }

  IconData _iconFor(HistoryActionType type) {
    switch (type) {
      case HistoryActionType.bottleDeleted:
        return Icons.delete_outline;
      case HistoryActionType.bottleDrunk:
        return Icons.local_bar_outlined;
      case HistoryActionType.wineDeleted:
        return Icons.wine_bar_outlined;
    }
  }

  Color _colorFor(HistoryActionType type) {
    switch (type) {
      case HistoryActionType.bottleDeleted:
      case HistoryActionType.wineDeleted:
        return const Color(0xFFE07060);
      case HistoryActionType.bottleDrunk:
        return AppColors.gold2;
    }
  }

  Future<void> _undo() async {
    setState(() => _undoing = true);
    final err = await HistoryService.undo(widget.entry);
    if (!mounted) return;
    setState(() => _undoing = false);
    final msg = err == null
        ? 'Action annulée'
        : 'Impossible : $err';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: err == null
            ? AppColors.gold
            : const Color(0xFFB23A48),
        content: Text(
          msg,
          style: AppText.sans(
            color: err == null
                ? const Color(0xFF1A1408)
                : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final color = _colorFor(e.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(e.type), size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      e.type.label,
                      style: AppText.sans(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(e.timestamp),
                      style: AppText.sans(color: AppColors.text3, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  e.wineLabel,
                  style: AppText.serif(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (e.bottleLocation != null && e.bottleLocation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      e.bottleLocation!,
                      style: AppText.sans(color: AppColors.text3, fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (e.undone)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Annulé',
                style: AppText.sans(color: AppColors.text3, fontSize: 11),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _undoing ? null : _undo,
              icon: _undoing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1A1408),
                      ),
                    )
                  : const Icon(Icons.undo, size: 16),
              label: Text(
                'Annuler',
                style: AppText.sans(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF1A1408),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SecurityContent extends StatefulWidget {
  const _SecurityContent();

  @override
  State<_SecurityContent> createState() => _SecurityContentState();
}

class _SecurityContentState extends State<_SecurityContent> {
  bool? _supported;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _checkSupport();
  }

  Future<void> _checkSupport() async {
    final ok = await BiometricService.isSupported();
    if (!mounted) return;
    setState(() => _supported = ok);
  }

  Future<void> _onChange(bool value) async {
    setState(() => _busy = true);
    if (value) {
      final auth = await BiometricService.authenticate(
        reason: 'Active le verrouillage biométrique',
      );
      if (auth) {
        await BiometricService.setEnabled(true);
      }
    } else {
      await BiometricService.setEnabled(false);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_supported == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
      );
    }
    if (_supported == false) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 18, color: AppColors.text3),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Cet appareil ne prend pas en charge la biométrie '
                '(Face ID / empreinte). Le verrouillage est désactivé.',
                style: AppText.sans(color: AppColors.text2, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: BiometricService.enabled,
      builder: (context, enabled, _) {
        return _ToggleRow(
          label: 'Verrouiller l\'app au démarrage',
          subtitle:
              'Demande Face ID ou ton empreinte avant d\'afficher la cave.',
          value: enabled,
          onChanged: _busy ? (_) {} : _onChange,
        );
      },
    );
  }
}

class _AccountContent extends StatefulWidget {
  const _AccountContent();

  @override
  State<_AccountContent> createState() => _AccountContentState();
}

class _AccountContentState extends State<_AccountContent> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border2),
        ),
        title: Text(
          'Se déconnecter ?',
          style: AppText.serif(color: AppColors.gold2, fontSize: 18),
        ),
        content: Text(
          'Tu devras te reconnecter avec Google pour retrouver ta cave. '
          'Les données restent dans Firebase.',
          style: AppText.sans(color: AppColors.text2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: AppText.sans(color: AppColors.text2, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Se déconnecter',
              style: AppText.sans(
                color: const Color(0xFFE07060),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _signingOut = true);
    try {
      await AuthService.signOut();
    } catch (_) {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '—';
    final name = user?.displayName ?? '';
    final photoUrl = user?.photoURL;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.bg2,
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? const Icon(Icons.person,
                        color: AppColors.text3, size: 22)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        style: AppText.serif(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      email,
                      style: AppText.sans(
                        color: AppColors.text3,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: _signingOut ? null : _signOut,
            icon: _signingOut
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.logout, size: 16),
            label: Text(
              'Se déconnecter',
              style:
                  AppText.sans(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB23A48),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
