import 'package:flutter/material.dart';
import '../services/ai_cross_check.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

Future<List<FieldDisagreement>?> showDisagreementDialog(
  BuildContext context,
  List<FieldDisagreement> disagreements,
) {
  return showDialog<List<FieldDisagreement>>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (_) => _DisagreementDialog(disagreements: disagreements),
  );
}

class _DisagreementDialog extends StatefulWidget {
  final List<FieldDisagreement> disagreements;
  const _DisagreementDialog({required this.disagreements});

  @override
  State<_DisagreementDialog> createState() => _DisagreementDialogState();
}

class _DisagreementDialogState extends State<_DisagreementDialog> {
  late final List<FieldDisagreement> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.disagreements
        .map((d) => FieldDisagreement(
              fieldKey: d.fieldKey,
              label: d.label,
              values: Map<AiSource, String>.from(d.values),
              chosen: d.chosen,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final modalW = w < 720 ? w - 32 : 660.0;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: modalW,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.compare_arrows,
                      color: AppColors.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Désaccords IA',
                          style: AppText.serif(
                            color: AppColors.gold2,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_items.length} champ${_items.length > 1 ? 's' : ''} avec divergences. Gemini a pré-sélectionné la valeur la plus fiable selon recherche web. Vérifie et applique.',
                          style: AppText.sans(
                              color: AppColors.text3, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  children: [
                    for (final d in _items) ...[
                      _DisagreementRow(
                        item: d,
                        onChanged: (src) =>
                            setState(() => d.chosen = src),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(
                      'Annuler',
                      style: AppText.sans(
                          color: AppColors.text3, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_items),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF1A1408),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                    ),
                    child: Text(
                      'Appliquer',
                      style: AppText.sans(
                        color: const Color(0xFF1A1408),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisagreementRow extends StatelessWidget {
  final FieldDisagreement item;
  final void Function(AiSource) onChanged;

  const _DisagreementRow({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label.toUpperCase(),
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in item.values.entries) ...[
            _Choice(
              label: entry.key.label,
              value: entry.value,
              selected: item.chosen == entry.key,
              onTap: () => onChanged(entry.key),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _Choice({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.1)
              : AppColors.bg2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.text3,
                  width: 1.5,
                ),
                color: selected ? AppColors.gold : Colors.transparent,
              ),
              child: selected
                  ? const Icon(Icons.check,
                      size: 10, color: Color(0xFF1A1408))
                  : null,
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 76,
              child: Text(
                label,
                style: AppText.sans(
                  color: selected ? AppColors.gold : AppColors.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '— vide —' : value,
                style: AppText.sans(
                  color: value.isEmpty
                      ? AppColors.text3
                      : AppColors.text,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
