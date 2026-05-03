import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bottle.dart';
import '../services/cave_service.dart';
import '../services/cellar_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/date_format.dart';

Future<void> showEditBottle(BuildContext context, Bottle bottle) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => EditBottleDialog(bottle: bottle),
  );
}

class EditBottleDialog extends StatefulWidget {
  final Bottle bottle;
  const EditBottleDialog({super.key, required this.bottle});

  @override
  State<EditBottleDialog> createState() => EditBottleDialogState();
}

class EditBottleDialogState extends State<EditBottleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _location;
  late final TextEditingController _price;
  late final TextEditingController _marketValue;
  late final TextEditingController _purchaseYear;
  late final TextEditingController _giftFrom;
  late final TextEditingController _giftOccasion;
  late BottleFormat _format;
  late BottleSource? _source;
  late bool _isGift;
  DateTime? _giftDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.bottle;
    _location = TextEditingController(text: b.location);
    _price = TextEditingController(
      text: b.purchasePrice != null ? b.purchasePrice!.toStringAsFixed(2) : '',
    );
    _marketValue = TextEditingController(
      text: b.marketValue != null ? b.marketValue!.toStringAsFixed(2) : '',
    );
    _purchaseYear =
        TextEditingController(text: b.purchaseYear?.toString() ?? '');
    _giftFrom = TextEditingController(text: b.giftFrom);
    _giftOccasion = TextEditingController(text: b.giftOccasion);
    _format = b.format;
    _source = b.source;
    _isGift = b.isGift;
    _giftDate = b.giftDate;
  }

  @override
  void dispose() {
    _location.dispose();
    _price.dispose();
    _marketValue.dispose();
    _purchaseYear.dispose();
    _giftFrom.dispose();
    _giftOccasion.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = _location.text.trim().toUpperCase();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? cellarId;
      int? slotCol;
      int? slotRow;

      if (loc.isNotEmpty) {
        final parsed = parseSlotLabel(loc);
        if (parsed != null) {
          final cellar =
              await CellarService.findByNumber(parsed.cellarNumber);
          if (cellar == null) {
            setState(() {
              _saving = false;
              _error =
                  'Le cellier N°${parsed.cellarNumber} n\'existe pas.';
            });
            return;
          }
          if (parsed.colIndex < 0 ||
              parsed.colIndex >= cellar.cols ||
              parsed.rowIndex < 0 ||
              parsed.rowIndex >= cellar.rows) {
            setState(() {
              _saving = false;
              _error =
                  'La case $loc n\'existe pas (cellier ${cellar.cols} × ${cellar.rows}).';
            });
            return;
          }
          final taken = await CaveService.isSlotTaken(
            cellarId: cellar.id,
            slotCol: parsed.colIndex,
            slotRow: parsed.rowIndex,
            exceptBottleId: widget.bottle.id,
          );
          if (taken) {
            setState(() {
              _saving = false;
              _error = 'La case $loc est déjà occupée.';
            });
            return;
          }
          cellarId = cellar.id;
          slotCol = parsed.colIndex;
          slotRow = parsed.rowIndex;
        }
      }

      if (cellarId == null &&
          loc.isNotEmpty &&
          loc != widget.bottle.location &&
          await CaveService.isLocationTaken(
            loc,
            exceptBottleId: widget.bottle.id,
          )) {
        setState(() {
          _saving = false;
          _error = 'L\'emplacement « $loc » est déjà occupé.';
        });
        return;
      }

      await CaveService.updateBottle(widget.bottle.id, {
        'location': loc,
        'cellarId': cellarId,
        'slotCol': slotCol,
        'slotRow': slotRow,
        'format': _format.label,
        'purchasePrice':
            double.tryParse(_price.text.replaceAll(',', '.')),
        'marketValue':
            double.tryParse(_marketValue.text.replaceAll(',', '.')),
        'purchaseYear': int.tryParse(_purchaseYear.text),
        'source': _source?.label,
        'isGift': _isGift,
        'giftFrom': _isGift ? _giftFrom.text.trim() : '',
        'giftOccasion': _isGift ? _giftOccasion.text.trim() : '',
        'giftDate': _isGift && _giftDate != null
            ? Timestamp.fromDate(_giftDate!)
            : null,
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.gold,
          content: Text(
            'Bouteille mise à jour',
            style: AppText.sans(
              color: const Color(0xFF1A1408),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Erreur : $e';
      });
    }
  }

  Future<void> _pickGiftDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _giftDate ?? now,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _giftDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxWidth = size.width > 720 ? 660.0 : size.width - 32;
    final maxHeight = size.height * 0.9;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 40,
                offset: Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _editHeader(),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _editContent(),
                  ),
                ),
              ),
              _editFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            'Modifier la bouteille',
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
            hoverColor: AppColors.bg3,
          ),
        ],
      ),
    );
  }

  Widget _editFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_error != null)
            Expanded(
              child: Text(
                _error!,
                style: AppText.sans(
                  color: const Color(0xFFE07060),
                  fontSize: 12,
                ),
              ),
            )
          else
            const Spacer(),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1A1408),
                    ),
                  )
                : Text(
                    'Enregistrer',
                    style:
                        AppText.sans(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _editContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _editSection('Emplacement & Format'),
        _grid2([
          _labeledField(
            'Emplacement',
            TextFormField(
              controller: _location,
              style: AppText.sans(color: AppColors.text, fontSize: 13),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                TextInputFormatter.withFunction((oldV, newV) =>
                    newV.copyWith(text: newV.text.toUpperCase())),
              ],
              decoration: _editDecoration(hint: 'Ex: C1-A3'),
            ),
          ),
          _labeledField(
            'Format',
            _editDropdownContainer(
              DropdownButton<BottleFormat>(
                value: _format,
                isExpanded: true,
                dropdownColor: AppColors.bg2,
                style: AppText.sans(color: AppColors.text, fontSize: 13),
                items: BottleFormat.values
                    .map((f) =>
                        DropdownMenuItem(value: f, child: Text(f.label)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _format = v ?? BottleFormat.ml750),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _editSection('Achat'),
        _grid2([
          _labeledField(
            'Prix achat (\$)',
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              style: AppText.sans(color: AppColors.text, fontSize: 13),
              decoration: _editDecoration(),
            ),
          ),
          _labeledField(
            'Valeur marché (\$)',
            TextFormField(
              controller: _marketValue,
              keyboardType: TextInputType.number,
              style: AppText.sans(color: AppColors.text, fontSize: 13),
              decoration: _editDecoration(),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        _grid2([
          _labeledField(
            'Année achat',
            TextFormField(
              controller: _purchaseYear,
              keyboardType: TextInputType.number,
              style: AppText.sans(color: AppColors.text, fontSize: 13),
              decoration: _editDecoration(),
            ),
          ),
          _labeledField(
            'Provenance',
            _editDropdownContainer(
              DropdownButton<BottleSource?>(
                value: _source,
                isExpanded: true,
                dropdownColor: AppColors.bg2,
                hint: Text('Choisir…',
                    style:
                        AppText.sans(color: AppColors.text3, fontSize: 13)),
                style: AppText.sans(color: AppColors.text, fontSize: 13),
                items: [
                  DropdownMenuItem<BottleSource?>(
                    value: null,
                    child: Text('—',
                        style: AppText.sans(
                            color: AppColors.text3, fontSize: 13)),
                  ),
                  ...BottleSource.values.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                  ),
                ],
                onChanged: (v) => setState(() => _source = v),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        _editSection('Cadeau'),
        Row(
          children: [
            Checkbox(
              value: _isGift,
              onChanged: (v) => setState(() => _isGift = v ?? false),
              activeColor: AppColors.gold,
              checkColor: const Color(0xFF1A1408),
            ),
            Text(
              'Cette bouteille est un cadeau',
              style: AppText.sans(color: AppColors.text2, fontSize: 13),
            ),
          ],
        ),
        if (_isGift) ...[
          const SizedBox(height: 10),
          _grid2([
            _labeledField(
              'De qui',
              TextFormField(
                controller: _giftFrom,
                style: AppText.sans(color: AppColors.text, fontSize: 13),
                decoration: _editDecoration(),
              ),
            ),
            _labeledField(
              'Occasion',
              TextFormField(
                controller: _giftOccasion,
                style: AppText.sans(color: AppColors.text, fontSize: 13),
                decoration:
                    _editDecoration(hint: 'Noël, anniversaire…'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _labeledField(
            'Date du cadeau',
            InkWell(
              onTap: _pickGiftDate,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.text3),
                    const SizedBox(width: 8),
                    Text(
                      _giftDate == null
                          ? 'Choisir une date'
                          : fmtDate(_giftDate!),
                      style: AppText.sans(
                        color: _giftDate == null
                            ? AppColors.text3
                            : AppColors.text,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    if (_giftDate != null)
                      InkWell(
                        onTap: () => setState(() => _giftDate = null),
                        child: const Icon(Icons.clear,
                            size: 14, color: AppColors.text3),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _editSection(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Text(
        title.toUpperCase(),
        style: AppText.sans(
          color: AppColors.text3,
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _grid2(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: children[0]),
        const SizedBox(width: 12),
        Expanded(child: children[1]),
      ],
    );
  }

  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(
            label.toUpperCase(),
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        child,
      ],
    );
  }

  InputDecoration _editDecoration({String? hint}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.bg3,
        hintText: hint,
        hintStyle: AppText.sans(color: AppColors.text3, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        border: _editBorder(AppColors.border),
        enabledBorder: _editBorder(AppColors.border),
        focusedBorder: _editBorder(AppColors.gold),
      );

  OutlineInputBorder _editBorder(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );

  Widget _editDropdownContainer(Widget child) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(child: child),
    );
  }
}
