import 'package:flutter/material.dart';
import '../models/bottle.dart';
import '../models/cellar.dart';
import '../services/cave_service.dart';
import '../services/cellar_service.dart';
import '../theme/app_text.dart';
import '../theme/app_colors.dart';

class SlotSelection {
  final String cellarId;
  final int cellarNumber;
  final int col;
  final int row;
  final String label;

  const SlotSelection({
    required this.cellarId,
    required this.cellarNumber,
    required this.col,
    required this.row,
    required this.label,
  });

  String get slotKey => '$cellarId::$row::$col';
}

Future<SlotSelection?> pickSlot(
  BuildContext context, {
  Set<String> reservedKeys = const {},
  SlotSelection? initial,
}) {
  return showDialog<SlotSelection>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _SlotPickerDialog(
      reservedKeys: reservedKeys,
      initial: initial,
    ),
  );
}

class _SlotPickerDialog extends StatefulWidget {
  final Set<String> reservedKeys;
  final SlotSelection? initial;

  const _SlotPickerDialog({
    required this.reservedKeys,
    this.initial,
  });

  @override
  State<_SlotPickerDialog> createState() => _SlotPickerDialogState();
}

class _SlotPickerDialogState extends State<_SlotPickerDialog> {
  String? _cellarId;
  SlotSelection? _selection;

  @override
  void initState() {
    super.initState();
    _cellarId = widget.initial?.cellarId;
    _selection = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxWidth = size.width > 900 ? 820.0 : size.width - 32;
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
          ),
          child: StreamBuilder<List<Cellar>>(
            stream: CellarService.watch(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                );
              }
              final cellars = snap.data ?? [];
              if (cellars.isEmpty) return _emptyState();

              if (_cellarId == null ||
                  !cellars.any((c) => c.id == _cellarId)) {
                _cellarId = cellars.first.id;
                _selection = null;
              }
              final selectedCellar =
                  cellars.firstWhere((c) => c.id == _cellarId);

