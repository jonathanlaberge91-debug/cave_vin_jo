import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/bottle.dart';
import '../services/cave_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

Future<bool> showDrinkBottleDialog(BuildContext context, Bottle bottle) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _DrinkBottleDialog(bottle: bottle),
  );
  return result ?? false;
}

class _DrinkBottleDialog extends StatefulWidget {
  final Bottle bottle;
  const _DrinkBottleDialog({required this.bottle});

  @override
  State<_DrinkBottleDialog> createState() => _DrinkBottleDialogState();
}

class _DrinkBottleDialogState extends State<_DrinkBottleDialog> {
  late DateTime _date;
  late final TextEditingController _rating;
  late final TextEditingController _location;
  late final TextEditingController _note;
  bool _saving = false;

  bool get _editing => widget.bottle.status == BottleStatus.drunk;

  @override
  void initState() {
    super.initState();
    final b = widget.bottle;
    _date = b.drunkAt ?? DateTime.now();
    _rating = TextEditingController(text: b.drunkRating?.toString() ?? '');
    _location = TextEditingController(text: b.drunkLocation ?? '');
    _note = TextEditingController(text: b.drunkNote ?? '');
  }

  @override
  void dispose() {
    _rating.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (_editing) {
        await CaveService.updateBottle(widget.bottle.id, {
          'drunkAt': Timestamp.fromDate(_date),
          'drunkRating': int.tryParse(_rating.text),
          'drunkNote': _note.text.trim().isNotEmpty ? _note.text.trim() : null,
          'drunkLocation': _location.text.trim().isNotEmpty ? _location.text.trim() : null,
        });
      } else {
        await CaveService.markBottleDrunk(
          bottleId: widget.bottle.id,
          drunkAt: _date,
          rating: int.tryParse(_rating.text),
          note: _note.text.trim().isNotEmpty ? _note.text.trim() : null,
          location: _location.text.trim().isNotEmpty ? _location.text.trim() : null,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border2),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('DATE DE DÉGUSTATION'),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bg3,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.text3),
                            const SizedBox(width: 8),
                            Text(
                              '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                              style: AppText.sans(color: AppColors.text, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('NOTE / 100'),
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _rating,
                            keyboardType: TextInputType.number,
                            style: AppText.sans(color: AppColors.text, fontSize: 13),
                            decoration: _inputDecoration(hint: '0-100'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('/ 100', style: AppText.sans(color: AppColors.text3, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('LIEU DE CONSOMMATION'),
                    TextFormField(
                      controller: _location,
                      style: AppText.sans(color: AppColors.text, fontSize: 13),
                      decoration: _inputDecoration(hint: 'Restaurant, maison, chez des amis…'),
                    ),
                    const SizedBox(height: 16),
                    _sectionLabel('NOTES'),
                    TextFormField(
                      controller: _note,
                      style: AppText.sans(color: AppColors.text, fontSize: 13),
                      maxLines: 3,
                      decoration: _inputDecoration(hint: 'Impressions, accords, occasion…'),
                    ),
                  ],
                ),
              ),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            _editing ? 'Modifier la dégustation' : 'Marquer comme bue',
            style: AppText.serif(
              color: AppColors.gold2,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.text3),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text('Annuler', style: AppText.sans(color: AppColors.text2)),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF1A1408),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1408)),
                  )
                : Text(
                    'Valider',
                    style: AppText.sans(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppText.sans(
          color: AppColors.text3,
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.bg3,
        hintText: hint,
        hintStyle: AppText.sans(color: AppColors.text3, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      );
}
