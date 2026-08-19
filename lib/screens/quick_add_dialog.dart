import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/bottle.dart';
import '../models/wine.dart';
import '../services/cave_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/platform_image.dart' as platform_img;
import '../dialogs/photo_crop_dialog.dart';
import 'slot_picker.dart';

/// Entrée rapide : photo + quantité + emplacements, sans lancer l'IA.
///
/// Les bouteilles partent tout de suite en cave, à leur place, marquées
/// « à identifier ». L'analyse IA se lance plus tard, en lot, depuis le
/// bandeau de la page Ma Cave.
Future<void> showQuickAddDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (_) => const QuickAddDialog(),
  );
}

class QuickAddDialog extends StatefulWidget {
  const QuickAddDialog({super.key});

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  final _picker = ImagePicker();

  Uint8List? _photoBytes;
  String? _photoFileName;
  String? _photoBlobUrl;
  BottleFormat _format = BottleFormat.ml750;
  int _quantity = 1;
  final List<SlotSelection?> _slots = [null];
  final _vintage = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();

  bool _saving = false;
  String? _error;
  int _addedCount = 0;

  /// Sur web, l'apercu passe par une URL blob (comme la fenetre d'ajout
  /// complete) : bien plus leger que de decoder les octets a chaque redessin.
  void _updateBlobUrl(Uint8List? bytes) {
    platform_img.revokeBlobUrl(_photoBlobUrl);
    _photoBlobUrl = bytes == null ? null : platform_img.createBlobUrl(bytes);
  }

  @override
  void dispose() {
    platform_img.revokeBlobUrl(_photoBlobUrl);
    _vintage.dispose();
    _price.dispose();
    _note.dispose();
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
    if (result != null) setState(() => _slots[index] = result);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null) return;
      final raw = await file.readAsBytes();
      if (raw.isEmpty) {
        setState(() => _error = 'La photo est vide.');
        return;
      }
      if (!mounted) return;
      final cropped = await showPhotoCropDialog(context, raw);
      if (cropped == null || !mounted) return;
      _updateBlobUrl(cropped);
      setState(() {
        _photoBytes = cropped;
        _photoFileName = file.name;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Impossible de charger la photo : $e');
    }
  }

  /// Remet le formulaire à zéro pour enchaîner la bouteille suivante, en
  /// gardant ce qui se répète d'une bouteille à l'autre (format).
  void _resetForNext() {
    _updateBlobUrl(null);
    setState(() {
      _photoBytes = null;
      _photoFileName = null;
      _quantity = 1;
      _slots
        ..clear()
        ..add(null);
      _vintage.clear();
      _price.clear();
      _note.clear();
      _error = null;
    });
  }

