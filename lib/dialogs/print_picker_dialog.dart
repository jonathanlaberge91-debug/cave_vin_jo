import 'package:flutter/material.dart';
import '../models/bottle.dart';
import '../models/wine.dart';
import '../services/cave_service.dart';
import '../services/wine_pdf_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/cascade_filter.dart';

Future<void> showPrintPickerDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (_) => const _PrintPickerDialog(),
  );
}

class _PrintPickerDialog extends StatefulWidget {
  const _PrintPickerDialog();

  @override
  State<_PrintPickerDialog> createState() => _PrintPickerDialogState();
}

class _PrintPickerDialogState extends State<_PrintPickerDialog> {
  bool _loading = true;
  List<Wine> _wines = const [];
  List<Bottle> _bottles = const [];
  CascadeFilterState _filter = const CascadeFilterState();
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (wines, bottles) = await (
        CaveService.wines().first,
        CaveService.bottlesInCave().first,
      ).wait;
      if (!mounted) return;
      setState(() {
        _wines = wines;
        _bottles = bottles;
        _selected
          ..clear()
          ..addAll(_filteredWines(wines, bottles, _filter).map((w) => w.id));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Wine> _filteredWines(
    List<Wine> wines,
    List<Bottle> bottles,
    CascadeFilterState filter,
  ) {
    final hasBottles = <String>{};
    for (final b in bottles) {
      hasBottles.add(b.wineId);
    }
    return wines
        .where((w) => hasBottles.contains(w.id))
        .where((w) => filter.matchesWine(
              country: w.country,
              region: w.region,
              appellation: w.appellation,
              climat: w.climat,
            ))
        .toList();
  }

  List<CascadeFilterData> get _allFilterItems {
    final hasBottles = <String>{};
    for (final b in _bottles) {
      hasBottles.add(b.wineId);
    }
    return [
      for (final w in _wines.where((w) => hasBottles.contains(w.id)))
        CascadeFilterData(
          country: w.country,
          region: w.region,
          appellation: w.appellation,
          climat: w.climat,
        ),
    ];
  }

  void _toggle(String id) {
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _toggleAll(List<Wine> visible) {
    final ids = visible.map((w) => w.id).toSet();
    final allSelected = ids.every(_selected.contains);
    setState(() {
      if (allSelected) {
        _selected.removeAll(ids);
      } else {
        _selected.addAll(ids);
      }
    });
  }

  Future<void> _print(List<Wine> visible) async {
    final selectedWines =
        visible.where((w) => _selected.contains(w.id)).toList();
    if (selectedWines.isEmpty) return;
    final selectedIds = selectedWines.map((w) => w.id).toSet();
    final selectedBottles =
        _bottles.where((b) => selectedIds.contains(b.wineId)).toList();
    openAllWinesPrintSheet(selectedWines, selectedBottles);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final maxWidth = size.width > 920 ? 880.0 : size.width - 32;
    final maxHeight = size.height * 0.92;

    final visible = _filteredWines(_wines, _bottles, _filter);
    final allSelected = visible.isNotEmpty &&
        visible.every((w) => _selected.contains(w.id));
    final selectedVisibleCount =
        visible.where((w) => _selected.contains(w.id)).length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(visible.length, selectedVisibleCount),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: CascadeFilterBar(
                    filter: _filter,
                    allItems: _allFilterItems,
                    onChanged: (f) {
                      setState(() {
                        _filter = f;
                        // Garde la sélection précédente pour les vins encore visibles.
                        final stillVisibleIds = _filteredWines(
                          _wines, _bottles, f,
                        ).map((w) => w.id).toSet();
                        _selected.retainAll(stillVisibleIds);
                      });
                    },
                  ),
                ),
                _selectionBar(visible, allSelected),
                Flexible(
                  child: visible.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'Aucun vin ne correspond au filtre.',
                              style: AppText.sans(
                                  color: AppColors.text3, fontSize: 13),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: AppColors.border,
                          ),
                          itemBuilder: (context, i) {
                            final w = visible[i];
                            final btls = _bottles
                                .where((b) => b.wineId == w.id)
                                .toList();
                            return _row(w, btls);
                          },
                        ),
                ),
              ],
              _footer(selectedVisibleCount, visible),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(int total, int selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined,
              size: 18, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Imprimer des fiches',
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$selected / $total sélectionné${selected > 1 ? 's' : ''}',
                  style: AppText.sans(
                      color: AppColors.text3, fontSize: 12),
                ),
              ],
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

  Widget _selectionBar(List<Wine> visible, bool allSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: visible.isEmpty ? null : () => _toggleAll(visible),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    allSelected
                        ? Icons.check_box_outlined
                        : Icons.check_box_outline_blank,
                    size: 18,
                    color: visible.isEmpty
                        ? AppColors.text3
                        : AppColors.gold2,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    allSelected
                        ? 'Tout désélectionner'
                        : 'Tout sélectionner',
                    style: AppText.sans(
                      color: visible.isEmpty
                          ? AppColors.text3
                          : AppColors.text2,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Wine wine, List<Bottle> bottles) {
    final isChecked = _selected.contains(wine.id);
    final qty = bottles.length;
    final origin = [wine.region, wine.country]
        .where((s) => s.isNotEmpty)
        .join(' · ');
    return InkWell(
      onTap: () => _toggle(wine.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isChecked
                  ? Icons.check_box_outlined
                  : Icons.check_box_outline_blank,
              size: 18,
              color: isChecked ? AppColors.gold : AppColors.text3,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wine.vintage != null
                        ? '${wine.name} ${wine.vintage}'
                        : wine.name,
                    style: AppText.serif(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (origin.isNotEmpty || wine.appellation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        [wine.appellation, origin]
                            .where((s) => s.isNotEmpty)
                            .join(' · '),
                        style: AppText.sans(
                          color: AppColors.text3,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '$qty bout.',
                style: AppText.sans(
                  color: AppColors.text2,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(int selectedCount, List<Wine> visible) {
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
            child: Text(
              'Annuler',
              style: AppText.sans(color: AppColors.text2, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: selectedCount == 0 ? null : () => _print(visible),
            icon: const Icon(Icons.print_outlined, size: 16),
            label: Text(
              selectedCount == 0
                  ? 'Imprimer'
                  : 'Imprimer $selectedCount fiche${selectedCount > 1 ? 's' : ''}',
              style:
                  AppText.sans(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF1A1408),
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              disabledBackgroundColor: AppColors.bg3,
              disabledForegroundColor: AppColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}
