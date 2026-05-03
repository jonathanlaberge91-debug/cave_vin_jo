import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class CellarFormResult {
  final int number;
  final String name;
  final int cols;
  final int rows;
  const CellarFormResult({
    required this.number,
    required this.name,
    required this.cols,
    required this.rows,
  });
}

class CellarFormDialog extends StatefulWidget {
  final String title;
  final int initialNumber;
  final String initialName;
  final int initialCols;
  final int initialRows;

  const CellarFormDialog({
    super.key,
    required this.title,
    required this.initialNumber,
    required this.initialName,
    required this.initialCols,
    required this.initialRows,
  });

  @override
  State<CellarFormDialog> createState() => _CellarFormDialogState();
}

class _CellarFormDialogState extends State<CellarFormDialog> {
  late final TextEditingController _number;
  late final TextEditingController _name;
  late final TextEditingController _cols;
  late final TextEditingController _rows;

  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: '${widget.initialNumber}');
    _name = TextEditingController(text: widget.initialName);
    _cols = TextEditingController(text: '${widget.initialCols}');
    _rows = TextEditingController(text: '${widget.initialRows}');
  }

  @override
  void dispose() {
    _number.dispose();
    _name.dispose();
    _cols.dispose();
    _rows.dispose();
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

  Widget _field({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    VoidCallback? onChanged,
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