              return Column(
                children: [
                  _header(),
                  _cellarTabs(cellars, selectedCellar),
                  Expanded(child: _grid(selectedCellar)),
                  _footer(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.grid_view_rounded, size: 48, color: AppColors.text3),
          const SizedBox(height: 14),
          Text(
            'Aucun cellier',
            style: AppText.serif(color: AppColors.text2, fontSize: 22),
          ),
          const SizedBox(height: 6),
          Text(
            'Crée d\'abord un cellier dans la section « Cellier ».',
            style: AppText.sans(color: AppColors.text3, fontSize: 12),
          ),
          const SizedBox(height: 18),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer',
                style: AppText.sans(color: AppColors.text2, fontSize: 13)),
          ),
        ],
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
            'Choisir une case',
            style: AppText.serif(
              color: AppColors.gold2,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_selection != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x1FC9A84C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x40C9A84C)),
              ),
              child: Text(
                _selection!.label,
                style: AppText.sans(
                  color: AppColors.gold2,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: AppColors.text3),
          ),
        ],
      ),
    );
  }

  Widget _cellarTabs(List<Cellar> cellars, Cellar selected) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: cellars.length,
        itemBuilder: (context, i) {
          final c = cellars[i];
          final active = c.id == selected.id;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() {
                _cellarId = c.id;
                if (_selection?.cellarId != c.id) _selection = null;
              }),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? const Color(0x1FC9A84C) : AppColors.bg3,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: active ? AppColors.gold : AppColors.border,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  c.name.isEmpty
                      ? 'Cellier ${c.number}'
                      : 'N°${c.number} · ${c.name}',
                  style: AppText.sans(
                    color: active ? AppColors.gold2 : AppColors.text2,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Un flux par cellier, cree une seule fois (et non a chaque rebuild).
  final Map<String, Stream<List<Bottle>>> _cellarStreams = {};

  Widget _grid(Cellar c) {
    final stream = _cellarStreams.putIfAbsent(
      c.id,
      () => CaveService.bottlesByCellar(c.id),
    );
    return StreamBuilder<List<Bottle>>(
      stream: stream,
      builder: (context, snap) {
        final bottles = snap.data ?? [];
        final occupied = <String, Bottle>{};
        for (final b in bottles) {
          if (b.slotCol == null || b.slotRow == null) continue;
          occupied['${b.slotRow}::${b.slotCol}'] = b;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const labelW = 28.0;
              const headerH = 22.0;
              const gap = 4.0;
              final availW = constraints.maxWidth - labelW;
              final availH = constraints.maxHeight - headerH;
              final cellW = (availW - gap * (c.cols - 1)) / c.cols;
              final cellH = (availH - gap * (c.rows - 1)) / c.rows;
              final cellSize = (cellW < cellH ? cellW : cellH).clamp(16.0, 44.0);

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: labelW),
                        for (var col = 0; col < c.cols; col++) ...[
                          SizedBox(
                            width: cellSize,
                            height: headerH,
                            child: Center(
                              child: Text(
                                '${col + 1}',
                                style: AppText.sans(
                                  color: AppColors.text3,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (col < c.cols - 1) const SizedBox(width: gap),
                        ],
                      ],
                    ),
                    for (var row = 0; row < c.rows; row++) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: labelW,
                            height: cellSize,
                            child: Center(
                              child: Text(
                                formatRowLetter(row),
                                style: AppText.sans(
                                  color: AppColors.text3,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          for (var col = 0; col < c.cols; col++) ...[
                            _buildCell(c, row, col, cellSize, occupied),
                            if (col < c.cols - 1) const SizedBox(width: gap),
                          ],
                        ],
                      ),
                      if (row < c.rows - 1) const SizedBox(height: gap),
                    ],
                    const SizedBox(height: 12),
                    _legend(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCell(
    Cellar c,
    int row,
    int col,
    double size,
    Map<String, Bottle> occupied,
  ) {
    final key = '$row::$col';
    final isOccupied = occupied.containsKey(key);
    final reservedKey = '${c.id}::$row::$col';
    final isReserved =
        widget.reservedKeys.contains(reservedKey) && !_isMyInitial(c.id, row, col);
    final isSelected = _selection?.cellarId == c.id &&
        _selection?.row == row &&
        _selection?.col == col;
    final disabled = isOccupied || isReserved;

    Color bg;
    Color border;
    if (isSelected) {
      bg = const Color(0x33C9A84C);
      border = AppColors.gold;
    } else if (isOccupied) {
      bg = const Color(0x33B23A48);
      border = const Color(0x66B23A48);
    } else if (isReserved) {
      bg = const Color(0x33E8C97A);
      border = const Color(0x66E8C97A);
    } else {
      bg = AppColors.bg3;
      border = AppColors.border;
    }

    final label = formatFullSlotLabel(c.number, row, col);
    final tip = isOccupied
        ? '$label · occupé'
        : isReserved
            ? '$label · réservé'
            : label;

    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: disabled
            ? null
            : () => setState(() {
                  _selection = SlotSelection(
                    cellarId: c.id,
                    cellarNumber: c.number,
                    col: col,
                    row: row,
                    label: label,
                  );
                }),
        borderRadius: BorderRadius.circular(3),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: border),
          ),
        ),
      ),
    );
  }

  bool _isMyInitial(String cellarId, int row, int col) {
    final init = widget.initial;
    if (init == null) return false;
    return init.cellarId == cellarId && init.row == row && init.col == col;
  }

  Widget _legend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _legendDot(AppColors.bg3, AppColors.border, 'Disponible'),
        _legendDot(const Color(0x33C9A84C), AppColors.gold, 'Sélectionnée'),
        _legendDot(
            const Color(0x33B23A48), const Color(0x66B23A48), 'Occupée'),
        _legendDot(
            const Color(0x33E8C97A), const Color(0x66E8C97A), 'Réservée'),
      ],
    );
  }

  Widget _legendDot(Color bg, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppText.sans(color: AppColors.text3, fontSize: 11),
        ),
      ],
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
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
                style: AppText.sans(color: AppColors.text2, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _selection == null
                ? null
                : () => Navigator.pop(context, _selection),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF1A1408),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              disabledBackgroundColor: AppColors.bg3,
              disabledForegroundColor: AppColors.text3,
            ),
            child: Text(
              'Confirmer',
              style: AppText.sans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
