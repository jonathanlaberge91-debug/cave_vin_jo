import 'dart:math';
import 'package:flutter/material.dart';
import '../models/bottle.dart';
import '../models/cave_column.dart';
import '../models/wine.dart';
import '../services/cave_preferences_service.dart';
import '../services/cave_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/cascade_filter.dart';
import '../widgets/cave_table.dart' show WineRow, GardeInfo;

const double _rowH = 36.0;
const double _headerH = 38.0;
const double _fallbackW = 120.0;

const List<CaveColumn> _frozenCols = [CaveColumn.name, CaveColumn.vintage];

double _colW(CaveColumn c) => c.width ?? _fallbackW;

class _ResizeHandle extends StatefulWidget {
  final void Function(double dx) onResize;
  const _ResizeHandle({required this.onResize});

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.opaque,
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerMove: (e) => widget.onResize(e.delta.dx),
        child: Container(
          width: 8,
          height: _headerH,
          color: _hovered
              ? const Color(0xFFD4A843).withValues(alpha: 0.45)
              : Colors.transparent,
        ),
      ),
    );
  }
}

bool _isEditable(CaveColumn c) => const {
      CaveColumn.name,
      CaveColumn.vintage,
      CaveColumn.appellation,
      CaveColumn.region,
      CaveColumn.country,
      CaveColumn.village,
      CaveColumn.climat,
      CaveColumn.domaine,
      CaveColumn.domainAddress,
      CaveColumn.grapes,
      CaveColumn.alcohol,
      CaveColumn.rating,
      CaveColumn.drinkFrom,
      CaveColumn.apogee,
      CaveColumn.drinkTo,
      CaveColumn.source,
      CaveColumn.purchaseYear,
      CaveColumn.price,
    }.contains(c);

bool _isBottleLevel(CaveColumn c) =>
    c == CaveColumn.purchaseYear || c == CaveColumn.price;

String _pendingDisplay(CaveColumn col, String raw) {
  if (raw.isEmpty) return '';
  switch (col) {
    case CaveColumn.rating:
      return '$raw/100';
    case CaveColumn.alcohol:
      return '$raw%';
    case CaveColumn.price:
      return '$raw \$';
    default:
      return raw;
  }
}

class _PendingEntry {
  final String wineId;
  final String wineName;
  final int? vintage;
  final CaveColumn col;
  final String oldDisplay;
  final String rawValue;
  final Map<String, dynamic> update;
  final bool isBottleLevel;
  final List<String> bottleIds;

  const _PendingEntry({
    required this.wineId,
    required this.wineName,
    required this.vintage,
    required this.col,
    required this.oldDisplay,
    required this.rawValue,
    required this.update,
    required this.isBottleLevel,
    required this.bottleIds,
  });

  String get newDisplay => _pendingDisplay(col, rawValue);
}

String _cellText(WineRow row, CaveColumn col) {
  final w = row.wine;
  final bs = row.bottles;
  switch (col) {
    case CaveColumn.name:
      return w.name;
    case CaveColumn.vintage:
      return w.vintage?.toString() ?? '';
    case CaveColumn.type:
      return w.type.name;
    case CaveColumn.appellation:
      return w.appellation;
    case CaveColumn.region:
      return w.region;
    case CaveColumn.country:
      return w.country;
    case CaveColumn.village:
      return w.village;
    case CaveColumn.climat:
      return w.climat;
    case CaveColumn.domaine:
      return w.domaine;
    case CaveColumn.domainAddress:
      return w.domainAddress;
    case CaveColumn.grapes:
      return w.grapes;
    case CaveColumn.alcohol:
      return w.alcohol != null ? '${w.alcohol}%' : '';
    case CaveColumn.rating:
      return w.rating != null ? '${w.rating}/100' : '';
    case CaveColumn.garde:
      return (bs.isEmpty
                  ? GardeInfo.fromWine(w)
                  : GardeInfo.fromWineFormat(w, bs.first.format))
              ?.label ??
          '';
    case CaveColumn.drinkFrom:
      return w.drinkFrom?.toString() ?? '';
    case CaveColumn.apogee:
      return w.drinkPeak?.toString() ?? '';
    case CaveColumn.drinkTo:
      return w.drinkTo?.toString() ?? '';
    case CaveColumn.qty:
      return '${bs.length}';
    case CaveColumn.price:
      if (bs.isEmpty) return '';
      final p = bs.first.purchasePrice;
      return p != null ? '${p.toStringAsFixed(0)} \$' : '';
    case CaveColumn.marketValue:
      final mv = bs.map((b) => b.marketValue).whereType<double>().toList();
      if (mv.isEmpty) return '';
      final avg = mv.reduce((a, b) => a + b) / mv.length;
      return '${avg.toStringAsFixed(0)} \$';
    case CaveColumn.totalValue:
      final total =
          bs.fold<double>(0, (s, b) => s + (b.marketValue ?? b.purchasePrice ?? 0));
      return '${total.toStringAsFixed(0)} \$';
    case CaveColumn.format:
      if (bs.isEmpty) return '';
      return bs.first.format.label;
    case CaveColumn.source:
      if (bs.isEmpty) return '';
      return bs.first.source ?? '';
    case CaveColumn.purchaseYear:
      if (bs.isEmpty) return '';
      return bs.first.purchaseYear?.toString() ?? '';
    case CaveColumn.createdAt:
      final d = w.createdAt;
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    case CaveColumn.location:
      final locs =
          bs.map((b) => b.location).where((l) => l.isNotEmpty).toSet();
      return locs.join(', ');
    default:
      return '';
  }
}

