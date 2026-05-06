import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/govee_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class CellarFormResult {
  final int number;
  final String name;
  final int cols;
  final int rows;
  final String? goveeTopDevice;
  final String? goveeBottomDevice;
  final String? tuyaDeviceId;
  const CellarFormResult({
    required this.number,
    required this.name,
    required this.cols,
    required this.rows,
    this.goveeTopDevice,
    this.goveeBottomDevice,
    this.tuyaDeviceId,
  });
}

class CellarFormDialog extends StatefulWidget {
  final String title;
  final int initialNumber;
  final String initialName;
  final int initialCols;
  final int initialRows;
  final String? initialGoveeTop;
  final String? initialGoveeBottom;
  final String? initialTuyaDeviceId;
  final List<GoveeSensor> goveeSensors;

  const CellarFormDialog({
    super.key,
    required this.title,
    required this.initialNumber,
    required this.initialName,
    required this.initialCols,
    required this.initialRows,
    this.initialGoveeTop,
    this.initialGoveeBottom,
    this.initialTuyaDeviceId,
    this.goveeSensors = const [],
  });

  @override
  State<CellarFormDialog> createState() => _CellarFormDialogState();
}

class _CellarFormDialogState extends State<CellarFormDialog> {
  late final TextEditingController _number;
  late final TextEditingController _name;
  late final TextEditingController _cols;
  late final TextEditingController _rows;
  late final TextEditingController _tuyaDeviceId;
  String? _goveeTop;
  String? _goveeBottom;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: '${widget.initialNumber}');
    _name = TextEditingController(text: widget.initialName);
    _cols = TextEditingController(text: '${widget.initialCols}');
    _rows = TextEditingController(text: '${widget.initialRows}');
    _tuyaDeviceId = TextEditingController(text: widget.initialTuyaDeviceId ?? '');
    _goveeTop = widget.initialGoveeTop;
    _goveeBottom = widget.initialGoveeBottom;
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _cols.dispose();
    _rows.dispose();
    _tuyaDeviceId.dispose();
    super.dispose();
  }

  int get _colsValue => int.tryParse(_cols.text.trim()) ?? 0;
  int get _rowsValue => int.tryParse(_rows.text.trim()) ?? 0;
  int get _total => _colsValue * _rowsValue;

  void _submit() {
    final number = int.tryParse(_number.text.trim());
    final cols = _colsValue;
    final rows = _rowsValue;
    if (number == null || number < 1) {
      _err('Numéro invalide.');
      return;
    }
    if (cols < 1 || cols > 50) {
      _err('Largeur entre 1 et 50.');
      return;
    }
    if (rows < 1 || rows > 100) {
      _err('Hauteur entre 1 et 100.');
      return;
    }
    Navigator.pop(
      context,
      CellarFormResult(
        number: number,
        name: _name.text.trim(),
        cols: cols,
        rows: rows,
        goveeTopDevice: _goveeTop,
        goveeBottomDevice: _goveeBottom,
        tuyaDeviceId: _tuyaDeviceId.text.trim().isEmpty ? null : _tuyaDeviceId.text.trim(),
      ),
    );
  }

  void _err(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF6E2A20),
        content: Text(m, style: AppText.sans(color: AppColors.text)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: AppText.serif(
                color: AppColors.gold2,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _field(
                    label: 'NUMÉRO',
                    controller: _number,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 5,
                  child: _field(label: 'NOM (OPTIONNEL)', controller: _name),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _field(
                    label: 'LARGEUR (COLONNES)',
                    controller: _cols,
                    keyboardType: TextInputType.number,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    label: 'HAUTEUR (RANGÉES)',
                    controller: _rows,
                    keyboardType: TextInputType.number,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                _total > 0
                    ? 'Total : $_total cases'
                    : 'Total : —',
                style: AppText.sans(
                  color: AppColors.gold2,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'TUYA IOT',
              style: AppText.sans(
                color: AppColors.text3,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            _field(
              label: 'DEVICE ID',
              controller: _tuyaDeviceId,
              hint: 'ex: eb103f9b9dda5093b8k8ae',
            ),
            const SizedBox(height: 14),
            Text(
              'CAPTEURS GOVEE',
              style: AppText.sans(
                color: AppColors.text3,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            if (widget.goveeSensors.isEmpty)
              Text(
                'Aucun capteur détecté. Configure ta clé API Govee dans Paramètres > Clés API.',
                style: AppText.sans(color: AppColors.text3, fontSize: 11),
              ),
            if (widget.goveeSensors.isNotEmpty)
              _goveePicker(
                label: '▲ Haut',
                value: _goveeTop,
                onChanged: (v) => setState(() => _goveeTop = v),
              ),
            if (widget.goveeSensors.isNotEmpty)
              const SizedBox(height: 8),
            if (widget.goveeSensors.isNotEmpty)
              _goveePicker(
                label: '▼ Bas',
                value: _goveeBottom,
                onChanged: (v) => setState(() => _goveeBottom = v),
              ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Annuler',
                    style: AppText.sans(color: AppColors.text2, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF1A1408),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Enregistrer',
                    style: AppText.sans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static double? _goveeTemp(double? raw) {
    if (raw == null) return null;
    if (raw > 1000) return raw / 100;
    if (raw > 45) return (raw - 32) * 5 / 9;
    return raw;
  }

  Widget _goveePicker({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            '$label — Aucun',
            style: AppText.sans(color: AppColors.text3, fontSize: 12),
          ),
          dropdownColor: AppColors.bg2,
          icon: const Icon(Icons.expand_more, size: 18, color: AppColors.text3),
          items: [
            DropdownMenuItem<String>(
              value: '',
              child: Text(
                '$label — Aucun',
                style: AppText.sans(color: AppColors.text3, fontSize: 12),
              ),
            ),
            for (final s in widget.goveeSensors)
              DropdownMenuItem<String>(
                value: s.device,
                child: Row(
                  children: [
                    Text(
                      '$label  ',
                      style: AppText.sans(color: AppColors.text3, fontSize: 11),
                    ),
                    Expanded(
                      child: Text(
                        s.name,
                        style: AppText.sans(color: AppColors.text, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (s.temperature != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${_goveeTemp(s.temperature)?.toStringAsFixed(1)}°C',
                        style: AppText.sans(
                          color: AppColors.gold2,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
          onChanged: (v) => onChanged(v == null || v.isEmpty ? null : v),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    VoidCallback? onChanged,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.sans(
            color: AppColors.text3,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: keyboardType == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          onChanged: onChanged != null ? (_) => onChanged() : null,
          style: AppText.sans(color: AppColors.text, fontSize: 13),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: AppColors.bg3,
            hintText: hint,
            hintStyle: AppText.sans(color: AppColors.text3, fontSize: 12),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          ),
        ),
      ],
    );
  }
}
