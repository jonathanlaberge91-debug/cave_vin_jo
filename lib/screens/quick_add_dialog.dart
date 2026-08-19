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

/// Entrée rapide en chaîne : photo → nombre → placement → bouteille suivante.
///
/// Le but est de vider une caisse sans jamais s'arrêter : dès qu'une bouteille
/// est validée, l'appareil photo repart pour la suivante. L'enregistrement
/// (téléversement de la photo compris) se fait en arrière-plan pour ne pas
/// faire attendre entre deux bouteilles.
///
/// Rien n'est identifié à ce stade : les vins partent avec `aiPending`, et
/// l'analyse IA se lance plus tard, en lot, depuis le bandeau de Ma Cave.
Future<void> showQuickAddDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (_) => const QuickAddDialog(),
  );
}

enum _Step { photo, quantity, placement }

/// Une bouteille figée au moment du « suivante », en route vers la base.
class _PendingEntry {
  final Uint8List? photoBytes;
  final String? photoFileName;
  final int quantity;
  final BottleFormat format;
  final List<SlotSelection?> slots;
  final int? vintage;
  final double? price;
  final String note;

  _PendingEntry({
    required this.photoBytes,
    required this.photoFileName,
    required this.quantity,
    required this.format,
    required this.slots,
    required this.vintage,
    required this.price,
    required this.note,
  });

  String get label {
    if (note.trim().isNotEmpty) return note.trim();
    if (vintage != null) return 'Bouteille $vintage';
    return 'Bouteille sans nom';
  }
}

class QuickAddDialog extends StatefulWidget {
  const QuickAddDialog({super.key});

  @override
  State<QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<QuickAddDialog> {
  final _picker = ImagePicker();

  _Step _step = _Step.photo;

  // Bouteille en cours
  Uint8List? _photoBytes;
  String? _photoFileName;
  String? _photoBlobUrl;
  BottleFormat _format = BottleFormat.ml750;
  int _quantity = 1;
  List<SlotSelection?> _slots = [null];
  final _vintage = TextEditingController();
  final _price = TextEditingController();
  final _note = TextEditingController();
  bool _showDetails = false;

  // Suivi de la série
  int _addedBottles = 0;
  int _addedWines = 0;
  int _savingCount = 0;
  final List<String> _failures = [];
  String? _error;

  /// Cases déjà réservées par les bouteilles de cette série : comme
  /// l'enregistrement se fait en arrière-plan, la case n'est pas encore
  /// « occupée » en base quand on place la bouteille suivante.
  final Set<String> _claimedSlots = {};

  bool _autoCameraTried = false;

  /// Gardé de côté pour pouvoir signaler un échec d'enregistrement même si la
  /// fenêtre est déjà fermée (les sauvegardes tournent en arrière-plan).
  ScaffoldMessengerState? _messenger;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoCamera());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    platform_img.revokeBlobUrl(_photoBlobUrl);
    _vintage.dispose();
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Sur téléphone, l'appareil photo s'ouvre tout seul : c'est le geste
  /// attendu. Sur grand écran on laisse choisir — il n'y a souvent pas de
  /// caméra, et un sélecteur de fichiers qui surgit serait déroutant.
  bool get _isPhone => MediaQuery.of(context).size.width < 600;

  Future<void> _maybeAutoCamera() async {
    if (!mounted || _autoCameraTried) return;
    _autoCameraTried = true;
    if (_isPhone) await _pickPhoto(ImageSource.camera);
  }