Map<String, dynamic>? _parseEdit(CaveColumn col, String value) {
  final v = value.trim();
  switch (col) {
    case CaveColumn.name:
      return v.isNotEmpty ? {'name': v} : null;
    case CaveColumn.vintage:
      return {'vintage': int.tryParse(v)};
    case CaveColumn.appellation:
      return {'appellation': v};
    case CaveColumn.region:
      return {'region': v};
    case CaveColumn.country:
      return {'country': v};
    case CaveColumn.village:
      return {'village': v};
    case CaveColumn.climat:
      return {'climat': v};
    case CaveColumn.domaine:
      return {'domaine': v};
    case CaveColumn.domainAddress:
      return {'domainAddress': v};
    case CaveColumn.grapes:
      return {'grapes': v};
    case CaveColumn.alcohol:
      return {'alcohol': double.tryParse(v.replaceAll(',', '.'))};
    case CaveColumn.rating:
      final i = int.tryParse(v);
      return {'rating': i?.clamp(0, 100)};
    case CaveColumn.drinkFrom:
      return {'drinkFrom': int.tryParse(v)};
    case CaveColumn.apogee:
      return {'drinkPeak': int.tryParse(v)};
    case CaveColumn.drinkTo:
      return {'drinkTo': int.tryParse(v)};
    case CaveColumn.purchaseYear:
      return {'purchaseYear': int.tryParse(v)};
    case CaveColumn.price:
      return {'purchasePrice': double.tryParse(v.replaceAll(',', '.'))};
    default:
      return null;
  }
}

class CaveSpreadsheetScreen extends StatefulWidget {
  const CaveSpreadsheetScreen({super.key});

  @override
  State<CaveSpreadsheetScreen> createState() => _CaveSpreadsheetScreenState();
}

class _CaveSpreadsheetScreenState extends State<CaveSpreadsheetScreen> {
  CascadeFilterState _filter = const CascadeFilterState();
  String _search = '';
  (String, CaveColumn)? _editing;
  final _editCtrl = TextEditingController();
  final _editFocus = FocusNode();
  final _searchCtrl = TextEditingController();
  List<WineRow> _allRows = [];

  // Staged changes — key: '${wineId}_${col.name}'
  final Map<String, _PendingEntry> _pending = {};

  // Column width overrides
  final Map<CaveColumn, double> _colWidths = {};

  double _effectiveW(CaveColumn c) => _colWidths[c] ?? _colW(c);

  final _leftScroll = ScrollController();
  final _rightScroll = ScrollController();
  bool _syncingV = false;

  final _horizContent = ScrollController();

  @override
  void initState() {
    super.initState();
    _editFocus.addListener(_onFocusChange);
    _leftScroll.addListener(_syncFromLeft);
    _rightScroll.addListener(_syncFromRight);
  }

  @override
  void dispose() {
    _editFocus.removeListener(_onFocusChange);
    _leftScroll.removeListener(_syncFromLeft);
    _rightScroll.removeListener(_syncFromRight);
    _editCtrl.dispose();
    _editFocus.dispose();
    _searchCtrl.dispose();
    _leftScroll.dispose();
    _rightScroll.dispose();
    _horizContent.dispose();
    super.dispose();
  }

