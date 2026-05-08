import 'dart:developer' as developer;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../utils/platform_image.dart' as platform_img;
import '../models/wine.dart';
import '../models/wish_wine.dart';
import '../services/wishlist_service.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../theme/app_text.dart';
import '../theme/app_colors.dart';
import '../widgets/native_image.dart';
import '../dialogs/photo_crop_dialog.dart';

Future<void> showAddWishDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => const AddWishDialog(),
  );
}

Future<void> showEditWishDialog(BuildContext context, WishWine wish) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => AddWishDialog(wish: wish),
  );
}

class AddWishDialog extends StatefulWidget {
  final WishWine? wish;
  const AddWishDialog({super.key, this.wish});

  @override
  State<AddWishDialog> createState() => _AddWishDialogState();
}

class _AddWishDialogState extends State<AddWishDialog> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

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

  final _drinkFrom = TextEditingController();
  final _drinkPeak = TextEditingController();
  final _drinkTo = TextEditingController();

  int? _rating;
  final _wineDescription = TextEditingController();
  final _domaineDescription = TextEditingController();
  final _personalNote = TextEditingController();
  final _marketValue = TextEditingController();
  final List<Critique> _critiques = [];

  Uint8List? _photoBytes;
  String? _photoFileName;
  String? _existingPhotoUrl;
  String? _photoBlobUrl;
  int _photoViewId = 0;
  bool _saving = false;
  bool _aiLoading = false;
  String? _error;

  bool get _editing => widget.wish != null;

  @override
  void initState() {
    super.initState();
    final w = widget.wish;
    if (w == null) return;
    _name.text = w.name;
    if (w.vintage != null) _vintage.text = w.vintage.toString();
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
    _personalNote.text = w.personalNote;
    if (w.marketValue != null) _marketValue.text = w.marketValue!.toStringAsFixed(0);
    _critiques.addAll(w.critiques);
    _existingPhotoUrl = w.photoUrl;
  }

  void _updateBlobUrl(Uint8List? bytes) {
    platform_img.revokeBlobUrl(_photoBlobUrl);
    _photoBlobUrl = null;
    if (bytes != null) {
      _photoBlobUrl = platform_img.createBlobUrl(bytes);
      _photoViewId++;
    }
  }

  @override
  void dispose() {
    platform_img.revokeBlobUrl(_photoBlobUrl);
    for (final c in [
      _aiName, _aiDomaine, _aiVintage,
      _name, _vintage, _producer, _appellation,
      _country, _region, _climat, _domaine, _village, _domainAddress,
      _grapes, _alcohol,
      _drinkFrom, _drinkPeak, _drinkTo,
      _wineDescription, _domaineDescription,
      _personalNote, _marketValue,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Photo picking
  // ---------------------------------------------------------------------------

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
      setState(() {
        _photoBytes = cropped;
        _photoFileName = fileName;
        _existingPhotoUrl = null;
        _error = 'Photo cadrée : ${(cropped.length / 1024).toStringAsFixed(0)} Ko';
      });
    } catch (e) {
      setState(() => _error = 'Impossible de charger la photo : $e');
    }
  }


  // ---------------------------------------------------------------------------
  // Gemini AI
  // ---------------------------------------------------------------------------

  Future<void> _analyzeCurrentPhoto() async {
    if (_photoBytes == null) {
      setState(() => _error = 'Importe ou prends d\'abord une photo de la bouteille.');
      return;
    }
    await _analyzePhotoWithGemini(_photoBytes!);
  }

  Future<void> _analyzePhotoWithGemini(Uint8List bytes) async {
    setState(() {
      _aiLoading = true;
      _error = null;
    });
    try {
      final manualVintage = _aiVintage.text.trim().isNotEmpty
          ? _aiVintage.text.trim()
          : (_vintage.text.trim().isNotEmpty ? _vintage.text.trim() : null);
      final result = await GeminiService.searchByPhoto(
        bytes,
        vintageHint: manualVintage,
      );
      if (!mounted) return;
      _applyGeminiResult(result);
      if (manualVintage != null && manualVintage.isNotEmpty) {
        setState(() => _vintage.text = manualVintage);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  Future<void> _searchWithGemini() async {
    if (_aiName.text.trim().isEmpty) {
      setState(() => _error = 'Entre un nom de vin pour utiliser Gemini.');
      return;
    }
    setState(() {
      _aiLoading = true;
      _error = null;
    });
    try {
      final result = await GeminiService.searchByText(
        name: _aiName.text.trim(),
        domaine: _aiDomaine.text.trim(),
        vintage: _aiVintage.text.trim(),
      );
      if (!mounted) return;
      _applyGeminiResult(result);
      if (_aiVintage.text.isNotEmpty) {
        setState(() => _vintage.text = _aiVintage.text.trim());
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
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

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_editing) {
      await _saveEdit();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      developer.log(
        '[SaveWish] _photoBytes=${_photoBytes?.length ?? "null"} _photoFileName=$_photoFileName',
        name: 'cave_vin_jo',
      );

      String? photoUrl;
      String? photoUploadError;
      if (_photoBytes != null) {
        try {
          photoUrl = await StorageService.uploadWinePhoto(
            bytes: _photoBytes!,
            fileName: _photoFileName ?? 'wine.jpg',
          );
          developer.log('[SaveWish] photoUrl=$photoUrl', name: 'cave_vin_jo');
        } catch (e) {
          photoUploadError = e.toString().replaceAll('Exception: ', '');
          developer.log('[SaveWish] upload FAILED: $photoUploadError', name: 'cave_vin_jo');
        }
      } else {
        developer.log('[SaveWish] no photoBytes — skipping upload', name: 'cave_vin_jo');
      }

      final now = DateTime.now();
      final market = double.tryParse(_marketValue.text.replaceAll(',', '.'));

      final wish = WishWine(
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
        critiques: List.unmodifiable(_critiques),
        marketValue: market,
        personalNote: _personalNote.text.trim(),
        createdAt: now,
      );

      await WishlistService.addWish(wish);

      if (!mounted) return;

      final String photoStatus;
      if (_photoBytes == null) {
        photoStatus = ' (sans photo)';
      } else if (photoUrl != null) {
        photoStatus = '';
      } else {
        photoStatus = ' — PHOTO ECHOUEE : ${photoUploadError ?? "raison inconnue"}';
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: photoUploadError != null
              ? const Color(0xFFB23A48)
              : AppColors.gold,
          duration: Duration(seconds: photoUploadError != null ? 12 : 4),
          content: Text(
            '${wish.name} ajouté aux souhaits$photoStatus',
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
    final w = widget.wish!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? photoUrl = _existingPhotoUrl;
      String? photoUploadError;
      if (_photoBytes != null) {
        try {
          photoUrl = await StorageService.uploadWinePhoto(
            bytes: _photoBytes!,
            fileName: _photoFileName ?? 'wine.jpg',
          );
        } catch (e) {
          photoUrl = _existingPhotoUrl;
          photoUploadError = e.toString().replaceAll('Exception: ', '');
        }
      }

      final market = double.tryParse(_marketValue.text.replaceAll(',', '.'));

      await WishlistService.updateWish(w.id, {
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
        'critiques': _critiques.map((c) => c.toMap()).toList(),
        'marketValue': market,
        'personalNote': _personalNote.text.trim(),
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
                ? '${_name.text.trim()} mis à jour — PHOTO ECHOUEE : $photoUploadError'
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
            _editing ? 'Modifier le souhait' : 'Ajouter à la liste de souhaits',
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

  // ---------------------------------------------------------------------------
  // Content
  // ---------------------------------------------------------------------------

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _aiBar(),
        const SizedBox(height: 22),

        _section('Identification'),
        _grid2([
          _field('Nom du vin *', _name, required: true),
          _field('Millesime', _vintage, number: true),
        ]),
        _grid2([
          _field('Producteur', _producer),
          _field('Appellation', _appellation),
        ]),
        _grid2([
          _field('Pays', _country),
          _field('Region', _region),
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
            hint: 'Ex: Chateau Petrus, 33500 Pomerol, France')),
        _grid2([
          _field('Cepages', _grapes),
          _field('Alcool (%)', _alcohol, number: true),
        ]),

        const SizedBox(height: 22),
        _section('Garde'),
        _grid3([
          _field('A boire des', _drinkFrom, number: true),
          _field('Apogee', _drinkPeak, number: true),
          _field('Fin de garde', _drinkTo, number: true),
        ]),

        const SizedBox(height: 22),
        _section('Notes & Description'),
        _single(_buildRatingSlider()),
        const SizedBox(height: 10),
        _single(_field('Description du vin', _wineDescription,
            maxLines: 5, hint: 'Robe, aromes, bouche, structure, finale...')),
        const SizedBox(height: 10),
        _single(_field('Description du domaine', _domaineDescription,
            maxLines: 4, hint: 'Histoire, philosophie, terroir, reputation...')),
        const SizedBox(height: 10),
        _single(_field('Note personnelle', _personalNote,
            maxLines: 4, hint: 'Pourquoi ce vin t\'interesse, occasion prevue...')),
        const SizedBox(height: 10),
        _single(_field('Valeur marche (\$)', _marketValue, number: true)),

        const SizedBox(height: 22),
        _critiquesSection(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // AI Bar
  // ---------------------------------------------------------------------------

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
            'La photo sera enregistree sur la fiche. Clique sur "Analyser avec Gemini" pour remplir les champs.',
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
                  label: 'Prendre photo',
                  onTap: _aiLoading
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _aiBtn(
                  label: 'Importer',
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
                  ? 'Analyse en cours...'
                  : (hasPhoto
                      ? 'Analyser avec Gemini'
                      : 'Importe une photo pour analyser'),
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
                  decoration: _decoration(hint: 'Nom du vin...'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _aiDomaine,
                  style: AppText.sans(color: AppColors.text, fontSize: 13),
                  decoration: _decoration(hint: 'Domaine...'),
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
                  label: _aiLoading ? '...' : 'Chercher',
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

  // ---------------------------------------------------------------------------
  // Photo preview
  // ---------------------------------------------------------------------------

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
                    setState(() => _existingPhotoUrl = null);
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
              ? 'PHOTO PRETE — ENREGISTREE SUR LA FICHE'
              : 'PHOTO ACTUELLE DE LA FICHE',
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


  // ---------------------------------------------------------------------------
  // Helper widgets
  // ---------------------------------------------------------------------------

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
        return 'Rose';
      case WineType.orange:
        return 'Orange';
      case WineType.petillant:
        return 'Petillant';
    }
  }

  Widget _buildRatingSlider() {
    return _labeled(
      'Note de degustation (/100)',
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

  // ---------------------------------------------------------------------------
  // Critiques
  // ---------------------------------------------------------------------------

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
              'Aucune critique. Utilise Gemini pour les remplir automatiquement, ou ajoute-les manuellement.',
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
                      decoration: _decoration(hint: 'Note de degustation...'),
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
        ));
      });
    }

    sourceCtrl.dispose();
    scoreCtrl.dispose();
    noteCtrl.dispose();
  }
}
