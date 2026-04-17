import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/wine.dart';
import '../models/bottle.dart';
import '../services/cave_service.dart';
import '../services/storage_service.dart';
import '../services/gemini_service.dart';
import '../theme/app_text.dart';
import 'home_screen.dart' show AppColors;

Future<void> showAddWineDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => const AddWineDialog(),
  );
}

class AddWineDialog extends StatefulWidget {
  const AddWineDialog({super.key});

  @override
  State<AddWineDialog> createState() => _AddWineDialogState();
}

class _AddWineDialogState extends State<AddWineDialog> {
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

  BottleFormat _format = BottleFormat.ml750;
  int _quantity = 1;
  final _price = TextEditingController();
  final _marketValue = TextEditingController();
  final _purchaseYear = TextEditingController();
  BottleSource? _source;
  final List<TextEditingController> _locations = [TextEditingController()];

  final _drinkFrom = TextEditingController();
  final _drinkPeak = TextEditingController();
  final _drinkTo = TextEditingController();

  int? _rating;
  final _wineDescription = TextEditingController();
  final _domaineDescription = TextEditingController();

  bool _isGift = false;
  final _giftFrom = TextEditingController();
  final _giftOccasion = TextEditingController();
  DateTime? _giftDate;

  Uint8List? _photoBytes;
  String? _photoFileName;
  bool _saving = false;
  bool _aiLoading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _aiName, _aiDomaine, _aiVintage,
      _name, _vintage, _producer, _appellation,
      _country, _region, _climat, _domaine, _village, _domainAddress,
      _grapes, _alcohol,
      _price, _marketValue, _purchaseYear,
      _drinkFrom, _drinkPeak, _drinkTo,
      _wineDescription, _domaineDescription,
      _giftFrom, _giftOccasion,
      ..._locations,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncLocations(int qty) {
    setState(() {
      _quantity = qty;
      while (_locations.length < qty) {
        _locations.add(TextEditingController());
      }
      while (_locations.length > qty) {
        _locations.removeLast().dispose();
      }
    });
  }

  Future<void> _pickPhoto(ImageSource source, {bool analyzeWithGemini = false}) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photoBytes = bytes;
        _photoFileName = file.name;
      });
      if (analyzeWithGemini) {
        await _analyzePhotoWithGemini(bytes);
      }
    } catch (e) {
      setState(() => _error = 'Impossible de charger la photo : $e');
    }
  }

  Future<void> _analyzePhotoWithGemini(Uint8List bytes) async {
    setState(() {
      _aiLoading = true;
      _error = null;
    });
    try {
      final result = await GeminiService.searchByPhoto(bytes);
      if (!mounted) return;
      _applyGeminiResult(result);
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
      _wineDescription.text = result.wineDescription;
      _domaineDescription.text = result.domaineDescription;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final locations = _locations.map((c) => c.text.trim()).toList();
    final filledLocations = locations.where((l) => l.isNotEmpty).toList();
    if (filledLocations.toSet().length != filledLocations.length) {
      setState(() => _error = 'Deux bouteilles ne peuvent pas partager un emplacement.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      for (final loc in filledLocations) {
        if (await CaveService.isLocationTaken(loc)) {
          setState(() {
            _saving = false;
            _error = 'L\'emplacement "$loc" est déjà occupé.';
          });
          return;
        }
      }

      String? photoUrl;
      if (_photoBytes != null) {
        photoUrl = await StorageService.uploadWinePhoto(
          bytes: _photoBytes!,
          fileName: _photoFileName ?? 'wine.jpg',
        );
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
        createdAt: now,
      );

      final price = double.tryParse(_price.text.replaceAll(',', '.'));
      final market = double.tryParse(_marketValue.text.replaceAll(',', '.'));
      final year = int.tryParse(_purchaseYear.text);

      final bottles = locations.map((loc) => Bottle(
            id: '',
            wineId: '',
            location: loc,
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
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.gold,
          content: Text(
            '${wine.name} ajouté ($_quantity bouteille${_quantity > 1 ? 's' : ''})',
            style: const TextStyle(color: Color(0xFF1A1408)),
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
            'Ajouter un vin',
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
                : Text('Enregistrer',
                    style: AppText.sans(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _aiBar(),
        const SizedBox(height: 14),
        _photoZone(),
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
        _single(_field('🍷 Description du vin', _wineDescription,
            maxLines: 5, hint: 'Robe, arômes, bouche, structure, finale…')),
        const SizedBox(height: 10),
        _single(_field('🏰 Description du domaine', _domaineDescription,
            maxLines: 4, hint: 'Histoire, philosophie, terroir, réputation…')),

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
      _dropdownContainer(
        DropdownButton<BottleSource?>(
          value: _source,
          isExpanded: true,
          dropdownColor: AppColors.bg2,
          hint: Text('Choisir…',
              style: AppText.sans(color: AppColors.text3, fontSize: 13)),
          style: AppText.sans(color: AppColors.text, fontSize: 13),
          items: [
            DropdownMenuItem<BottleSource?>(
              value: null,
              child: Text('—', style: AppText.sans(color: AppColors.text3, fontSize: 13)),
            ),
            ...BottleSource.values.map((s) =>
                DropdownMenuItem(value: s, child: Text(s.label))),
          ],
          onChanged: (v) => setState(() => _source = v),
        ),
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
      'Emplacements cave (un par bouteille, ex: 1-A3)',
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(_locations.length, (i) {
          return SizedBox(
            width: 120,
            child: TextField(
              controller: _locations[i],
              style: AppText.sans(color: AppColors.text, fontSize: 13),
              decoration: _decoration(hint: 'Bout. ${i + 1}'),
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
            Text('🎁 Ce vin est un cadeau',
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

  Widget _aiBar() {
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
          Text(
            'RECHERCHE RAPIDE (IA)',
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 10,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 10),
          Row(
            children: [
              _aiBtn(
                label: _aiLoading ? '⏳ Analyse…' : '✶ Gemini',
                primary: true,
                onTap: _aiLoading ? null : _searchWithGemini,
              ),
              const SizedBox(width: 8),
              _aiBtn(label: '📷 Photo', onTap: () => _pickPhoto(ImageSource.camera, analyzeWithGemini: true)),
              const SizedBox(width: 8),
              _aiBtn(label: '🖼 Galerie', onTap: () => _pickPhoto(ImageSource.gallery, analyzeWithGemini: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aiBtn({required String label, VoidCallback? onTap, bool primary = false}) {
    return Material(
      color: primary ? AppColors.gold : AppColors.bg2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary ? AppColors.gold : AppColors.border2),
          ),
          child: Text(
            label,
            style: AppText.sans(
              color: primary ? const Color(0xFF1A1408) : AppColors.text2,
              fontSize: 12,
              fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoZone() {
    return InkWell(
      onTap: () => _pickPhoto(ImageSource.gallery),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border2, width: 2),
        ),
        child: _photoBytes == null
            ? Column(
                children: [
                  Text('📸', style: AppText.emoji(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text(
                    'Cliquer pour ajouter une photo de l\'étiquette',
                    style: AppText.sans(color: AppColors.text3, fontSize: 12),
                  ),
                ],
              )
            : Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_photoBytes!, height: 160, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 8),
                  Text('Cliquer pour changer',
                      style: AppText.sans(color: AppColors.text3, fontSize: 11)),
                ],
              ),
      ),
    );
  }
}