  void _syncFromLeft() {
    if (_syncingV) return;
    _syncingV = true;
    if (_rightScroll.hasClients) _rightScroll.jumpTo(_leftScroll.offset);
    _syncingV = false;
  }

  void _syncFromRight() {
    if (_syncingV) return;
    _syncingV = true;
    if (_leftScroll.hasClients) _leftScroll.jumpTo(_rightScroll.offset);
    _syncingV = false;
  }

  void _onFocusChange() {
    if (!_editFocus.hasFocus && _editing != null) _commit();
  }

  void _startEdit(WineRow row, CaveColumn col) {
    if (_editing != null) _commit();

    // If there's already a pending change for this cell, use its raw value
    final pendingKey = '${row.wine.id}_${col.name}';
    final pending = _pending[pendingKey];
    final base = pending != null ? pending.rawValue : _cellText(row, col);
    final editValue = base
        .replaceAll('%', '')
        .replaceAll(' \$', '')
        .replaceAll('/100', '');

    setState(() {
      _editing = (row.wine.id, col);
      _editCtrl.text = editValue;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editFocus.requestFocus();
    });
  }

  void _commit() {
    if (_editing == null) return;
    final (wineId, col) = _editing!;
    setState(() => _editing = null);
    final update = _parseEdit(col, _editCtrl.text);
    if (update == null) return;

    final rowIdx = _allRows.indexWhere((r) => r.wine.id == wineId);
    if (rowIdx < 0) return;
    final row = _allRows[rowIdx];

    final key = '${wineId}_${col.name}';
    final oldDisplay = _pending[key]?.oldDisplay ?? _cellText(row, col);
    final rawValue = _editCtrl.text.trim();

    // Strip formatting to compare apples-to-apples
    final strippedOld = oldDisplay
        .replaceAll('%', '')
        .replaceAll(' \$', '')
        .replaceAll('/100', '');
    if (rawValue == strippedOld) {
      // Back to original — remove from pending if it was there
      if (_pending.containsKey(key)) setState(() => _pending.remove(key));
      return;
    }

    setState(() {
      _pending[key] = _PendingEntry(
        wineId: wineId,
        wineName: row.wine.name,
        vintage: row.wine.vintage,
        col: col,
        oldDisplay: oldDisplay,
        rawValue: rawValue,
        update: update,
        isBottleLevel: _isBottleLevel(col),
        bottleIds: _isBottleLevel(col)
            ? row.bottles.map((b) => b.id).toList()
            : [],
      );
    });
  }

  Future<void> _editSource(WineRow row) async {
    final key = '${row.wine.id}_${CaveColumn.source.name}';
    final currentDisplay = _pending[key]?.rawValue ??
        (row.bottles.isNotEmpty ? row.bottles.first.source ?? '' : '');
    final labels = CavePreferencesService.allSourceLabels;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: Text(
          'Provenance',
          style: AppText.sans(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 240, maxWidth: 320, maxHeight: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: labels.map((label) {
                final isSelected = currentDisplay == label;
                return InkWell(
                  onTap: () => Navigator.pop(ctx, label),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: AppColors.gold)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: AppText.sans(
                            color: isSelected ? AppColors.gold : AppColors.text,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: AppText.sans(color: AppColors.text2, fontSize: 13)),
          ),
        ],
      ),
    );
    if (selected != null && mounted) {
      final oldDisplay =
          _pending[key]?.oldDisplay ?? _cellText(row, CaveColumn.source);
      setState(() {
        _pending[key] = _PendingEntry(
          wineId: row.wine.id,
          wineName: row.wine.name,
          vintage: row.wine.vintage,
          col: CaveColumn.source,
          oldDisplay: oldDisplay,
          rawValue: selected,
          update: {'source': selected},
          isBottleLevel: true,
          bottleIds: row.bottles.map((b) => b.id).toList(),
        );
      });
    }
  }