  Future<bool> _save() async {
    if (_photoBytes == null && _note.text.trim().isEmpty) {
      setState(() => _error =
          'Prends une photo de l\'étiquette (ou écris une note pour te '
          'souvenir de quelle bouteille il s\'agit).');
      return false;
    }

    final keys = <String>{};
    for (final s in _slots) {
      if (s == null) continue;
      if (!keys.add(s.slotKey)) {
        setState(() =>
            _error = 'Deux bouteilles ne peuvent pas partager une case.');
        return false;
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
          return false;
        }
      }

      String? photoUrl;
      String? thumbUrl;
      if (_photoBytes != null) {
        final urls = await StorageService.uploadWinePhoto(
          bytes: _photoBytes!,
          fileName: _photoFileName ?? 'wine.jpg',
        );
        photoUrl = urls.photoUrl;
        thumbUrl = urls.thumbUrl;
      }

      final now = DateTime.now();
      final wine = Wine(
        id: '',
        // Pas de nom : c'est justement ce que l'IA ira chercher. La note
        // sert d'aide-memoire en attendant.
        name: '',
        // La note va dans quickNote et PAS dans wineDescription : sinon elle
        // occuperait la place de la description que l'IA va chercher.
        quickNote: _note.text.trim(),
        vintage: int.tryParse(_vintage.text),
        photoUrl: photoUrl,
        thumbUrl: thumbUrl,
        createdAt: now,
        aiPending: true,
      );

      final price = double.tryParse(_price.text.replaceAll(',', '.'));
      final bottles = _slots
          .map((s) => Bottle(
                id: '',
                wineId: '',
                location: s?.label ?? '',
                cellarId: s?.cellarId,
                slotCol: s?.col,
                slotRow: s?.row,
                format: _format,
                purchasePrice: price,
                createdAt: now,
              ))
          .toList();

      await CaveService.addWineWithBottles(wine: wine, bottles: bottles);
      _addedCount += _quantity;
      if (mounted) setState(() => _saving = false);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Erreur : $e';
        });
      }
      return false;
    }
  }

  Future<void> _saveAndNext() async {
    if (await _save() && mounted) _resetForNext();
  }

  Future<void> _saveAndClose() async {
    if (!await _save()) return;
    if (!mounted) return;
    final n = _addedCount;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.gold,
        duration: const Duration(seconds: 5),
        content: Text(
          '$n bouteille${n > 1 ? 's' : ''} en cave, à identifier. '
          'Lance l\'analyse IA quand tu as fini de tout rentrer.',
          style: const TextStyle(color: Color(0xFF1A1408)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final w = screenW < 720 ? screenW - 24 : 640.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: w,
        constraints: BoxConstraints(maxHeight: screenH * 0.92),
        decoration: BoxDecoration(
          color: AppColors.bg2,
          border: Border.all(color: AppColors.border2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: _body(),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Entrée rapide',
                  style: AppText.serif(color: AppColors.gold2, fontSize: 20),
                ),
                Text(
                  'Photo, quantité, emplacement. L\'IA passera plus tard.',
                  style: AppText.sans(color: AppColors.text3, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_addedCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_addedCount rentrée${_addedCount > 1 ? 's' : ''}',
                style: AppText.sans(
                  color: AppColors.gold2,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.text3, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _photoZone(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: _quantityField()),
            const SizedBox(width: 12),
            Expanded(child: _formatField()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _textField('Millésime (si tu le vois)', _vintage,
                  number: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _textField('Prix achat (\$)', _price, number: true),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _textField('Note (facultatif)', _note,
            hint: 'Ex : caisse de la SAQ, cadeau de Marc…'),
        const SizedBox(height: 18),
        _slotsZone(),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFB23A48).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: const Color(0xFFB23A48).withValues(alpha: 0.5)),
            ),
            child: Text(
              _error!,
              style: AppText.sans(color: const Color(0xFFE9A0AA), fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }

  Widget _photoZone() {
    final has = _photoBytes != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 108,
          height: 148,
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: has ? AppColors.gold : AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: has
              ? (kIsWeb && _photoBlobUrl != null
                  ? platform_img.buildBlobPreview(_photoBlobUrl!)
                  : Image.memory(_photoBytes!, fit: BoxFit.cover))
              : const Icon(Icons.wine_bar_outlined,
                  color: AppColors.text3, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Photo de l\'étiquette',
                style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'C\'est elle que l\'IA lira plus tard pour remplir la fiche.',
                style: AppText.sans(color: AppColors.text3, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _smallButton(
                    icon: Icons.photo_camera_outlined,
                    label: has ? 'Reprendre' : 'Prendre',
                    onTap: () => _pickPhoto(ImageSource.camera),
                  ),
                  _smallButton(
                    icon: Icons.image_outlined,
                    label: 'Importer',
                    onTap: () => _pickPhoto(ImageSource.gallery),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quantityField() {
    return _labeled(
      'Nombre de bouteilles',
      Row(
        children: [
          _stepButton(Icons.remove,
              onTap: _quantity > 1 ? () => _syncSlots(_quantity - 1) : null),
          Expanded(
            child: Text(
              '$_quantity',
              textAlign: TextAlign.center,
              style: AppText.serif(color: AppColors.gold2, fontSize: 20),
            ),
          ),
          _stepButton(Icons.add,
              onTap: _quantity < 60 ? () => _syncSlots(_quantity + 1) : null),
        ],
      ),
    );
  }

  Widget _formatField() {
    return _labeled(
      'Format',
      DropdownButtonHideUnderline(
        child: DropdownButton<BottleFormat>(
          value: _format,
          isExpanded: true,
          dropdownColor: AppColors.bg3,
          style: AppText.sans(color: AppColors.text, fontSize: 13),
          items: BottleFormat.values
              .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
              .toList(),
          onChanged: (v) => setState(() => _format = v ?? _format),
        ),
      ),
    );
  }

  Widget _slotsZone() {
    return _labeled(
      'Emplacements (une case par bouteille)',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(_slots.length, (i) {
          final slot = _slots[i];
          final has = slot != null;
          return InkWell(
            onTap: () => _pickSlotFor(i),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 150,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: has ? AppColors.gold : AppColors.border),
              ),
              child: Row(
                children: [
                  Text('Bout. ${i + 1}',
                      style:
                          AppText.sans(color: AppColors.text3, fontSize: 11)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      has ? slot.label : 'Choisir…',
                      style: AppText.sans(
                        color: has ? AppColors.gold2 : AppColors.text3,
                        fontSize: 13,
                        fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (has)
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
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _saveAndNext,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.gold),
                    )
                  : const Icon(Icons.add, size: 16),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold2,
                side: const BorderSide(color: AppColors.gold),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              label: const Text('Enregistrer et suivante'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _saveAndClose,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF1A1408),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Enregistrer et fermer'),
            ),
          ),
        ],
      ),
    );
  }

  // ---- petits blocs d'interface ----

  Widget _labeled(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.sans(color: AppColors.text3, fontSize: 11)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _textField(String label, TextEditingController c,
      {bool number = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.sans(color: AppColors.text3, fontSize: 11)),
        const SizedBox(height: 6),
        TextField(
          controller: c,
          keyboardType: number ? TextInputType.number : TextInputType.text,
          style: AppText.sans(color: AppColors.text, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppText.sans(color: AppColors.text3, fontSize: 12),
            filled: true,
            fillColor: AppColors.bg3,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: _saving ? null : onTap,
      icon: Icon(icon, size: 15),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text2,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      label: Text(label, style: AppText.sans(fontSize: 12)),
    );
  }

  Widget _stepButton(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon,
            size: 18,
            color: onTap == null ? AppColors.border2 : AppColors.gold2),
      ),
    );
  }
}
