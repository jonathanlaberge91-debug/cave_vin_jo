import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bottle.dart';
import '../models/cellar.dart';
import '../models/wine.dart';
import '../services/cave_preferences_service.dart';
import '../services/cave_service.dart';
import '../services/cellar_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/wine_type_helpers.dart';
import '../widgets/cave_table.dart' show GardeInfo;
import '../widgets/native_image.dart';
import '../dialogs/cellar_form_dialog.dart';
import 'slot_picker.dart';
import 'wine_cellar_screen.dart' show CellarStatus;
import 'wine_detail_screen.dart';

double _cellSizeFromZoom(int zoom) => 14.0 + (zoom - 1) * 3.5;

class CellierScreen extends StatefulWidget {
  const CellierScreen({super.key});

  @override
  State<CellierScreen> createState() => _CellierScreenState();
}

class _CellierScreenState extends State<CellierScreen> {
  final _isDragging = ValueNotifier<bool>(false);
  List<CellarStatus>? _physical;
  String _bridgeUrl = 'http://localhost:8765';
  Timer? _bridgeTimer;
  final Set<int> _sending = {};

  @override
  void initState() {
    super.initState();
    _loadBridge();
  }

  @override
  void dispose() {
    _bridgeTimer?.cancel();
    _isDragging.dispose();
    super.dispose();
  }