  Future<void> _showSaveDialog() async {
    final entries = _pending.values.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        title: Text(
          'Modifications en attente',
          style: AppText.sans(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w600),
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: entries.map((e) {
                final wineLabel = e.vintage != null
                    ? '${e.wineName} ${e.vintage}'
                    : e.wineName;
                final oldLabel =
                    e.oldDisplay.isEmpty ? '—' : e.oldDisplay;
                final newLabel =
                    e.newDisplay.isEmpty ? '—' : e.newDisplay;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          wineLabel,
                          style: AppText.sans(
                              color: AppColors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        e.col.label,
                        style: AppText.sans(
                            color: AppColors.text2, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        oldLabel,
                        style: AppText.sans(
                            color: AppColors.text3, fontSize: 12),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward,
                            size: 12, color: AppColors.text3),
                      ),
                      Text(
                        newLabel,
                        style: AppText.sans(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: AppText.sans(color: AppColors.text2, fontSize: 13)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Confirmer',
                style: AppText.sans(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _saveAll();
  }

  Future<void> _saveAll() async {
    final entries = Map<String, _PendingEntry>.from(_pending);
    setState(() => _pending.clear());
    for (final e in entries.values) {
      if (e.isBottleLevel) {
        for (final id in e.bottleIds) {
          await CaveService.updateBottle(id, e.update);
        }
      } else {
        await CaveService.updateWine(e.wineId, e.update);
      }
    }
  }

  List<WineRow> _filtered(List<WineRow> rows) {
    final q = _search.toLowerCase();
    return rows.where((r) {
      final w = r.wine;
      if (!_filter.matchesWine(
        country: w.country,
        region: w.region,
        appellation: w.appellation,
        climat: w.climat,
      )) {
        return false;
      }
      if (q.isEmpty) return true;
      return w.name.toLowerCase().contains(q) ||
          w.domaine.toLowerCase().contains(q) ||
          w.region.toLowerCase().contains(q) ||
          (w.vintage?.toString() ?? '').contains(q);
    }).toList();
  }

  List<CascadeFilterData> _filterData(List<WineRow> rows) => rows
      .map((r) => CascadeFilterData(
            country: r.wine.country,
            region: r.wine.region,
            appellation: r.wine.appellation,
            climat: r.wine.climat,
          ))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Cave en tableau',
            style: AppText.serif(color: AppColors.text, fontSize: 18)),
        actions: [
          if (_pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: const Size(0, 34),
                ),
                onPressed: _showSaveDialog,
                icon: const Icon(Icons.save_outlined,
                    size: 16, color: Colors.black),
                label: Text(
                  'Sauvegarder (${_pending.length})',
                  style: AppText.sans(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: StreamBuilder<List<Wine>>(
        stream: CaveService.wines(),
        builder: (ctx, wineSnap) {
          return StreamBuilder<List<Bottle>>(
            stream: CaveService.bottlesInCave(),
            builder: (ctx, bottleSnap) {
              final wines = wineSnap.data ?? [];
              final bottles = bottleSnap.data ?? [];
              final byWine = <String, List<Bottle>>{};
              for (final b in bottles) {
                byWine.putIfAbsent(b.wineId, () => []).add(b);
              }
              _allRows = wines
                  .where((w) => byWine.containsKey(w.id))
                  .map((w) => WineRow(wine: w, bottles: byWine[w.id]!))
                  .toList();

              final filtered = _filtered(_allRows);

              return ValueListenableBuilder<Set<CaveColumn>>(
                valueListenable: CavePreferencesService.tableVisible,
                builder: (ctx, visible, _) {
                  final cols = CaveColumn.values
                      .where((c) =>
                          c != CaveColumn.photo && visible.contains(c))
                      .toList();
                  return Column(
                    children: [
                      _buildTopBar(wines
                          .map((w) =>
                              WineRow(wine: w, bottles: byWine[w.id] ?? []))
                          .toList()),
                      Expanded(child: _buildTable(filtered, cols)),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTopBar(List<WineRow> allRows) {
    return Container(
      color: AppColors.bg2,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          TextField(
            controller: _searchCtrl,
            style: AppText.sans(color: AppColors.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Rechercher…',
              hintStyle: AppText.sans(color: AppColors.text3, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.text3, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: AppColors.bg3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.gold),
              ),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 6),
          CascadeFilterBar(
            filter: _filter,
            allItems: _filterData(allRows),
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildTable(List<WineRow> rows, List<CaveColumn> cols) {
    final scrollCols = cols.where((c) => !_frozenCols.contains(c)).toList();
    final frozenW = _frozenCols.fold<double>(0, (s, c) => s + _effectiveW(c));
    final scrollW = scrollCols.fold<double>(0, (s, c) => s + _effectiveW(c));

    return LayoutBuilder(builder: (ctx, constraints) {
      final h = constraints.maxHeight;
      final contentW = max(constraints.maxWidth - frozenW - 1, scrollW);
      final dataH = h - _headerH - 1;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: frozen panel
          SizedBox(
            width: frozenW,
            height: h,
            child: Column(
              children: [
                _buildHeaderSection(_frozenCols),
                Container(height: 1, color: AppColors.border),
                Expanded(
                  child: ListView.builder(
                    controller: _leftScroll,
                    itemCount: rows.length,
                    itemBuilder: (ctx, i) =>
                        _buildRowSection(rows[i], _frozenCols, i),
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: h, color: AppColors.border),
          // RIGHT: header outside scroll view so resize handles work
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: _headerH,
                  child: ClipRect(
                    child: AnimatedBuilder(
                      animation: _horizContent,
                      builder: (ctx, child) => Transform.translate(
                        offset: Offset(
                          -(_horizContent.hasClients
                              ? _horizContent.offset
                              : 0.0),
                          0,
                        ),
                        child: child,
                      ),
                      child: _buildHeaderSection(scrollCols),
                    ),
                  ),
                ),
                Container(height: 1, color: AppColors.border),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _horizContent,
                    child: SizedBox(
                      width: contentW,
                      height: dataH,
                      child: ListView.builder(
                        controller: _rightScroll,
                        itemCount: rows.length,
                        itemBuilder: (ctx, i) =>
                            _buildRowSection(rows[i], scrollCols, i),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildHeaderSection(List<CaveColumn> cols) {
    return Container(
      height: _headerH,
      color: AppColors.bg2,
      child: Row(
        children: cols.map((c) {
          return SizedBox(
            width: _effectiveW(c),
            height: _headerH,
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        c.label,
                        style: AppText.sans(
                          color: AppColors.text2,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                _ResizeHandle(
                  onResize: (dx) => setState(
                    () => _colWidths[c] =
                        (_effectiveW(c) + dx).clamp(36.0, 600.0),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRowSection(WineRow row, List<CaveColumn> cols, int index) {
    return Container(
      height: _rowH,
      color: index.isEven ? AppColors.bg : AppColors.bg2,
      child: Row(
        children: cols.map((c) => _buildCell(row, c)).toList(),
      ),
    );
  }

  Widget _buildCell(WineRow row, CaveColumn col) {
    final key = '${row.wine.id}_${col.name}';
    final isEditing =
        _editing != null && _editing!.$1 == row.wine.id && _editing!.$2 == col;
    final editable = _isEditable(col);
    final pending = _pending[key];
    final isPending = pending != null;

    Widget content;
    if (isEditing) {
      content = TextField(
        controller: _editCtrl,
        focusNode: _editFocus,
        autofocus: true,
        style: AppText.sans(color: AppColors.text, fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: InputBorder.none,
          hintText: '—',
          hintStyle: AppText.sans(color: AppColors.text3, fontSize: 12),
        ),
        onSubmitted: (_) => _commit(),
      );
    } else {
      final text = isPending ? pending.newDisplay : _cellText(row, col);
      final garde = col == CaveColumn.garde
          ? (row.bottles.isEmpty
              ? GardeInfo.fromWine(row.wine)
              : GardeInfo.fromWineFormat(row.wine, row.bottles.first.format))
          : null;
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: col == CaveColumn.source
            ? () => _editSource(row)
            : editable
                ? () => _startEdit(row, col)
                : null,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: garde != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: garde.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: garde.color.withValues(alpha: 0.4)),
                      ),
                      child: Text(garde.label,
                          style: AppText.sans(
                              color: garde.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (garde.windowShort.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, top: 1),
                        child: Text(garde.windowShort,
                            style: AppText.sans(
                                color: garde.color.withValues(alpha: 0.7),
                                fontSize: 8,
                                fontWeight: FontWeight.w600)),
                      ),
                  ],
                )
              : Text(
                  text,
                  style: AppText.sans(
                    color: isPending
                        ? const Color(0xFF6BA3FF)
                        : editable
                            ? AppColors.text
                            : AppColors.text2,
                    fontSize: 12,
                    fontWeight:
                        isPending ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      );
    }

    Color? bgColor;
    if (isEditing) {
      bgColor = AppColors.gold.withValues(alpha: 0.22);
    } else if (isPending) {
      bgColor = const Color(0xFF6BA3FF).withValues(alpha: 0.10);
    }

    return Container(
      key: ValueKey(key),
      width: _effectiveW(col),
      height: _rowH,
      decoration: BoxDecoration(
        border: Border(
            right: BorderSide(color: AppColors.border.withValues(alpha: 0.4))),
        color: bgColor,
      ),
      child: content,
    );
  }
}