  void _updateBlobUrl(Uint8List? bytes) {
    platform_img.revokeBlobUrl(_photoBlobUrl);
    _photoBlobUrl = bytes == null ? null : platform_img.createBlobUrl(bytes);
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
        // Photo prise : on enchaîne directement sur le nombre.
        _step = _Step.quantity;
      });
    } catch (e) {
      setState(() => _error = 'Impossible de charger la photo : $e');
    }
  }

  void _setQuantity(int qty) {
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
    final reserved = <String>{..._claimedSlots};
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
    if (result != null && mounted) setState(() => _slots[index] = result);
  }

  // ---------------------------------------------------------------- série

  /// Fige la bouteille en cours, lance son enregistrement en arrière-plan et
  /// repart aussitôt sur la suivante (appareil photo compris).
  /// [continueChain] à false quand on termine : on enregistre la bouteille
  /// en cours mais on ne relance PAS l'appareil photo.
  void _nextBottle({bool continueChain = true}) {
    if (_photoBytes == null && _note.text.trim().isEmpty) {
      setState(() => _error =
          'Prends une photo de l\'étiquette (ou écris une note pour '
          'reconnaître la bouteille plus tard).');
      return;
    }

    final entry = _PendingEntry(
      photoBytes: _photoBytes,
      photoFileName: _photoFileName,
      quantity: _quantity,
      format: _format,
      slots: List<SlotSelection?>.from(_slots),
      vintage: int.tryParse(_vintage.text),
      price: double.tryParse(_price.text.replaceAll(',', '.')),
      note: _note.text,
    );

    for (final s in entry.slots) {
      if (s != null) _claimedSlots.add(s.slotKey);
    }

    setState(() {
      _addedBottles += entry.quantity;
      _addedWines += 1;
      _savingCount += 1;
      // Remise à zéro pour la suivante. Le format se garde : dans une caisse,
      // c'est le même d'une bouteille à l'autre.
      _updateBlobUrl(null);
      _photoBytes = null;
      _photoFileName = null;
      _quantity = 1;
      _slots = [null];
      _vintage.clear();
      _price.clear();
      _note.clear();
      _showDetails = false;
      _error = null;
      _step = _Step.photo;
    });

    unawaited(_persist(entry));
    if (continueChain) {
      _autoCameraTried = false;
      unawaited(_maybeAutoCamera());
    }
  }

  Future<void> _persist(_PendingEntry e) async {
    try {
      String? photoUrl;
      String? thumbUrl;
      if (e.photoBytes != null) {
        final urls = await StorageService.uploadWinePhoto(
          bytes: e.photoBytes!,
          fileName: e.photoFileName ?? 'wine.jpg',
        );
        photoUrl = urls.photoUrl;
        thumbUrl = urls.thumbUrl;
      }

      final now = DateTime.now();
      final wine = Wine(
        id: '',
        // Sans nom : c'est justement ce que l'IA ira chercher.
        name: '',
        quickNote: e.note.trim(),
        vintage: e.vintage,
        photoUrl: photoUrl,
        thumbUrl: thumbUrl,
        createdAt: now,
        aiPending: true,
      );

      final bottles = e.slots
          .map((s) => Bottle(
                id: '',
                wineId: '',
                location: s?.label ?? '',
                cellarId: s?.cellarId,
                slotCol: s?.col,
                slotRow: s?.row,
                format: e.format,
                purchasePrice: e.price,
                createdAt: now,
              ))
          .toList();

      await CaveService.addWineWithBottles(wine: wine, bottles: bottles);
    } catch (err) {
      final msg = err.toString().replaceAll('Exception: ', '');
      if (mounted) {
        setState(() {
          _addedBottles -= e.quantity;
          _addedWines -= 1;
          _failures.add('${e.label} : $msg');
        });
      } else {
        // Fenêtre déjà fermée : on prévient quand même, sinon la bouteille
        // disparaîtrait sans un mot.
        _messenger?.showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFB23A48),
            duration: const Duration(seconds: 12),
            content: Text(
              'Bouteille non enregistrée (${e.label}) : $msg',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingCount -= 1);
    }
  }

  Future<void> _finish() async {
    // Bouteille en cours de saisie : on ne la perd pas.
    if (_photoBytes != null || _note.text.trim().isNotEmpty) {
      _nextBottle(continueChain: false);
    }
    final bottles = _addedBottles;
    final wines = _addedWines;
    final failures = List<String>.from(_failures);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    if (failures.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB23A48),
          duration: const Duration(seconds: 12),
          content: Text(
            '${failures.length} bouteille(s) non enregistrée(s) :\n'
            '${failures.join('\n')}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }
    if (bottles == 0) return;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.gold,
        duration: const Duration(seconds: 6),
        content: Text(
          '$bottles bouteille${bottles > 1 ? 's' : ''} en cave '
          '($wines à identifier). Lance l\'analyse IA quand tu es prêt.',
          style: const TextStyle(color: Color(0xFF1A1408)),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- affichage

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final w = screenW < 720 ? screenW - 20 : 600.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
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
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
                child: switch (_step) {
                  _Step.photo => _photoStep(),
                  _Step.quantity => _quantityStep(),
                  _Step.placement => _placementStep(),
                },
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    const titles = {
      _Step.photo: ('1 · Photo', 'Photographie l\'étiquette de la bouteille.'),
      _Step.quantity: ('2 · Nombre', 'Combien de bouteilles identiques ?'),
      _Step.placement: ('3 · Placement', 'Facultatif — tu peux passer.'),
    };
    final entry = titles[_step]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 10, 8),
      child: Row(
        children: [
          const Icon(Icons.bolt, color: AppColors.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.$1,
                    style: AppText.serif(color: AppColors.gold2, fontSize: 19)),
                Text(entry.$2,
                    style:
                        AppText.sans(color: AppColors.text3, fontSize: 11.5)),
              ],
            ),
          ),
          if (_addedBottles > 0 || _savingCount > 0) _counterChip(),
          IconButton(
            tooltip: 'Terminer',
            onPressed: _finish,
            icon: const Icon(Icons.close, color: AppColors.text3, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _counterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_savingCount > 0) ...[
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                  strokeWidth: 1.6, color: AppColors.gold2),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            '$_addedBottles rentrée${_addedBottles > 1 ? 's' : ''}',
            style: AppText.sans(
              color: AppColors.gold2,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ---- étape 1 : photo ----

  Widget _photoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_camera_outlined,
                  size: 34, color: AppColors.text3),
              const SizedBox(height: 10),
              Text(
                _addedBottles > 0
                    ? 'Bouteille suivante'
                    : 'Photo de l\'étiquette',
                style: AppText.sans(color: AppColors.text2, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _bigButton(
                icon: Icons.photo_camera,
                label: 'Prendre la photo',
                filled: true,
                onTap: () => _pickPhoto(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bigButton(
                icon: Icons.image_outlined,
                label: 'Importer',
                onTap: () => _pickPhoto(ImageSource.gallery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _step = _Step.quantity),
          style: TextButton.styleFrom(foregroundColor: AppColors.text3),
          child:
              Text('Continuer sans photo', style: AppText.sans(fontSize: 12)),
        ),
        _errorBox(),
      ],
    );
  }

  // ---- étape 2 : nombre ----

  Widget _quantityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photoThumb(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _stepButton(Icons.remove,
                          onTap: _quantity > 1
                              ? () => _setQuantity(_quantity - 1)
                              : null),
                      Expanded(
                        child: Text(
                          '$_quantity',
                          textAlign: TextAlign.center,
                          style: AppText.serif(
                              color: AppColors.gold2, fontSize: 40),
                        ),
                      ),
                      _stepButton(Icons.add,
                          onTap: _quantity < 60
                              ? () => _setQuantity(_quantity + 1)
                              : null),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final n in [1, 2, 3, 6, 12]) _quantityChip(n),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _formatRow(),
        const SizedBox(height: 8),
        _detailsSection(),
        _errorBox(),
      ],
    );
  }

  Widget _quantityChip(int n) {
    final selected = _quantity == n;
    return InkWell(
      onTap: () => _setQuantity(n),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.gold.withValues(alpha: 0.2) : AppColors.bg3,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? AppColors.gold : AppColors.border),
        ),
        child: Text(
          '$n',
          style: AppText.sans(
            color: selected ? AppColors.gold2 : AppColors.text2,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _formatRow() {
    return Row(
      children: [
        Text('Format',
            style: AppText.sans(color: AppColors.text3, fontSize: 12)),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<BottleFormat>(
                value: _format,
                isExpanded: true,
                dropdownColor: AppColors.bg3,
                style: AppText.sans(color: AppColors.text, fontSize: 13),
                items: BottleFormat.values
                    .map((f) =>
                        DropdownMenuItem(value: f, child: Text(f.label)))
                    .toList(),
                onChanged: (v) => setState(() => _format = v ?? _format),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _detailsSection() {
    if (!_showDetails) {
      return TextButton.icon(
        onPressed: () => setState(() => _showDetails = true),
        icon: const Icon(Icons.tune, size: 15),
        style: TextButton.styleFrom(foregroundColor: AppColors.text3),
        label: Text('Millésime, prix, note (facultatif)',
            style: AppText.sans(fontSize: 12)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _textField('Millésime', _vintage, number: true)),
              const SizedBox(width: 10),
              Expanded(
                  child: _textField('Prix achat (\$)', _price, number: true)),
            ],
          ),
          const SizedBox(height: 10),
          _textField('Note', _note, hint: 'Ex : caisse SAQ, cadeau de Marc…'),
        ],
      ),
    );
  }

  // ---- étape 3 : placement ----

  Widget _placementStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photoThumb(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_quantity × ${_format.label}',
                    style: AppText.serif(color: AppColors.gold2, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Une case par bouteille — ou passe : elles resteront '
                    'sans emplacement et tu pourras les placer plus tard.',
                    style: AppText.sans(color: AppColors.text3, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_slots.length, (i) => _slotChip(i)),
        ),
        _errorBox(),
      ],
    );
  }

  Widget _slotChip(int i) {
    final slot = _slots[i];
    final has = slot != null;
    return InkWell(
      onTap: () => _pickSlotFor(i),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: has ? AppColors.gold : AppColors.border),
        ),
        child: Row(
          children: [
            Text('Bout. ${i + 1}',
                style: AppText.sans(color: AppColors.text3, fontSize: 11)),
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
                  child: Icon(Icons.close, size: 14, color: AppColors.text3),
                ),
              )
            else
              const Icon(Icons.grid_view, size: 14, color: AppColors.text3),
          ],
        ),
      ),
    );
  }

  // ---- bas de fenêtre : la navigation de la chaîne ----

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_step != _Step.photo)
            TextButton(
              onPressed: () => setState(() {
                _step =
                    _step == _Step.placement ? _Step.quantity : _Step.photo;
              }),
              style: TextButton.styleFrom(foregroundColor: AppColors.text3),
              child: const Text('Retour'),
            )
          else
            TextButton(
              onPressed: _finish,
              style: TextButton.styleFrom(foregroundColor: AppColors.text3),
              child: Text(_addedBottles > 0 ? 'Terminer' : 'Fermer',
                  style: AppText.sans(fontSize: 13)),
            ),
          const Spacer(),
          if (_step == _Step.quantity)
            FilledButton.icon(
              onPressed: () => setState(() => _step = _Step.placement),
              icon: const Icon(Icons.arrow_forward, size: 16),
              style: _primaryStyle(),
              label: const Text('Placer'),
            ),
          if (_step == _Step.placement) ...[
            TextButton(
              onPressed: _nextBottle,
              style: TextButton.styleFrom(foregroundColor: AppColors.text2),
              child: const Text('Passer'),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              onPressed: _nextBottle,
              icon: const Icon(Icons.photo_camera, size: 16),
              style: _primaryStyle(),
              label: const Text('Suivante'),
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _primaryStyle() => FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(0xFF1A1408),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      );

  // ---- petits blocs ----

  Widget _photoThumb() {
    final has = _photoBytes != null;
    return Container(
      width: 92,
      height: 126,
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: has ? AppColors.gold : AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: has
          ? (kIsWeb && _photoBlobUrl != null
              ? platform_img.buildBlobPreview(_photoBlobUrl!)
              : Image.memory(_photoBytes!, fit: BoxFit.cover))
          : const Icon(Icons.wine_bar_outlined,
              color: AppColors.text3, size: 26),
    );
  }

  Widget _errorBox() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFB23A48).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: const Color(0xFFB23A48).withValues(alpha: 0.5)),
        ),
        child: Text(
          _error!,
          style: AppText.sans(color: const Color(0xFFE9A0AA), fontSize: 12),
        ),
      ),
    );
  }

  Widget _bigButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label,
              style: AppText.sans(fontSize: 13, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
    if (filled) {
      return FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: const Color(0xFF1A1408),
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: child,
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text2,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
      child: child,
    );
  }

  Widget _textField(String label, TextEditingController c,
      {bool number = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.sans(color: AppColors.text3, fontSize: 11)),
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

  Widget _stepButton(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon,
            size: 20,
            color: onTap == null ? AppColors.border2 : AppColors.gold2),
      ),
    );
  }
}
