import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../services/cave_preferences_service.dart';
import '../services/cave_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../screens/slot_picker.dart';

Future<void> showAddBottles(
  BuildContext context,
  Wine wine, {
  Set<BottleFormat> existingFormats = const {},
  BottleFormat initialFormat = BottleFormat.ml750,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => AddBottlesDialog(
      wine: wine,
      existingFormats: existingFormats,
      initialFormat: initialFormat,
    ),
  );
}

class AddBottlesDialog extends StatefulWidget {
  final Wine wine;
  final Set<BottleFormat> existingFormats;
  final BottleFormat initialFormat;
  const AddBottlesDialog({
    super.key,
    required this.wine,
    this.existingFormats = const {},
    this.initialFormat = BottleFormat.ml750,
  });

  @override
  State<AddBottlesDialog> createState() => AddBottlesDialogState();
}

class AddBottlesDialogState extends State<AddBottlesDialog> {
  late BottleFormat _format;
  int _quantity = 1;
  final _price = TextEditingController();
  final _marketValue = TextEditingController();
  final _purchaseYear = TextEditingController();
  String? _source;
  final List<SlotSelection?> _slots = [null];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _format = widget.initialFormat;
  }

  @override
  void dispose() {
    _price.dispose();
    _marketValue.dispose();
    _purchaseYear.dispose();
    super.dispose();
  }

  void _syncSlots(int qty) {
    setState(() {
      _quantity = qty;
      while (_slots.length < qty) {
        _slots.add(null);
      }
      while (_slots.length > qty) {
        _slots.removeLast();
      }
    });
  }

  Future<void> _pickSlotFor(int index) async {
    final reserved = <String>{};
    for (var i = 0; i < _slots.length; i++) {
      if (i == index) continue;
      final s = _slots[i];
      if (s != null) reserved.add(s.slotKey);
    }
    final result = await pickSlot(
      context,
      reservedKeys: reserved,
      initial: _slots[index],
    );
    if (result != null) {
      setState(() => _slots[index] = result);
    }
  }

  Future<void> _save() async {
    final keys = <String>{};
    for (final s in _slots) {
      if (s == null) continue;
      if (!keys.add(s.slotKey)) {
        setState(() =>
            _error = 'Deux bouteilles ne peuvent pas partager une case.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      for (final s in _slots) {
        if (s == null) continue;
        final taken = await CaveService.isSlotTaken(
          cellarId: s.cellarId,
          slotCol: s.col,
          slotRow: s.row,
        );
        if (taken) {
          setState(() {
            _saving = false;
            _error = 'La case ${s.label} est déjà occupée.';
          });
          return;
        }
      }

      final price = double.tryParse(_price.text.replaceAll(',', '.'));
      final market750 = double.tryParse(_marketValue.text.replaceAll(',', '.'));
      final market = market750 != null
          ? (market750 * _format.marketMultiplier).roundToDouble()
          : null;
      final year = int.tryParse(_purchaseYear.text);
      final now = DateTime.now();

      final bottles = _slots
          .map((s) => Bottle(
                id: '',
                wineId: widget.wine.id,
                location: s?.label ?? '',
                cellarId: s?.cellarId,
                slotCol: s?.col,
                slotRow: s?.row,
                format: _format,
                purchasePrice: price,
                marketValue: market,
                purchaseYear: year,
                source: _source,
                createdAt: now,
              ))
          .toList();

      final isNewFormat = widget.existingFormats.isNotEmpty &&
          !widget.existingFormats.contains(_format);
      if (isNewFormat) {
        await CaveService.cloneWineWithBottles(
          sourceWine: widget.wine,
          bottles: bottles,
        );
      } else {
        await CaveService.addBottlesToWine(
          wineId: widget.wine.id,
          bottles: bottles,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.gold,
          content: Text(
            '$_quantity bouteille${_quantity > 1 ? 's' : ''} ajoutée${_quantity > 1 ? 's' : ''}',
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
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildContent(),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajouter des bouteilles',
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.wine.name,
                  style: AppText.sans(
                    color: AppColors.text3,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.text3),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
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
            child: Text('Annuler',
                style: AppText.sans(color: AppColors.text2)),
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
                    'Ajouter',
                    style: AppText.sans(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection('Format & Quantité'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildLabeled(
                'Format',
                _buildDropdownContainer(
                  DropdownButton<BottleFormat>(
                    value: _format,
                    isExpanded: true,
                    dropdownColor: AppColors.bg2,
                    style:
                        AppText.sans(color: AppColors.text, fontSize: 13),
                    items: BottleFormat.values
                        .map((f) =>
                            DropdownMenuItem(value: f, child: Text(f.label)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _format = v ?? BottleFormat.ml750),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabeled(
                'Quantité',
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      _buildQtyBtn(Icons.remove, () {
                        if (_quantity > 1) _syncSlots(_quantity - 1);
                      }),
                      Expanded(
                        child: Center(
                          child: Text(
                            '$_quantity',
                            style: AppText.serif(
                              color: AppColors.gold2,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      _buildQtyBtn(
                          Icons.add, () => _syncSlots(_quantity + 1)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection('Achat'),
        Row(
          children: [
            Expanded(
              child: _buildLabeled(
                'Prix achat (\$)',
                TextField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  style: AppText.sans(color: AppColors.text, fontSize: 13),
                  decoration: _buildDecoration(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabeled(
                'Valeur marché 750mL (\$)',
                TextField(
                  controller: _marketValue,
                  keyboardType: TextInputType.number,
                  style: AppText.sans(color: AppColors.text, fontSize: 13),
                  decoration: _buildDecoration(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildLabeled(
                'Année achat',
                TextField(
                  controller: _purchaseYear,
                  keyboardType: TextInputType.number,
                  style: AppText.sans(color: AppColors.text, fontSize: 13),
                  decoration: _buildDecoration(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLabeled(
                'Provenance',
                ValueListenableBuilder<List<String>>(
                  valueListenable: CavePreferencesService.customSources,
                  builder: (context, _, __) {
                    final labels =
                        CavePreferencesService.allSourceLabels;
                    final hasCurrent =
                        _source == null || labels.contains(_source);
                    return _buildDropdownContainer(
                      DropdownButton<String?>(
                        value: hasCurrent ? _source : null,
                        isExpanded: true,
                        dropdownColor: AppColors.bg2,
                        hint: Text('Choisir…',
                            style: AppText.sans(
                                color: AppColors.text3, fontSize: 13)),
                        style: AppText.sans(
                            color: AppColors.text, fontSize: 13),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('—',
                                style: AppText.sans(
                                    color: AppColors.text3, fontSize: 13)),
                          ),
                          ...labels.map((s) =>
                              DropdownMenuItem(value: s, child: Text(s))),
                        ],
                        onChanged: (v) => setState(() => _source = v),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection('Emplacements'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_slots.length, (i) {
            final slot = _slots[i];
            final hasSlot = slot != null;
            return InkWell(
              onTap: () => _pickSlotFor(i),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 150,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasSlot ? AppColors.gold : AppColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Bout. ${i + 1}',
                      style: AppText.sans(
                          color: AppColors.text3, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasSlot ? slot.label : 'Choisir…',
                        style: AppText.sans(
                          color:
                              hasSlot ? AppColors.gold2 : AppColors.text3,
                          fontSize: 13,
                          fontWeight:
                              hasSlot ? FontWeight.w600 : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasSlot)
                      InkWell(
                        onTap: () => setState(() => _slots[i] = null),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close,
                              size: 14, color: AppColors.text3),
                        ),
                      )
                    else
                      const Icon(Icons.grid_view,
                          size: 14, color: AppColors.text3),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Laisse vide pour mettre la bouteille dans la zone « À placer ».',
          style: AppText.sans(color: AppColors.text3, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSection(String title) {
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

  Widget _buildLabeled(String label, Widget child) {
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

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 38,
        height: 40,
        child: Icon(icon, color: AppColors.gold2, size: 18),
      ),
    );
  }

  InputDecoration _buildDecoration({String? hint}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.bg3,
        hintText: hint,
        hintStyle: AppText.sans(color: AppColors.text3, fontSize: 12),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
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

  Widget _buildDropdownContainer(Widget child) {
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
