import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../utils/platform_image.dart' as platform_img;
import '../models/wine.dart';
import '../models/bottle.dart';
import '../services/cave_preferences_service.dart';
import '../services/cave_service.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../services/ai_cross_check.dart';
import '../services/ai_search_job.dart';
import '../services/ai_search_job_service.dart';
import '../services/ocr_service.dart';
import '../dialogs/disagreement_dialog.dart';
import '../theme/app_text.dart';
import '../theme/app_colors.dart';
import '../widgets/native_image.dart';
import '../dialogs/photo_crop_dialog.dart';
import 'slot_picker.dart';

Future<void> showAddWineDialog(BuildContext context, {AiSearchJob? job}) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => AddWineDialog(initialJob: job),
  );
}

Future<void> showEditWineDialog(BuildContext context, Wine wine) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => AddWineDialog(wine: wine),
  );
}

class AddWineDialog extends StatefulWidget {
  final Wine? wine;
  final AiSearchJob? initialJob;
  const AddWineDialog({super.key, this.wine, this.initialJob});

  @override
  State<AddWineDialog> createState() => _AddWineDialogState();
}

String _normalizeWineName(String s) {
  if (s.trim().isEmpty) return '';
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ñ': 'n', 'ç': 'c',
    'œ': 'oe', 'æ': 'ae',
  };
  var t = s.toLowerCase();
  accents.forEach((k, v) => t = t.replaceAll(k, v));
  t = t
      .replaceAll(RegExp(r"[^a-z0-9 ]+"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return t;
}

class _AddWineDialogState extends State<AddWineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  List<Wine> _existingWines = [];
  List<Bottle> _existingBottles = [];
  bool _dupDismissed = false;

  final _aiName = TextEditingController();
  final _aiDomaine = TextEditingController();
  final _aiVintage = TextEditingController();

  final _name = TextEditingController();
  final _vintage = TextEditingController();
  final _producer = TextEditingController();
  final _appellation = TextEditingController();
  final _country = TextEditingController();
  final _region = TextEditingController();
  final _climat = TextEditingController();
  final _domaine = TextEditingController();
  final _village = TextEditingController();
  final _domainAddress = TextEditingController();
  final _grapes = TextEditingController();
  final _alcohol = TextEditingController();
  WineType _type = WineType.rouge;

  BottleFormat _format = BottleFormat.ml750;
  int _quantity = 1;
  final _price = TextEditingController();
  final _marketValue = TextEditingController();
  final _purchaseYear = TextEditingController();
  String? _source;
  final List<SlotSelection?> _slots = [null];

  final _drinkFrom = TextEditingController();
  final _drinkPeak = TextEditingController();
  final _drinkTo = TextEditingController();

  int? _rating;
  final _wineDescription = TextEditingController();
  final _domaineDescription = TextEditingController();
  final List<Critique> _critiques = [];

  bool _isGift = false;
  final _giftFrom = TextEditingController();
  final _giftOccasion = TextEditingController();
  DateTime? _giftDate;

  Uint8List? _photoBytes;
  String? _photoFileName;
  String? _existingPhotoUrl;
  String? _existingThumbUrl;
  String? _photoBlobUrl;
  int _photoViewId = 0;
  bool _saving = false;
  bool _aiLoading = false;
  String? _error;
  // OCR démarré en background dès le crop de la photo, pour que les IA
  // n'aient pas à attendre quand l'utilisateur clique Analyser.
  Future<String?>? _ocrFuture;

  bool get _editing => widget.wine != null;

  @override
  void initState() {
    super.initState();
    _loadExistingForDuplicates();
    _name.addListener(_onDupSourceChanged);
    _vintage.addListener(_onDupSourceChanged);
    final w = widget.wine;
    if (w != null) {
      _name.text = w.name;
      _aiName.text = w.name;
      if (w.domaine.isNotEmpty) _aiDomaine.text = w.domaine;
      if (w.vintage != null) {
        _vintage.text = w.vintage.toString();
        _aiVintage.text = w.vintage.toString();
      }
      _producer.text = w.producer;
      _appellation.text = w.appellation;
      _country.text = w.country;
      _region.text = w.region;
      _climat.text = w.climat;
      _domaine.text = w.domaine;
      _village.text = w.village;
      _domainAddress.text = w.domainAddress;
      _grapes.text = w.grapes;
      if (w.alcohol != null) _alcohol.text = w.alcohol.toString();
      _type = w.type;
      if (w.drinkFrom != null) _drinkFrom.text = w.drinkFrom.toString();
      if (w.drinkPeak != null) _drinkPeak.text = w.drinkPeak.toString();
      if (w.drinkTo != null) _drinkTo.text = w.drinkTo.toString();
      _rating = w.rating;
      _wineDescription.text = w.wineDescription;
      _domaineDescription.text = w.domaineDescription;
      _critiques.addAll(w.critiques);
      _existingPhotoUrl = w.photoUrl;
      _existingThumbUrl = w.thumbUrl;
    }
    // Si on rouvre depuis un job IA terminé : pré-remplir
    final job = widget.initialJob;
    if (job != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyJobOnOpen(job);
      });
    }
  }

  Future<void> _applyJobOnOpen(AiSearchJob job) async {
    // Restaurer la photo si présente
    if (job.photoBytes != null) {
      _updateBlobUrl(job.photoBytes);
      setState(() {
        _photoBytes = job.photoBytes;
        _photoFileName = job.photoFileName;
      });
    }
    // Champs de recherche
    if (job.searchName != null && job.searchName!.isNotEmpty) {
      _aiName.text = job.searchName!;
    }
    if (job.searchDomaine != null && job.searchDomaine!.isNotEmpty) {
      _aiDomaine.text = job.searchDomaine!;
    }
    if (job.searchVintage != null && job.searchVintage!.isNotEmpty) {
      _aiVintage.text = job.searchVintage!;
    }
    // Données partielles bouteille
    final d = job.draftData;
    setState(() {
      _format = d.format;
      _quantity = d.quantity;
      while (_slots.length < _quantity) {
        _slots.add(null);
      }
      while (_slots.length > _quantity) {
        _slots.removeLast();
      }
      if (d.purchasePrice != null) {
        _price.text = d.purchasePrice!.toStringAsFixed(0);
      }
      if (d.purchaseYear != null) {
        _purchaseYear.text = d.purchaseYear.toString();
      }
      _source = d.source;
      _isGift = d.isGift;
      _giftFrom.text = d.giftFrom;
      _giftOccasion.text = d.giftOccasion;
      _giftDate = d.giftDate;
    });
    // Appliquer le résultat IA si succès
    final result = job.result;
    if (result != null) {
      await _applyCrossCheck(result);
    }
  }

  void _updateBlobUrl(Uint8List? bytes) {
    platform_img.revokeBlobUrl(_photoBlobUrl);
    _photoBlobUrl = null;
    if (bytes != null) {
      _photoBlobUrl = platform_img.createBlobUrl(bytes);
      _photoViewId++;
    }
  }

  Future<void> _loadExistingForDuplicates() async {
    try {
      final wines = await CaveService.wines().first;
      final bottles = await CaveService.bottlesInCave().first;
      if (!mounted) return;
      setState(() {
        _existingWines = wines;
        _existingBottles = bottles;
      });
    } catch (_) {}
  }

  void _onDupSourceChanged() {
    if (_dupDismissed) return;
    if (mounted) setState(() {});
  }

  List<Wine> _findDuplicates() {
    final key = _normalizeWineName(_name.text);
    if (key.isEmpty || key.length < 3) return const [];
    final vintage = int.tryParse(_vintage.text);
    return _existingWines.where((w) {
      if (_editing && w.id == widget.wine!.id) return false;
      if (_normalizeWineName(w.name) != key) return false;
      if (vintage != null && w.vintage != null && w.vintage != vintage) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Bottle> _bottlesForWine(String wineId) {
    return _existingBottles.where((b) => b.wineId == wineId).toList();
  }

  @override
  void dispose() {
    _name.removeListener(_onDupSourceChanged);
    _vintage.removeListener(_onDupSourceChanged);
    platform_img.revokeBlobUrl(_photoBlobUrl);
    for (final c in [
      _aiName, _aiDomaine, _aiVintage,
      _name, _vintage, _producer, _appellation,
      _country, _region, _climat, _domaine, _village, _domainAddress,
      _grapes, _alcohol,
      _price, _marketValue, _purchaseYear,
      _drinkFrom, _drinkPeak, _drinkTo,
      _wineDescription, _domaineDescription,
      _giftFrom, _giftOccasion,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncLocations(int qty) {
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

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      Uint8List? rawBytes;
      String? fileName;

      final file = await _picker.pickImage(source: source);
      if (file == null) return;
      rawBytes = await file.readAsBytes();
      fileName = file.name;

      if (rawBytes == null || rawBytes.isEmpty) {
        setState(() => _error = 'La photo est vide.');
        return;
      }
      if (!mounted) return;

      final cropped = await showPhotoCropDialog(context, rawBytes);
      if (cropped == null || !mounted) return;

      _updateBlobUrl(cropped);
      // Démarre l'OCR en background dès maintenant. Pendant que l'utilisateur
      // regarde la photo / remplit des champs / clique Analyser, OCR tourne
      // déjà. Quand il clique, le résultat est souvent déjà disponible.
      _ocrFuture = OcrService.recognize(cropped);
      setState(() {
        _photoBytes = cropped;
        _photoFileName = fileName;
        _existingPhotoUrl = null;
        _existingThumbUrl = null;
        _error = 'Photo cadrée : ${(cropped.length / 1024).toStringAsFixed(0)} Ko';
      });
    } catch (e) {
      setState(() => _error = 'Impossible de charger la photo : $e');
    }
  }


  Future<void> _analyzeCurrentPhoto() async {
    if (_photoBytes == null) {
      setState(() => _error = 'Importe ou prends d\'abord une photo de la bouteille.');
      return;
    }
    await _analyzePhotoWithGemini(_photoBytes!);
  }

  WineDraftData _captureDraft() {
    return WineDraftData(
      format: _format,
      quantity: _quantity,
      purchasePrice: double.tryParse(_price.text.replaceAll(',', '.')),
      purchaseYear: int.tryParse(_purchaseYear.text),
      source: _source,
      isGift: _isGift,
      giftFrom: _giftFrom.text,
      giftOccasion: _giftOccasion.text,
      giftDate: _giftDate,
    );
  }

  Future<void> _analyzePhotoWithGemini(Uint8List bytes) async {
    // En mode édition : exécution synchrone (l'utilisateur veut rafraîchir).
    if (_editing) {
      setState(() {
        _aiLoading = true;
        _error = null;
      });
      try {
        final manualVintage = _aiVintage.text.trim().isNotEmpty
            ? _aiVintage.text.trim()
            : (_vintage.text.trim().isNotEmpty ? _vintage.text.trim() : null);
        final cc = await AiCrossCheck.searchByPhoto(
          bytes,
          ocrFuture: _ocrFuture,
          vintageHint: manualVintage,
        );
        if (!mounted) return;
        await _applyCrossCheck(cc);
        if (manualVintage != null && manualVintage.isNotEmpty) {
          setState(() => _vintage.text = manualVintage);
        }
      } catch (e) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _aiLoading = false);
      }
      return;
    }
    // Nouveau vin : on enqueue le job en arrière-plan + on ferme.
    _enqueueAndClose();
    unawaited(AiSearchJobService.enqueuePhoto(
      photoBytes: bytes,
      photoFileName: _photoFileName,
      searchName: _aiName.text.trim().isEmpty ? null : _aiName.text.trim(),
      searchDomaine:
          _aiDomaine.text.trim().isEmpty ? null : _aiDomaine.text.trim(),
      searchVintage:
          _aiVintage.text.trim().isEmpty ? null : _aiVintage.text.trim(),
      draftData: _captureDraft(),
    ));
  }

  Future<void> _searchWithGemini() async {
    if (_aiName.text.trim().isEmpty) {
      setState(() => _error = 'Entre un nom de vin pour utiliser Gemini.');
      return;
    }
    if (_editing) {
      setState(() {
        _aiLoading = true;
        _error = null;
      });
      try {
        final cc = await AiCrossCheck.searchByText(
          name: _aiName.text.trim(),
          domaine: _aiDomaine.text.trim(),
          vintage: _aiVintage.text.trim(),
        );
        if (!mounted) return;
        await _applyCrossCheck(cc);
        if (_aiVintage.text.isNotEmpty) {
          setState(() => _vintage.text = _aiVintage.text.trim());
        }
      } catch (e) {
        setState(() => _error = e.toString().replaceAll('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _aiLoading = false);
      }
      return;
    }
    _enqueueAndClose();
    unawaited(AiSearchJobService.enqueueText(
      name: _aiName.text.trim(),
      domaine:
          _aiDomaine.text.trim().isEmpty ? null : _aiDomaine.text.trim(),
      vintage:
          _aiVintage.text.trim().isEmpty ? null : _aiVintage.text.trim(),
      draftData: _captureDraft(),
    ));
  }

  void _enqueueAndClose() {
    if (!mounted) return;
    Navigator.of(context).pop();
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: AppColors.gold,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.cloud_sync_outlined,
                size: 18, color: Color(0xFF1A1408)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Recherche IA lancée. Suivi : Paramètres → Recherches IA',
                style: AppText.sans(
                  color: const Color(0xFF1A1408),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyCrossCheck(CrossCheckResult cc) async {
    if (cc.disagreements.isEmpty) {
      _applyGeminiResult(cc.merged);
      if (cc.errors.isNotEmpty) {
        final msg = cc.errors.entries
            .map((e) => '${e.key.label}: ${e.value}')
            .join(' · ');
        setState(() => _error = 'IA secondaire(s) indisponible(s) : $msg');
      }
      return;
    }
    final chosen = await showDisagreementDialog(context, cc.disagreements);
    if (!mounted) return;
    // Si l'utilisateur a annulé/fermé : on applique quand même les choix
    // pré-sélectionnés par l'IA (validator + résolution Gemini grounded).
    // Sinon on perdrait toutes les corrections automatiques.
    final finalResult =
        AiCrossCheck.applyChoices(cc, chosen ?? cc.disagreements);
    _applyGeminiResult(finalResult);
  }


  void _applyGeminiResult(GeminiResult result) {
    setState(() {
      _name.text = result.name;
      _producer.text = result.producer;
      if (result.vintage != null) _vintage.text = result.vintage.toString();
      _appellation.text = result.appellation;
      _country.text = result.country;
      _region.text = result.region;
      _climat.text = result.climat;
      _domaine.text = result.domaine;
      _village.text = result.village;
      _domainAddress.text = result.domainAddress;
      _grapes.text = result.grapes;
      if (result.alcohol != null) _alcohol.text = result.alcohol.toString();
      _type = WineType.values.firstWhere(
        (t) => t.name == result.type,
        orElse: () => WineType.rouge,
      );
      if (result.drinkFrom != null) _drinkFrom.text = result.drinkFrom.toString();
      if (result.drinkPeak != null) _drinkPeak.text = result.drinkPeak.toString();
      if (result.drinkTo != null) _drinkTo.text = result.drinkTo.toString();
      if (result.marketValue != null) _marketValue.text = result.marketValue!.toStringAsFixed(0);
      _wineDescription.text = result.wineDescription;
      _domaineDescription.text = result.domaineDescription;
      if (result.critiques.isNotEmpty) {
        _critiques
          ..clear()
          ..addAll(result.critiques);
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_editing) {
      await _saveEdit();
      return;
    }

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

      developer.log(
        '[Save] _photoBytes=${_photoBytes?.length ?? "null"} _photoFileName=$_photoFileName',
        name: 'cave_vin_jo',
      );

      String? photoUrl;
      String? thumbUrl;
      String? photoUploadError;
      if (_photoBytes != null) {
        try {
          final urls = await StorageService.uploadWinePhoto(
            bytes: _photoBytes!,
            fileName: _photoFileName ?? 'wine.jpg',
          );
          photoUrl = urls.photoUrl;
          thumbUrl = urls.thumbUrl;
          developer.log('[Save] photoUrl=$photoUrl thumbUrl=$thumbUrl', name: 'cave_vin_jo');
        } catch (e) {
          photoUploadError = e.toString().replaceAll('Exception: ', '');
          developer.log('[Save] upload FAILED: $photoUploadError', name: 'cave_vin_jo');
        }
      } else {
        developer.log('[Save] no photoBytes — skipping upload', name: 'cave_vin_jo');
      }

      final now = DateTime.now();
      final wine = Wine(
        id: '',
        name: _name.text.trim(),
        producer: _producer.text.trim(),
        vintage: int.tryParse(_vintage.text),
        appellation: _appellation.text.trim(),
        country: _country.text.trim(),
        region: _region.text.trim(),
        climat: _climat.text.trim(),
        domaine: _domaine.text.trim(),
        village: _village.text.trim(),
        domainAddress: _domainAddress.text.trim(),
        grapes: _grapes.text.trim(),
        alcohol: double.tryParse(_alcohol.text.replaceAll(',', '.')),
        type: _type,
        drinkFrom: int.tryParse(_drinkFrom.text),
        drinkPeak: int.tryParse(_drinkPeak.text),
        drinkTo: int.tryParse(_drinkTo.text),
        rating: _rating,
        wineDescription: _wineDescription.text.trim(),
        domaineDescription: _domaineDescription.text.trim(),
        photoUrl: photoUrl,
        thumbUrl: thumbUrl,
        critiques: List.unmodifiable(_critiques),
        createdAt: now,
      );

      final price = double.tryParse(_price.text.replaceAll(',', '.'));
      final market = double.tryParse(_marketValue.text.replaceAll(',', '.'));
      final year = int.tryParse(_purchaseYear.text);

      final bottles = _slots.map((s) => Bottle(
            id: '',
            wineId: '',
            location: s?.label ?? '',
            cellarId: s?.cellarId,
            slotCol: s?.col,
            slotRow: s?.row,
            format: _format,
            purchasePrice: price,
            marketValue: market,
            purchaseYear: year,
            source: _source,
            isGift: _isGift,
            giftFrom: _isGift ? _giftFrom.text.trim() : '',
            giftOccasion: _isGift ? _giftOccasion.text.trim() : '',
            giftDate: _isGift ? _giftDate : null,
            createdAt: now,
          )).toList();

      await CaveService.addWineWithBottles(wine: wine, bottles: bottles);

      if (!mounted) return;

      final String photoStatus;
      if (_photoBytes == null) {
        photoStatus = ' (sans photo)';
      } else if (photoUrl != null) {
        photoStatus = ' ✓ avec photo';
      } else {
        photoStatus = ' ⚠ PHOTO ÉCHOUÉE — ${photoUploadError ?? "raison inconnue"}';
      }

      // Retire le job de recherche IA si on est arrivé via un job (option 5D).
      if (widget.initialJob != null) {
        AiSearchJobService.remove(widget.initialJob!.id);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: photoUploadError != null
              ? const Color(0xFFB23A48)
              : AppColors.gold,
          duration: Duration(seconds: photoUploadError != null ? 12 : 4),
          content: Text(
            '${wine.name} ajouté ($_quantity bouteille${_quantity > 1 ? 's' : ''})$photoStatus',
            style: TextStyle(
              color: photoUploadError != null
                  ? Colors.white
                  : const Color(0xFF1A1408),
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

  Future<void> _saveEdit() async {
    final w = widget.wine!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? photoUrl = _existingPhotoUrl;
      String? thumbUrl = _existingThumbUrl;
      String? photoUploadError;
      if (_photoBytes != null) {
        try {
          final urls = await StorageService.uploadWinePhoto(
            bytes: _photoBytes!,
            fileName: _photoFileName ?? 'wine.jpg',
          );
          photoUrl = urls.photoUrl;
          thumbUrl = urls.thumbUrl;
        } catch (e) {
          photoUrl = _existingPhotoUrl;
          thumbUrl = _existingThumbUrl;
          photoUploadError = e.toString().replaceAll('Exception: ', '');
        }
      }

      await CaveService.updateWine(w.id, {
        'name': _name.text.trim(),
        'vintage': int.tryParse(_vintage.text),
        'producer': _producer.text.trim(),
        'appellation': _appellation.text.trim(),
        'country': _country.text.trim(),
        'region': _region.text.trim(),
        'climat': _climat.text.trim(),
        'domaine': _domaine.text.trim(),
        'village': _village.text.trim(),
        'domainAddress': _domainAddress.text.trim(),
        'grapes': _grapes.text.trim(),
        'alcohol': double.tryParse(_alcohol.text.replaceAll(',', '.')),
        'type': _type.name,
        'drinkFrom': int.tryParse(_drinkFrom.text),
        'drinkPeak': int.tryParse(_drinkPeak.text),
        'drinkTo': int.tryParse(_drinkTo.text),
        'rating': _rating,
        'wineDescription': _wineDescription.text.trim(),
        'domaineDescription': _domaineDescription.text.trim(),
        'photoUrl': photoUrl,
        'thumbUrl': thumbUrl,
        'critiques': _critiques.map((c) => c.toMap()).toList(),
      });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: photoUploadError != null
              ? const Color(0xFFB23A48)
              : AppColors.gold,
          duration: Duration(seconds: photoUploadError != null ? 12 : 4),
          content: Text(
            photoUploadError != null
                ? '${_name.text.trim()} mis à jour ⚠ PHOTO ÉCHOUÉE — $photoUploadError'
                : '${_name.text.trim()} mis à jour',
            style: TextStyle(
              color: photoUploadError != null
                  ? Colors.white
                  : const Color(0xFF1A1408),
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
    final maxWidth = size.width > 900 ? 860.0 : size.width - 32;
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
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(),
              Flexible(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildContent(),
                  ),
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
            _editing ? 'Modifier le vin' : 'Ajouter un vin',
            style: AppText.serif(
              color: AppColors.gold2,
              fontSize: 22,
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

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_error != null)
            Expanded(
              child: Text(
                _error!,
                style: AppText.sans(color: const Color(0xFFE07060), fontSize: 12),
              ),
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF1A1408)),
                  )
                : Text(
                    _editing ? 'Enregistrer les modifications' : 'Enregistrer',
                    style: AppText.sans(
                        fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final duplicates = _dupDismissed ? const <Wine>[] : _findDuplicates();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _aiBar(),
        if (duplicates.isNotEmpty) ...[
          const SizedBox(height: 14),
          _duplicateBanner(duplicates),
        ],
        const SizedBox(height: 22),

        _section('Identification'),
        _grid2([
          _field('Nom du vin *', _name, required: true),
          _field('Millésime', _vintage, number: true),
        ]),
        _grid2([
          _field('Producteur', _producer),
          _field('Appellation', _appellation),
        ]),
        _grid2([
          _field('Pays', _country),
          _field('Région', _region),
        ]),
        _grid2([
          _field('Climat / Lieu-dit', _climat),
          _field('Village', _village),
        ]),
        _grid2([
          _field('Domaine / Monopole', _domaine),
          _buildTypeDropdown(),
        ]),
        _single(_field('Adresse du domaine', _domainAddress,
            hint: 'Ex: Château Pétrus, 33500 Pomerol, France')),
        _grid2([
          _field('Cépages', _grapes),
          _field('Alcool (%)', _alcohol, number: true),
        ]),

        if (!_editing) ...[
          const SizedBox(height: 22),
          _section('Stock & Achat'),
          _grid2([
            _buildFormatDropdown(),
            _buildQuantityField(),
          ]),
          _grid2([
            _field('Prix achat (\$)', _price, number: true),
            _field('Valeur marché (\$)', _marketValue, number: true),
          ]),
          _grid2([
            _field('Année achat', _purchaseYear, number: true),
            _buildSourceDropdown(),
          ]),
          const SizedBox(height: 10),
          _buildLocationsList(),
        ],

        const SizedBox(height: 22),
        _section('Fenêtre de dégustation'),
        _grid3([
          _field('À boire dès', _drinkFrom, number: true),
          _field('Apogée', _drinkPeak, number: true),
          _field('Fin de garde', _drinkTo, number: true),
        ]),

        const SizedBox(height: 22),
        _section('Notes & Évaluation'),
        _single(_buildRatingSlider()),
        const SizedBox(height: 10),
        _single(_field('Description du vin', _wineDescription,
            maxLines: 5, hint: 'Robe, arômes, bouche, structure, finale…')),
        const SizedBox(height: 10),
        _single(_field('Description du domaine', _domaineDescription,
            maxLines: 4, hint: 'Histoire, philosophie, terroir, réputation…')),

        const SizedBox(height: 22),
        _critiquesSection(),

        if (!_editing) ...[
          const SizedBox(height: 22),
          _section('Cadeau'),
          _buildGiftCheckbox(),
          if (_isGift) ...[
            const SizedBox(height: 12),
            _grid2([
              _field('De qui', _giftFrom),
              _field('Occasion', _giftOccasion, hint: 'Noël, anniversaire…'),
            ]),
            _single(_buildGiftDatePicker()),
          ],
        ],
      ],
    );
  }

  Widget _section(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.only(bottom: 8),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 12),
          Expanded(child: children[1]),
        ],
      ),
    );
  }

  Widget _grid3(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 12),
          Expanded(child: children[1]),
          const SizedBox(width: 12),
          Expanded(child: children[2]),
        ],
      ),
    );
  }

  Widget _single(Widget child) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    bool number = false,
    int maxLines = 1,
    String? hint,
  }) {
    return _labeled(
      label,
      TextFormField(
        controller: controller,
        keyboardType: number ? TextInputType.number : null,
        maxLines: maxLines,
        style: AppText.sans(color: AppColors.text, fontSize: 13),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null
            : null,
        decoration: _decoration(hint: hint),
      ),
    );
  }

  Widget _labeled(String label, Widget child) {
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

  InputDecoration _decoration({String? hint}) => InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.bg3,
        hintText: hint,
        hintStyle: AppText.sans(color: AppColors.text3, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        border: _borderRadius(AppColors.border),
        enabledBorder: _borderRadius(AppColors.border),
        focusedBorder: _borderRadius(AppColors.gold),
      );

  OutlineInputBorder _borderRadius(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c),
      );

  Widget _dropdownContainer(Widget child) {
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

  Widget _buildTypeDropdown() {
    return _labeled(
      'Type',
      _dropdownContainer(
        DropdownButton<WineType>(
          value: _type,
          isExpanded: true,
          dropdownColor: AppColors.bg2,
          style: AppText.sans(color: AppColors.text, fontSize: 13),
          items: WineType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t))))
              .toList(),
          onChanged: (v) => setState(() => _type = v ?? WineType.rouge),
        ),
      ),
    );
  }

  String _typeLabel(WineType t) {
    switch (t) {
      case WineType.rouge:
        return 'Rouge';
      case WineType.blanc:
        return 'Blanc';
      case WineType.rose:
        return 'Rosé';
      case WineType.orange:
        return 'Orange';
      case WineType.petillant:
        return 'Pétillant';
    }
  }

  Widget _buildFormatDropdown() {
    return _labeled(
      'Format',
      _dropdownContainer(
        DropdownButton<BottleFormat>(
          value: _format,
          isExpanded: true,
          dropdownColor: AppColors.bg2,
          style: AppText.sans(color: AppColors.text, fontSize: 13),
          items: BottleFormat.values
              .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
              .toList(),
          onChanged: (v) => setState(() => _format = v ?? BottleFormat.ml750),
        ),
      ),
    );
  }

  Widget _buildSourceDropdown() {
    return _labeled(
      'Provenance',
      ValueListenableBuilder<List<String>>(
        valueListenable: CavePreferencesService.customSources,
        builder: (context, _, __) {
          final labels = CavePreferencesService.allSourceLabels;
          // Garde le _source courant si c'était une valeur supprimée.
          final hasCurrent = _source == null || labels.contains(_source);
          return _dropdownContainer(
            DropdownButton<String?>(
              value: hasCurrent ? _source : null,
              isExpanded: true,
              dropdownColor: AppColors.bg2,
              hint: Text('Choisir…',
                  style: AppText.sans(color: AppColors.text3, fontSize: 13)),
              style: AppText.sans(color: AppColors.text, fontSize: 13),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('—',
                      style: AppText.sans(
                          color: AppColors.text3, fontSize: 13)),
                ),
                ...labels.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _source = v),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuantityField() {
    return _labeled(
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
            _qtyBtn(Icons.remove, () {
              if (_quantity > 1) _syncLocations(_quantity - 1);
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
            _qtyBtn(Icons.add, () => _syncLocations(_quantity + 1)),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 38, height: 40,
        child: Icon(icon, color: AppColors.gold2, size: 18),
      ),
    );
  }

  Widget _buildLocationsList() {
    return _labeled(
      'Emplacements cave (une case par bouteille)',
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                    style: AppText.sans(color: AppColors.text3, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasSlot ? slot.label : 'Choisir…',
                      style: AppText.sans(
                        color: hasSlot ? AppColors.gold2 : AppColors.text3,
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
    );
  }

  Widget _buildRatingSlider() {
    return _labeled(
      'Note de dégustation (/100)',
      Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.gold,
                inactiveTrackColor: AppColors.bg4,
                thumbColor: AppColors.gold2,
                overlayColor: AppColors.gold.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: (_rating ?? 0).toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (v) => setState(() => _rating = v == 0 ? null : v.round()),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 50,
            child: Text(
              _rating == null ? '—' : '$_rating',
              textAlign: TextAlign.center,
              style: AppText.serif(
                color: AppColors.gold2,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCheckbox() {
    return InkWell(
      onTap: () => setState(() => _isGift = !_isGift),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: _isGift,
              onChanged: (v) => setState(() => _isGift = v ?? false),
              activeColor: AppColors.gold,
              checkColor: const Color(0xFF1A1408),
              side: const BorderSide(color: AppColors.border2),
            ),
            const SizedBox(width: 4),
            Text('Ce vin est un cadeau',
                style: AppText.sans(color: AppColors.text, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftDatePicker() {
    return _labeled(
      'Date du cadeau',
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _giftDate ?? DateTime.now(),
            firstDate: DateTime(1900),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            builder: (context, child) => Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: AppColors.gold,
                  onPrimary: Color(0xFF1A1408),
                  surface: AppColors.bg2,
                  onSurface: AppColors.text,
                ),
              ),
              child: child!,
            ),
          );
          if (picked != null) setState(() => _giftDate = picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.text3),
              const SizedBox(width: 10),
              Text(
                _giftDate == null
                    ? 'Choisir une date'
                    : '${_giftDate!.day.toString().padLeft(2, '0')}/'
                        '${_giftDate!.month.toString().padLeft(2, '0')}/'
                        '${_giftDate!.year}',
                style: AppText.sans(
                  color: _giftDate == null ? AppColors.text3 : AppColors.text,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _duplicateBanner(List<Wine> duplicates) {
    final orange = const Color(0xFFD49A4C);
    int totalBottles = 0;
    final lines = <Widget>[];
    for (final w in duplicates) {
      final bottles = _bottlesForWine(w.id);
      if (bottles.isEmpty) continue;
      totalBottles += bottles.length;
      final locations = bottles
          .map((b) => b.location.isEmpty ? 'sans emplacement' : b.location)
          .toSet()
          .toList()
        ..sort();
      final locText = locations.length > 4
          ? '${locations.take(4).join(', ')} +${locations.length - 4}'
          : locations.join(', ');
      final vint = w.vintage != null ? ' ${w.vintage}' : '';
      lines.add(
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '• ${w.name}$vint — ${bottles.length} bouteille${bottles.length > 1 ? 's' : ''} ($locText)',
            style: AppText.sans(color: AppColors.text2, fontSize: 12, height: 1.35),
          ),
        ),
      );
    }
    if (lines.isEmpty || totalBottles == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: const Color(0x1FD49A4C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: orange.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editing
                      ? 'Doublon possible avec un autre vin de ta cave'
                      : 'Tu as peut-être déjà ce vin',
                  style: AppText.sans(
                    color: orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                ...lines,
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _dupDismissed = true),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: AppColors.text3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiBar() {
    final hasPhoto = _photoBytes != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PHOTO DU VIN + ANALYSE IA',
            style: AppText.sans(
              color: AppColors.gold2,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'La photo sera enregistrée sur la fiche. Clique sur « Analyser avec Gemini » pour remplir les champs.',
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          if (hasPhoto || _existingPhotoUrl != null) ...[
            Center(child: _bigPhotoPreview()),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _aiBtn(
                  label: '📷 Prendre photo',
                  onTap: _aiLoading
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _aiBtn(
                  label: '🖼 Importer',
                  onTap: _aiLoading
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _aiBtn(
              label: _aiLoading
                  ? '⏳ Analyse en cours…'
                  : (hasPhoto
                      ? '✶ Analyser avec Gemini'
                      : '✶ Importe une photo pour analyser'),
              primary: hasPhoto && !_aiLoading,
              muted: !hasPhoto,
              onTap: (hasPhoto && !_aiLoading) ? _analyzeCurrentPhoto : null,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OU RECHERCHE PAR NOM',
                  style: AppText.sans(
                    color: AppColors.text3,
                    fontSize: 9,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.border, height: 1)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _aiName,
                  style: AppText.sans(color: AppColors.text, fontSize: 13),
                  decoration: _decoration(hint: 'Nom du vin…'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _aiDomaine,
                  style: AppText.sans(color: AppColors.text, fontSize: 13),
                  decoration: _decoration(hint: 'Domaine…'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _aiVintage,
                  style: AppText.sans(color: AppColors.text, fontSize: 13),
                  decoration: _decoration(hint: '2020'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _aiBtn(
                  label: _aiLoading ? '⏳' : '✶ Chercher',
                  primary: true,
                  onTap: _aiLoading ? null : _searchWithGemini,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigPhotoPreview() {
    final hasNew = _photoBytes != null;
    final hasExisting = !hasNew && _existingPhotoUrl != null;
    return Column(
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.55), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 240,
                  height: 320,
                  child: hasNew && _photoBytes != null
                      ? (kIsWeb && _photoBlobUrl != null
                          ? platform_img.buildBlobPreview(_photoBlobUrl!)
                          : Image.memory(_photoBytes!, fit: BoxFit.cover))
                      : NativeNetworkImage(
                          url: _existingPhotoUrl!,
                          width: 240,
                          height: 320,
                          fit: BoxFit.contain,
                        ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: () {
                  if (hasNew) {
                    _updateBlobUrl(null);
                    setState(() {
                      _photoBytes = null;
                      _photoFileName = null;
                    });
                  } else if (hasExisting) {
                    setState(() {
                      _existingPhotoUrl = null;
                      _existingThumbUrl = null;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hasNew
              ? '✓ PHOTO PRÊTE — ENREGISTRÉE SUR LA FICHE'
              : '✓ PHOTO ACTUELLE DE LA FICHE',
          style: AppText.sans(
            color: AppColors.gold2,
            fontSize: 9,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }


  Widget _aiBtn({
    required String label,
    VoidCallback? onTap,
    bool primary = false,
    bool muted = false,
  }) {
    final Color bg = primary ? AppColors.gold : AppColors.bg2;
    final Color border = primary
        ? AppColors.gold
        : (muted ? AppColors.border : AppColors.border2);
    final Color fg = primary
        ? const Color(0xFF1A1408)
        : (muted ? AppColors.text3 : AppColors.text2);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: AppText.sans(
              color: fg,
              fontSize: 12,
              fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _critiquesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _section('Critiques (rempli par Gemini)'),
        if (_critiques.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, style: BorderStyle.solid),
            ),
            child: Text(
              'Aucune critique. Utilise ✶ Gemini pour les remplir automatiquement, ou ajoute-les manuellement.',
              style: AppText.sans(color: AppColors.text3, fontSize: 12),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < _critiques.length; i++) ...[
                _critiqueRow(_critiques[i], i),
                if (i < _critiques.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: _addCritiqueDialog,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border2),
              ),
              child: Text(
                '+ Ajouter une critique',
                style: AppText.sans(
                  color: AppColors.gold2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _critiqueRow(Critique c, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.source.isEmpty ? 'Critique' : c.source,
                      style: AppText.serif(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (c.date != null)
                      Text(
                        '${c.date!.day.toString().padLeft(2, '0')}/'
                        '${c.date!.month.toString().padLeft(2, '0')}/'
                        '${c.date!.year}',
                        style: AppText.sans(
                          color: AppColors.text3,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              if (c.score.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x29C9A84C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x66C9A84C)),
                  ),
                  child: Text(
                    c.score,
                    style: AppText.serif(
                      color: AppColors.gold2,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              InkWell(
                onTap: () => setState(() => _critiques.removeAt(index)),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.close,
                    size: 14,
                    color: AppColors.text3,
                  ),
                ),
              ),
            ],
          ),
          if (c.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              c.note,
              style: AppText.serif(
                color: AppColors.text2,
                fontSize: 13,
                height: 1.5,
              ).copyWith(fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addCritiqueDialog() async {
    final sourceCtrl = TextEditingController();
    final scoreCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime? date;

    final added = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => Dialog(
            backgroundColor: AppColors.bg2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border2),
            ),
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajouter une critique',
                    style: AppText.serif(
                      color: AppColors.gold2,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _labeled(
                    'Source / critique',
                    TextField(
                      controller: sourceCtrl,
                      style: AppText.sans(color: AppColors.text, fontSize: 13),
                      decoration: _decoration(hint: 'Robert Parker, Decanter, ...'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _labeled(
                    'Note',
                    TextField(
                      controller: scoreCtrl,
                      style: AppText.sans(color: AppColors.text, fontSize: 13),
                      decoration: _decoration(hint: '98/100, 19/20, 5/5...'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _labeled(
                    'Citation / commentaire',
                    TextField(
                      controller: noteCtrl,
                      maxLines: 4,
                      style: AppText.sans(color: AppColors.text, fontSize: 13),
                      decoration: _decoration(hint: 'Note de dégustation...'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _labeled(
                    'Date (optionnelle)',
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                          builder: (c, child) => Theme(
                            data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: AppColors.gold,
                                onPrimary: Color(0xFF1A1408),
                                surface: AppColors.bg2,
                                onSurface: AppColors.text,
                              ),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setLocal(() => date = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.bg3,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: AppColors.text3),
                            const SizedBox(width: 10),
                            Text(
                              date == null
                                  ? 'Choisir une date'
                                  : '${date!.day.toString().padLeft(2, '0')}/'
                                      '${date!.month.toString().padLeft(2, '0')}/'
                                      '${date!.year}',
                              style: AppText.sans(
                                color: date == null
                                    ? AppColors.text3
                                    : AppColors.text,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Annuler',
                            style: AppText.sans(color: AppColors.text2)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (sourceCtrl.text.trim().isEmpty &&
                              scoreCtrl.text.trim().isEmpty &&
                              noteCtrl.text.trim().isEmpty) {
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: const Color(0xFF1A1408),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Ajouter',
                            style: AppText.sans(
                                fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (added == true) {
      setState(() {
        _critiques.add(Critique(
          source: sourceCtrl.text.trim(),
          score: scoreCtrl.text.trim(),
          note: noteCtrl.text.trim(),
          date: date,
          // Saisie manuelle par l'utilisateur : pas soumise au verrou IA.
          verifie: true,
        ));
      });
    }

    sourceCtrl.dispose();
    scoreCtrl.dispose();
    noteCtrl.dispose();
  }
}