  Future<void> _loadBridge() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('wine_cellr_bridge_url');
    if (saved != null && saved.isNotEmpty) _bridgeUrl = saved;
    _fetchBridge();
    _bridgeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchBridge());
  }

  Future<void> _fetchBridge() async {
    try {
      final res = await http.get(Uri.parse('$_bridgeUrl/status-all')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => CellarStatus.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() => _physical = list);
      }
    } catch (_) {}
  }

  Future<void> _sendDps(int idx, String dps, dynamic value) async {
    if (_sending.contains(idx)) return;
    setState(() => _sending.add(idx));
    try {
      await http.post(
        Uri.parse('$_bridgeUrl/set/$idx'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'dps': dps, 'value': value}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
    if (mounted) setState(() => _sending.remove(idx));
    _fetchBridge();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cellar>>(
      stream: CellarService.watch(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          );
        }
        final cellars = snap.data ?? [];
        final isMobile = MediaQuery.of(context).size.width < 600;

        if (isMobile) return _buildMobileLayout(cellars);
        return _buildDesktopLayout(cellars);
      },
    );
  }

  Widget _buildDesktopLayout(List<Cellar> cellars) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildHeader(cellars),
                  if (cellars.isEmpty)
                    Expanded(child: _buildEmpty())
                  else
                    Expanded(child: _buildAllCellars(cellars)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 480,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bg2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: _buildUnplacedBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(List<Cellar> cellars) {
    return Column(
      children: [
        Expanded(
          child: cellars.isEmpty
              ? _buildEmpty()
              : _buildMobileCellars(cellars),
        ),
        _MobileUnplacedPanel(
          isDragging: _isDragging,
          onChipTap: _onChipTap,
          onOpenDetail: _openWineDetail,
        ),
      ],
    );
  }

  Widget _buildMobileCellars(List<Cellar> cellars) {
    return ValueListenableBuilder<int>(
      valueListenable: CavePreferencesService.cellarZoom,
      builder: (context, zoom, _) {
        final cellSize = _cellSizeFromZoom(zoom);
        return StreamBuilder<List<Wine>>(
          stream: CaveService.wines(),
          builder: (context, winesSnap) {
            final wines = winesSnap.data ?? [];
            final winesById = {for (final w in wines) w.id: w};

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: cellars.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) return _buildMobileAddCellarBtn(cellars);
                final c = cellars[i - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildMobileCellarCard(c, winesById, cellSize, cellarIndex: i - 1),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMobileAddCellarBtn(List<Cellar> cellars) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            '${cellars.length} cellier${cellars.length > 1 ? 's' : ''}',
            style: AppText.sans(color: AppColors.text3, fontSize: 12),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _onCreate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 14, color: AppColors.gold),
                  const SizedBox(width: 4),
                  Text('Ajouter', style: AppText.sans(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCellarCard(Cellar c, Map<String, Wine> winesById, double cellSize, {int cellarIndex = -1}) {
    return StreamBuilder<List<Bottle>>(
      stream: CaveService.bottlesByCellar(c.id),
      builder: (context, bottlesSnap) {
        final bottles = bottlesSnap.data ?? [];
        final occupied = <String, Bottle>{};
        final anchors = <String, Bottle>{};
        for (final b in bottles) {
          if (b.slotCol == null || b.slotRow == null) continue;
          final span = b.format.slotSpan;
          anchors['${b.slotRow}::${b.slotCol}'] = b;
          for (var s = 0; s < span; s++) {
            occupied['${b.slotRow}::${b.slotCol! + s}'] = b;
          }
        }
        final occupiedCount = anchors.length;
        final status = _physical != null && cellarIndex >= 0 && cellarIndex < _physical!.length ? _physical![cellarIndex] : null;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.name.isEmpty ? 'Cellier ${c.number}' : c.name,
                        style: AppText.serif(
                          color: AppColors.gold2,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (status != null) _buildTempControls(status, cellarIndex),
                    if (status != null) const SizedBox(width: 10),
                    Text(
                      '$occupiedCount/${c.totalSlots}',
                      style: AppText.sans(color: AppColors.text3, fontSize: 11),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: _buildGridStatic(c, occupied, winesById, cellSize: cellSize, anchors: anchors),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllCellars(List<Cellar> cellars) {
    return ValueListenableBuilder<int>(
      valueListenable: CavePreferencesService.cellarZoom,
      builder: (context, zoom, _) {
        final cellSize = _cellSizeFromZoom(zoom);
        return StreamBuilder<List<Wine>>(
          stream: CaveService.wines(),
          builder: (context, winesSnap) {
            final wines = winesSnap.data ?? [];
            final winesById = {for (final w in wines) w.id: w};

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(20),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cellars.length; i++) ...[
                      SizedBox(
                        width: _cardWidth(cellars[i], cellSize),
                        child: _buildCellarCard(cellars[i], winesById, cellSize, cellarIndex: i),
                      ),
                      if (i < cellars.length - 1) const SizedBox(width: 20),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  double _cardWidth(Cellar c, double cellSize) {
    const gap = 1.0;
    const labelW = 24.0;
    const padding = 18.0 + 14.0;
    final gridW = labelW + cellSize * c.cols + gap * (c.cols - 1);
    const minW = 280.0;
    return (gridW + padding).clamp(minW, 2400.0);
  }

  Widget _buildCellarCard(Cellar c, Map<String, Wine> winesById, double cellSize, {int cellarIndex = -1}) {
    return StreamBuilder<List<Bottle>>(
      stream: CaveService.bottlesByCellar(c.id),
      builder: (context, bottlesSnap) {
        final bottles = bottlesSnap.data ?? [];
        final occupied = <String, Bottle>{};
        final anchors = <String, Bottle>{};
        for (final b in bottles) {
          if (b.slotCol == null || b.slotRow == null) continue;
          final span = b.format.slotSpan;
          anchors['${b.slotRow}::${b.slotCol}'] = b;
          for (var s = 0; s < span; s++) {
            occupied['${b.slotRow}::${b.slotCol! + s}'] = b;
          }
        }
        final occupiedCount = anchors.length;
        final freeCount = c.totalSlots - occupiedCount;
        final status = _physical != null && cellarIndex >= 0 && cellarIndex < _physical!.length ? _physical![cellarIndex] : null;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 12),
                child: Row(
                  children: [
                    Text(
                      c.name.isEmpty ? 'Cellier ${c.number}' : c.name,
                      style: AppText.serif(
                        color: AppColors.gold2,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (status != null) _buildTempControls(status, cellarIndex),
                    if (status != null) const SizedBox(width: 10),
                    Text(
                      '$occupiedCount/${c.totalSlots} bouteilles',
                      style: AppText.sans(
                        color: AppColors.text3,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: _buildGridStatic(c, occupied, winesById, cellSize: cellSize, anchors: anchors),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTempControls(CellarStatus status, int idx) {
    final isCelsius = status.tempUnit == 'c';
    final current = isCelsius ? status.currentTemp : status.currentTempF;
    final target = isCelsius ? status.targetTemp : status.targetTempF;
    final unit = isCelsius ? '°C' : '°F';
    final busy = _sending.contains(idx);
    final dps = isCelsius ? '2' : '104';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$current$unit', style: AppText.sans(color: AppColors.text2, fontSize: 11)),
        const SizedBox(width: 8),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: busy ? null : () => _sendDps(idx, dps, target - 1),
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border2),
              ),
              child: const Icon(Icons.remove, size: 12, color: AppColors.text2),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('$target$unit', style: AppText.sans(color: AppColors.gold2, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: busy ? null : () => _sendDps(idx, dps, target + 1),
            child: Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border2),
              ),
              child: const Icon(Icons.add, size: 12, color: AppColors.text2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridStatic(
    Cellar c,
    Map<String, Bottle> occupied,
    Map<String, Wine> winesById, {
    required double cellSize,
    Map<String, Bottle>? anchors,
  }) {
    final anchorMap = anchors ?? occupied;
    return LayoutBuilder(
      builder: (context, constraints) {
        const labelW = 24.0;
        const headerH = 18.0;
        const gap = 1.0;

        return Column(
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
                          fontSize: 8,
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
              _buildGridRow(
                c: c, row: row, cellSize: cellSize, gap: gap, labelW: labelW,
                occupied: occupied, anchorMap: anchorMap, winesById: winesById,
              ),
              if (row < c.rows - 1) const SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }

  Widget _buildGridRow({
    required Cellar c,
    required int row,
    required double cellSize,
    required double gap,
    required double labelW,
    required Map<String, Bottle> occupied,
    required Map<String, Bottle> anchorMap,
    required Map<String, Wine> winesById,
  }) {
    final children = <Widget>[
      SizedBox(
        width: labelW,
        height: cellSize,
        child: Center(
          child: Text(
            formatRowLetter(row),
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ];

    var col = 0;
    while (col < c.cols) {
      if (col > 0) children.add(SizedBox(width: gap));

      final currentCol = col;
      final key = '$row::$currentCol';
      final anchor = anchorMap[key];

      if (anchor != null) {
        final span = anchor.format.slotSpan;
        final w = cellSize * span + gap * (span - 1);
        children.add(
          _SlotCell(
            size: cellSize,
            spanWidth: w,
            span: span,
            label: formatFullSlotLabel(c.number, row, currentCol),
            shortLabel: '${formatRowLetter(row)}${currentCol + 1}',
            bottle: anchor,
            wine: winesById[anchor.wineId],
            isDragging: _isDragging,
            totalCols: c.cols,
            onTapWine: (wine, b) => _openWineDetail(wine, b),
            onDrop: (dropped) =>
                _onDropOnSlot(dropped, c, row, currentCol, occupied),
          ),
        );
        col += span;
      } else if (occupied[key] != null) {
        col++;
      } else {
        children.add(
          _SlotCell(
            size: cellSize,
            label: formatFullSlotLabel(c.number, row, currentCol),
            shortLabel: '${formatRowLetter(row)}${currentCol + 1}',
            isDragging: _isDragging,
            totalCols: c.cols,
            onDrop: (dropped) =>
                _onDropOnSlot(dropped, c, row, currentCol, occupied),
          ),
        );
        col++;
      }
    }

    return Row(children: children);
  }

  Future<void> _openWineDetail(Wine wine, Bottle bottle) async {
    final allBottles = await CaveService.bottlesInCave().first;
    final wineBottles =
        allBottles.where((b) => b.wineId == wine.id).toList();
    if (!mounted) return;
    showWineDetail(context, wine: wine, bottles: wineBottles);
  }

  Widget _buildUnplacedBar() {
    return StreamBuilder<List<Bottle>>(
      stream: CaveService.unplacedBottlesInCave(),
      builder: (context, bottlesSnap) {
        final bottles = bottlesSnap.data ?? [];
        return StreamBuilder<List<Wine>>(
          stream: CaveService.wines(),
          builder: (context, winesSnap) {
            final winesById = {
              for (final w in winesSnap.data ?? <Wine>[]) w.id: w
            };
            final grouped = <String, List<Bottle>>{};
            for (final b in bottles) {
              final key = '${b.wineId}::${b.format.name}';
              grouped.putIfAbsent(key, () => []).add(b);
            }
            final groups = grouped.values.toList();

            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                    child: Row(
                      children: [
                        Text(
                          'À PLACER',
                          style: AppText.sans(
                            color: AppColors.text3,
                            fontSize: 11,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bg3,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border2),
                          ),
                          child: Text(
                            '${bottles.length}',
                            style: AppText.sans(
                              color: AppColors.text2,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (bottles.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Toutes les bouteilles sont placées.',
                          style: AppText.sans(
                            color: AppColors.text3,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    const _UnplacedHeader(),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: groups.length,
                        itemBuilder: (context, i) {
                          final group = groups[i];
                          final first = group.first;
                          final w = winesById[first.wineId];
                          return _UnplacedRow(
                            bottles: group,
                            wine: w,
                            isDragging: _isDragging,
                            onTap: () => _onChipTap(first, w),
                            onOpenDetail: w != null
                                ? () => _openWineDetail(w, first)
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                ],
              );
          },
        );
      },
    );
  }

  Future<void> _onDropOnSlot(
    Bottle dropped,
    Cellar c,
    int row,
    int col,
    Map<String, Bottle> occupied,
  ) async {
    final span = dropped.format.slotSpan;

    if (col + span > c.cols) {
      _showError('Pas assez de place sur cette rangée.');
      return;
    }

    for (var s = 0; s < span; s++) {
      final key = '$row::${col + s}';
      final existing = occupied[key];
      if (existing != null && existing.id != dropped.id) {
        if (span > 1 || existing.format.slotSpan > 1) {
          _showError('Une ou plusieurs cases sont déjà occupées.');
          return;
        }
        if (dropped.slotRow == null || dropped.slotCol == null ||
            existing.slotRow == null || existing.slotCol == null) {
          _showError('Cette case est déjà occupée.');
          return;
        }
        await CaveService.swapSlots(
          a: dropped,
          b: existing,
          cellarNumber: c.number,
        );
        return;
      }
    }

    await CaveService.assignSlot(
      bottleId: dropped.id,
      cellarId: c.id,
      cellarNumber: c.number,
      col: col,
      row: row,
    );
  }

  Future<void> _onChipTap(Bottle b, Wine? w) async {
    final selection = await pickSlot(context);
    if (selection == null) return;
    final taken = await CaveService.isSlotTaken(
      cellarId: selection.cellarId,
      slotCol: selection.col,
      slotRow: selection.row,
    );
    if (!mounted) return;
    if (taken) {
      _showError('La case ${selection.label} est déjà occupée.');
      return;
    }
    await CaveService.assignSlot(
      bottleId: b.id,
      cellarId: selection.cellarId,
      cellarNumber: selection.cellarNumber,
      col: selection.col,
      row: selection.row,
    );
  }

  Widget _buildHeader(List<Cellar> cellars) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            'Celliers',
            style: AppText.serif(
              color: AppColors.gold2,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border2),
            ),
            child: Text(
              '${cellars.length}',
              style: AppText.sans(
                color: AppColors.text2,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          _ctaButton('+ Nouveau cellier', onTap: _onCreate),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
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
              'Crée ton premier cellier pour organiser tes bouteilles.',
              style: AppText.sans(color: AppColors.text3, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCreate() async {
    final next = await CellarService.nextNumber();
    if (!mounted) return;
    final result = await showDialog<CellarFormResult>(
      context: context,
      builder: (_) => CellarFormDialog(
        title: 'Nouveau cellier',
        initialNumber: next,
        initialName: '',
        initialCols: 10,
        initialRows: 20,
      ),
    );
    if (result == null) return;
    final taken = await CellarService.isNumberTaken(result.number);
    if (!mounted) return;
    if (taken) {
      _showError('Le numéro ${result.number} est déjà utilisé.');
      return;
    }
    await CellarService.add(
      number: result.number,
      name: result.name,
      cols: result.cols,
      rows: result.rows,
    );
  }

  Future<void> _onEdit(Cellar c) async {
    final result = await showDialog<CellarFormResult>(
      context: context,
      builder: (_) => CellarFormDialog(
        title: 'Modifier le cellier',
        initialNumber: c.number,
        initialName: c.name,
        initialCols: c.cols,
        initialRows: c.rows,
      ),
    );
    if (result == null) return;
    if (result.number != c.number) {
      final taken = await CellarService.isNumberTaken(
        result.number,
        exceptId: c.id,
      );
      if (!mounted) return;
      if (taken) {
        _showError('Le numéro ${result.number} est déjà utilisé.');
        return;
      }
    }
    await CellarService.update(
      c.id,
      number: result.number,
      name: result.name,
      cols: result.cols,
      rows: result.rows,
    );
  }

  Future<void> _onDelete(Cellar c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: Text(
          'Supprimer le cellier ?',
          style: AppText.serif(color: AppColors.gold2, fontSize: 18),
        ),
        content: Text(
          'Le cellier ${c.number}${c.name.isEmpty ? '' : ' (${c.name})'} sera supprimé. Cette action est irréversible.',
          style: AppText.sans(color: AppColors.text2, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler',
                style: AppText.sans(color: AppColors.text2, fontSize: 13)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Supprimer',
                style: AppText.sans(
                    color: const Color(0xFFE07060),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await CellarService.delete(c.id);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF6E2A20),
        content: Text(msg, style: AppText.sans(color: AppColors.text)),
      ),
    );
  }

  Widget _ctaButton(String label, {required VoidCallback onTap}) {
    return Material(
      color: AppColors.gold,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: AppText.sans(
              color: const Color(0xFF1A1408),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallButton(String label,
      {required VoidCallback onTap, bool danger = false}) {
    final color = danger ? const Color(0xFFE07060) : AppColors.text2;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border2),
        ),
        child: Text(
          label,
          style: AppText.sans(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SlotCell extends StatefulWidget {
  final double size;
  final double? spanWidth;
  final int span;
  final int totalCols;
  final String label;
  final String shortLabel;
  final Bottle? bottle;
  final Wine? wine;
  final ValueNotifier<bool> isDragging;
  final void Function(Wine wine, Bottle bottle)? onTapWine;
  final void Function(Bottle bottle)? onDrop;

  const _SlotCell({
    required this.size,
    this.spanWidth,
    this.span = 1,
    this.totalCols = 999,
    required this.label,
    required this.shortLabel,
    this.bottle,
    this.wine,
    required this.isDragging,
    this.onTapWine,
    this.onDrop,
  });

  @override
  State<_SlotCell> createState() => _SlotCellState();
}

class _SlotCellState extends State<_SlotCell> {
  bool _hover = false;
  OverlayEntry? _overlay;

  void _showOverlay() {
    final wine = widget.wine;
    if (wine == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final pos = box.localToGlobal(Offset.zero);
    final mq = MediaQuery.of(context).size;
    final label = widget.label;
    final cellW = widget.spanWidth ?? widget.size;

    _overlay = OverlayEntry(builder: (_) {
      const cardW = 260.0;
      var left = pos.dx + cellW / 2 - cardW / 2;
      if (left < 8) left = 8;
      if (left + cardW > mq.width - 8) left = mq.width - cardW - 8;
      final top = pos.dy - 24;

      return Positioned(
        left: left,
        bottom: mq.height - top,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: _SlotHoverCard(wine: wine, label: label),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void didUpdateWidget(covariant _SlotCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bottle?.id != widget.bottle?.id) {
      _hideOverlay();
      _hover = false;
    }
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOccupied = widget.bottle != null;
    final garde = widget.wine != null ? GardeInfo.fromWine(widget.wine!) : null;
    final cellColor = garde?.color ?? wineTypeColor(widget.wine?.type ?? WineType.rouge);
    final vintageText = widget.wine?.vintage != null
        ? '${widget.wine!.vintage! % 100}'.padLeft(2, '0')
        : '';
    final cellW = widget.spanWidth ?? widget.size;

    Widget cellFor({required bool highlight, bool dragging = false, bool hovered = false}) {
      final showGold = hovered || highlight;
      return Container(
        width: cellW,
        height: widget.size,
        decoration: BoxDecoration(
          color: dragging
              ? cellColor.withValues(alpha: 0.10)
              : isOccupied
                  ? cellColor.withValues(alpha: hovered ? 0.45 : 0.30)
                  : showGold
                      ? const Color(0x33C9A84C)
                      : AppColors.bg3,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: dragging
                ? cellColor.withValues(alpha: 0.25)
                : showGold
                    ? AppColors.gold
                    : isOccupied
                        ? cellColor.withValues(alpha: 0.65)
                        : AppColors.border,
            width: showGold ? 1.5 : 1,
          ),
        ),
        child: _cellContent(
          isOccupied: isOccupied,
          dragging: dragging,
          hovered: hovered,
          vintageText: vintageText,
          cellColor: cellColor,
        ),
      );
    }

    Widget feedbackCell() {
      return Container(
        width: cellW,
        height: widget.size,
        decoration: BoxDecoration(
          color: cellColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: cellColor.withValues(alpha: 0.9),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: vintageText.isNotEmpty
            ? Center(
                child: Text(
                  vintageText,
                  style: AppText.sans(
                    color: cellColor,
                    fontSize: 9 * _scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : null,
      );
    }

    return DragTarget<Bottle>(
      onWillAcceptWithDetails: (details) {
        if (widget.onDrop == null) return false;
        if (details.data.id == widget.bottle?.id) return false;
        final neededSpan = details.data.format.slotSpan;
        if (neededSpan > 1) {
          final col = _colFromLabel(widget.shortLabel);
          if (col + neededSpan > widget.totalCols) return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) => widget.onDrop?.call(details.data),
      builder: (ctx, candidate, rejected) {
        final highlighted = candidate.isNotEmpty;

        if (isOccupied) {
          Widget child = cellFor(highlight: highlighted, hovered: _hover);
          if (widget.wine != null && widget.onTapWine != null) {
            child = InkWell(
              onTap: () => widget.onTapWine!(widget.wine!, widget.bottle!),
              borderRadius: BorderRadius.circular(3),
              child: child,
            );
          }
          return Draggable<Bottle>(
            data: widget.bottle!,
            onDragStarted: () {
              _hideOverlay();
              widget.isDragging.value = true;
            },
            onDragEnd: (_) {
              if (mounted) widget.isDragging.value = false;
            },
            onDraggableCanceled: (_, _) {
              if (mounted) widget.isDragging.value = false;
            },
            feedback: Material(
              color: Colors.transparent,
              child: feedbackCell(),
            ),
            childWhenDragging: cellFor(highlight: false, dragging: true),
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              onEnter: (_) {
                setState(() => _hover = true);
                _showOverlay();
              },
              onExit: (_) {
                setState(() => _hover = false);
                _hideOverlay();
              },
              child: child,
            ),
          );
        }

        return MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: ValueListenableBuilder<bool>(
            valueListenable: widget.isDragging,
            builder: (context, draggingNow, _) {
              final showLabel = draggingNow || _hover;
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: highlighted
                      ? const Color(0x33C9A84C)
                      : _hover
                          ? const Color(0x1AC9A84C)
                          : AppColors.bg3,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: highlighted || _hover
                        ? AppColors.gold
                        : AppColors.border,
                    width: highlighted || _hover ? 1.5 : 1,
                  ),
                ),
                child: showLabel
                    ? Center(
                        child: Text(
                          widget.shortLabel,
                          style: AppText.sans(
                            color: _hover ? AppColors.gold2 : AppColors.text3,
                            fontSize: 7 * _scale,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
        );
      },
    );
  }

  static int _colFromLabel(String shortLabel) {
    final m = RegExp(r'[A-Z]+(\d+)').firstMatch(shortLabel);
    if (m == null) return 0;
    return (int.tryParse(m.group(1)!) ?? 1) - 1;
  }

  double get _scale => widget.size / 28.0;

  Widget? _cellContent({
    required bool isOccupied,
    required bool dragging,
    required bool hovered,
    required String vintageText,
    required Color cellColor,
  }) {
    if (dragging) return null;
    if (isOccupied && hovered) {
      return Center(
        child: Text(
          widget.shortLabel,
          style: AppText.sans(
            color: AppColors.gold2,
            fontSize: 7 * _scale,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (isOccupied && vintageText.isNotEmpty) {
      return Center(
        child: Text(
          vintageText,
          style: AppText.sans(
            color: cellColor,
            fontSize: 9 * _scale,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return null;
  }
}

class _UnplacedHeader extends StatelessWidget {
  const _UnplacedHeader();

  @override
  Widget build(BuildContext context) {
    final style = AppText.sans(
      color: AppColors.text3,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.bg3,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: Center(child: Text('PHOTO', style: style))),
          const SizedBox(width: 10),
          Expanded(flex: 3, child: Text('VIN', style: style)),
          SizedBox(width: 50, child: Center(child: Text('MILL.', style: style))),
          const SizedBox(width: 10),
          SizedBox(width: 60, child: Center(child: Text('FORMAT', style: style))),
          const SizedBox(width: 10),
          SizedBox(width: 36, child: Center(child: Text('QTÉ', style: style))),
          const SizedBox(width: 10),
          const SizedBox(width: 24),
          const SizedBox(width: 10),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

class _UnplacedRow extends StatelessWidget {
  final List<Bottle> bottles;
  final Wine? wine;
  final ValueNotifier<bool> isDragging;
  final VoidCallback onTap;
  final VoidCallback? onOpenDetail;

  const _UnplacedRow({
    required this.bottles,
    required this.wine,
    required this.isDragging,
    required this.onTap,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final w = wine;
    final color = w == null ? AppColors.gold : wineTypeColor(w.type);
    final count = bottles.length;
    final first = bottles.first;

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: w?.photoUrl != null
                    ? NativeNetworkImage(
                        url: w!.photoUrl!,
                        width: 27,
                        height: 36,
                      )
                    : _photoFallback(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    w?.name ?? 'Vin',
                    style: AppText.serif(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 50,
            child: Center(
              child: Text(
                w?.vintage != null ? '${w!.vintage}' : '—',
                style: AppText.sans(
                  color: w?.vintage != null ? AppColors.gold2 : AppColors.text3,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: Center(
              child: Text(
                first.format.label,
                style: AppText.sans(color: AppColors.text2, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: Center(
              child: count > 1
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bg3,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border2),
                      ),
                      child: Text(
                        '$count',
                        style: AppText.sans(
                          color: AppColors.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : Text(
                      '1',
                      style: AppText.sans(
                        color: AppColors.text3,
                        fontSize: 11,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 24,
            child: w != null
                ? _WineInfoHover(wine: w, bottles: bottles, onTap: onOpenDetail)
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 10),
          const SizedBox(
            width: 20,
            child: Icon(Icons.drag_indicator, size: 14, color: AppColors.text3),
          ),
        ],
      ),
    );

    final feedback = Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x50000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          if (w?.photoUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: NativeNetworkImage(
                url: w!.photoUrl!,
                width: 24,
                height: 32,
              ),
            )
          else
            const SizedBox(width: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        w?.name ?? 'Vin',
                        style: AppText.serif(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (w?.producer.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    w!.producer,
                    style: AppText.sans(color: AppColors.text3, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (w?.vintage != null)
                      Text(
                        '${w!.vintage}',
                        style: AppText.sans(
                          color: AppColors.gold2,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (w?.vintage != null) const SizedBox(width: 8),
                    Text(
                      first.format.label,
                      style: AppText.sans(color: AppColors.text3, fontSize: 10),
                    ),
                    if (count > 1) ...[
                      const SizedBox(width: 8),
                      Text(
                        '×$count',
                        style: AppText.sans(
                          color: AppColors.text2,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Draggable<Bottle>(
      data: first,
      onDragStarted: () => isDragging.value = true,
      onDragEnd: (_) => isDragging.value = false,
      dragAnchorStrategy: (draggable, context, position) =>
          const Offset(120, -10),
      feedback: Material(color: Colors.transparent, child: feedback),
      childWhenDragging: Opacity(opacity: 0.3, child: row),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: InkWell(
          onTap: onTap,
          child: row,
        ),
      ),
    );
  }

  static Widget _photoFallback() {
    return Container(
      width: 27,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(Icons.wine_bar, color: AppColors.text3, size: 12),
    );
  }
}

class _WineInfoHover extends StatefulWidget {
  final Wine wine;
  final List<Bottle> bottles;
  final VoidCallback? onTap;
  const _WineInfoHover({required this.wine, required this.bottles, this.onTap});

  @override
  State<_WineInfoHover> createState() => _WineInfoHoverState();
}

class _WineInfoHoverState extends State<_WineInfoHover> {
  OverlayEntry? _overlay;

  void _show() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final pos = box.localToGlobal(Offset.zero);
    final screenW = MediaQuery.of(context).size.width;
    final w = widget.wine;
    final b = widget.bottles;

    _overlay = OverlayEntry(builder: (_) {
      const cardW = 300.0;
      var left = pos.dx - cardW - 12;
      if (left < 8) left = pos.dx + box.size.width + 12;
      if (left + cardW > screenW - 8) left = screenW - cardW - 8;
      var top = pos.dy - 40;
      if (top < 8) top = 8;

      return Positioned(
        left: left,
        top: top,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: _WineInfoCard(wine: w, bottles: b),
          ),
        ),
      );
    });
    Overlay.of(context).insert(_overlay!);
  }

  void _hide() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => _show(),
        onExit: (_) => _hide(),
        child: const Icon(
          Icons.description_outlined,
          size: 16,
          color: AppColors.text3,
        ),
      ),
    );
  }
}

class _WineInfoCard extends StatelessWidget {
  final Wine wine;
  final List<Bottle> bottles;
  const _WineInfoCard({required this.wine, required this.bottles});

  @override
  Widget build(BuildContext context) {
    final w = wine;
    final color = wineTypeColor(w.type);
    final qty = bottles.length;
    final format = bottles.first.format.label;

    final rows = <Widget>[];

    if (w.producer.isNotEmpty) rows.add(_row('Producteur', w.producer));
    if (w.appellation.isNotEmpty) rows.add(_row('Appellation', w.appellation));
    if (w.region.isNotEmpty || w.country.isNotEmpty) {
      final origin = [w.region, w.country].where((s) => s.isNotEmpty).join(', ');
      rows.add(_row('Origine', origin));
    }
    if (w.domaine.isNotEmpty) rows.add(_row('Domaine', w.domaine));
    if (w.village.isNotEmpty) rows.add(_row('Village', w.village));
    if (w.climat.isNotEmpty) rows.add(_row('Climat', w.climat));
    if (w.grapes.isNotEmpty) rows.add(_row('Cépages', w.grapes));
    if (w.alcohol != null) rows.add(_row('Alcool', '${w.alcohol!.toStringAsFixed(1)} %'));
    if (w.rating != null) rows.add(_row('Note', '${w.rating}/100'));
    if (w.drinkFrom != null || w.drinkPeak != null || w.drinkTo != null) {
      final parts = <String>[];
      if (w.drinkFrom != null) parts.add('dès ${w.drinkFrom}');
      if (w.drinkPeak != null) parts.add('apogée ${w.drinkPeak}');
      if (w.drinkTo != null) parts.add('jusqu\'à ${w.drinkTo}');
      rows.add(_row('Garde', parts.join(' · ')));
    }

    final prices = bottles.map((b) => b.purchasePrice).whereType<double>().toList();
    if (prices.isNotEmpty) {
      rows.add(_row('Prix', '${prices.first.toStringAsFixed(0)} \$'));
    }
    rows.add(_row('Format', format));
    rows.add(_row('Quantité', '$qty'));

    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  w.name,
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (w.vintage != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x1FC9A84C),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0x40C9A84C)),
                  ),
                  child: Text(
                    '${w.vintage}',
                    style: AppText.sans(
                      color: AppColors.gold2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) const SizedBox(height: 6),
          ],
          if (w.wineDescription.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Text(
              w.wineDescription,
              style: AppText.sans(color: AppColors.text3, fontSize: 11, height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppText.sans(
              color: AppColors.text3,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppText.sans(
              color: AppColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SlotHoverCard extends StatelessWidget {
  final Wine wine;
  final String label;
  const _SlotHoverCard({required this.wine, required this.label});

  @override
  Widget build(BuildContext context) {
    final w = wine;
    final color = wineTypeColor(w.type);
    final garde = GardeInfo.fromWine(w);

    final details = <_CardDetail>[];
    if (w.producer.isNotEmpty) details.add(_CardDetail(w.producer));
    if (w.appellation.isNotEmpty) details.add(_CardDetail(w.appellation));
    final origin = [w.region, w.country].where((s) => s.isNotEmpty).join(', ');
    if (origin.isNotEmpty) details.add(_CardDetail(origin));
    if (w.grapes.isNotEmpty) details.add(_CardDetail(w.grapes));

    return Container(
      width: 260,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2A2318),
            AppColors.bg2,
            const Color(0xFF1E1B16),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.06),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  w.name,
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (w.vintage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0x1FC9A84C),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0x40C9A84C)),
                  ),
                  child: Text(
                    '${w.vintage}',
                    style: AppText.sans(
                      color: AppColors.gold2,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  wineTypeLabel(w.type),
                  style: AppText.sans(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (garde != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: garde.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: garde.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    garde.label,
                    style: AppText.sans(
                      color: garde.color,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                label,
                style: AppText.sans(
                  color: AppColors.text3,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.0),
                    AppColors.gold.withValues(alpha: 0.25),
                    AppColors.gold.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final d in details) ...[
              Text(
                d.text,
                style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (d != details.last) const SizedBox(height: 3),
            ],
          ],
          if (w.rating != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.star, color: AppColors.gold2, size: 11),
                const SizedBox(width: 3),
                Text(
                  '${w.rating}',
                  style: AppText.sans(
                    color: AppColors.gold2,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CardDetail {
  final String text;
  const _CardDetail(this.text);
}

class _MobileUnplacedPanel extends StatefulWidget {
  final ValueNotifier<bool> isDragging;
  final Future<void> Function(Bottle b, Wine? w) onChipTap;
  final Future<void> Function(Wine wine, Bottle bottle) onOpenDetail;

  const _MobileUnplacedPanel({
    required this.isDragging,
    required this.onChipTap,
    required this.onOpenDetail,
  });

  @override
  State<_MobileUnplacedPanel> createState() => _MobileUnplacedPanelState();
}

class _MobileUnplacedPanelState extends State<_MobileUnplacedPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Bottle>>(
      stream: CaveService.unplacedBottlesInCave(),
      builder: (context, bottlesSnap) {
        final bottles = bottlesSnap.data ?? [];
        return StreamBuilder<List<Wine>>(
          stream: CaveService.wines(),
          builder: (context, winesSnap) {
            final winesById = {
              for (final w in winesSnap.data ?? <Wine>[]) w.id: w
            };
            final grouped = <String, List<Bottle>>{};
            for (final b in bottles) {
              final key = '${b.wineId}::${b.format.name}';
              grouped.putIfAbsent(key, () => []).add(b);
            }
            final groups = grouped.values.toList();

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: AppColors.bg2,
                border: const Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, size: 16, color: AppColors.gold),
                          const SizedBox(width: 8),
                          Text(
                            'À placer',
                            style: AppText.sans(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: bottles.isEmpty
                                  ? AppColors.bg3
                                  : AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${bottles.length}',
                              style: AppText.sans(
                                color: bottles.isEmpty ? AppColors.text3 : AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            _expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            size: 20,
                            color: AppColors.text3,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_expanded && groups.isNotEmpty)
                    SizedBox(
                      height: (groups.length * 52.0).clamp(0, 220),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                        itemCount: groups.length,
                        itemBuilder: (context, i) {
                          final group = groups[i];
                          final first = group.first;
                          final w = winesById[first.wineId];
                          return _MobileUnplacedItem(
                            wine: w,
                            bottles: group,
                            onTap: () => widget.onChipTap(first, w),
                            onOpenDetail: w != null
                                ? () => widget.onOpenDetail(w, first)
                                : null,
                          );
                        },
                      ),
                    ),
                  if (_expanded && groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Toutes les bouteilles sont placées',
                        style: AppText.sans(color: AppColors.text3, fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _MobileUnplacedItem extends StatelessWidget {
  final Wine? wine;
  final List<Bottle> bottles;
  final VoidCallback onTap;
  final VoidCallback? onOpenDetail;

  const _MobileUnplacedItem({
    required this.wine,
    required this.bottles,
    required this.onTap,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    final w = wine;
    final first = bottles.first;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: w != null ? wineTypeColor(w.type) : AppColors.text3,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w?.name ?? '?',
                    style: AppText.sans(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${first.format.label} · x${bottles.length}',
                    style: AppText.sans(color: AppColors.text3, fontSize: 10),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onOpenDetail,
              child: const Icon(Icons.chevron_right, size: 18, color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}
