import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class CascadeFilterState {
  final Set<String> countries;
  final Set<String> regions;
  final Set<String> appellations;
  final Set<String> climats;

  const CascadeFilterState({
    this.countries = const {},
    this.regions = const {},
    this.appellations = const {},
    this.climats = const {},
  });

  bool get isEmpty =>
      countries.isEmpty &&
      regions.isEmpty &&
      appellations.isEmpty &&
      climats.isEmpty;

  CascadeFilterState copyWith({
    Set<String>? countries,
    Set<String>? regions,
    Set<String>? appellations,
    Set<String>? climats,
  }) =>
      CascadeFilterState(
        countries: countries ?? this.countries,
        regions: regions ?? this.regions,
        appellations: appellations ?? this.appellations,
        climats: climats ?? this.climats,
      );

  bool matchesWine({
    required String country,
    required String region,
    required String appellation,
    required String climat,
  }) {
    if (countries.isNotEmpty && !countries.contains(country)) return false;
    if (regions.isNotEmpty && !regions.contains(region)) return false;
    if (appellations.isNotEmpty && !appellations.contains(appellation)) return false;
    if (climats.isNotEmpty && !climats.contains(climat)) return false;
    return true;
  }
}

class CascadeFilterData {
  final String country;
  final String region;
  final String appellation;
  final String climat;

  const CascadeFilterData({
    required this.country,
    required this.region,
    required this.appellation,
    required this.climat,
  });
}

class CascadeFilterBar extends StatelessWidget {
  final CascadeFilterState filter;
  final List<CascadeFilterData> allItems;
  final ValueChanged<CascadeFilterState> onChanged;

  const CascadeFilterBar({
    super.key,
    required this.filter,
    required this.allItems,
    required this.onChanged,
  });

  static const _burgundyNames = {'bourgogne', 'burgundy', 'bourgogne-franche-comté'};

  @override
  Widget build(BuildContext context) {
    final countries = allItems
        .map((e) => e.country)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (countries.isEmpty) return const SizedBox.shrink();

    final filteredByCountry = filter.countries.isEmpty
        ? allItems
        : allItems.where((e) => filter.countries.contains(e.country)).toList();

    final regions = filteredByCountry
        .map((e) => e.region)
        .where((r) => r.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final filteredByRegion = filter.regions.isEmpty
        ? filteredByCountry
        : filteredByCountry.where((e) => filter.regions.contains(e.region)).toList();

    final appellations = filteredByRegion
        .map((e) => e.appellation)
        .where((a) => a.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final showClimat = filter.regions.any(
      (r) => _burgundyNames.contains(r.toLowerCase()),
    );
    final climats = showClimat
        ? (filteredByRegion
            .where((e) => _burgundyNames.contains(e.region.toLowerCase()))
            .map((e) => e.climat)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort())
        : <String>[];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildGroup('Pays', countries, filter.countries, (v) {
            var next = filter.copyWith(countries: v);
            if (v.isEmpty || v != filter.countries) {
              next = next.copyWith(regions: {}, appellations: {}, climats: {});
            }
            onChanged(next);
          }),
          if (filter.countries.isNotEmpty && regions.isNotEmpty) ...[
            _divider(),
            _buildGroup('Région', regions, filter.regions, (v) {
              var next = filter.copyWith(regions: v);
              if (v.isEmpty || v != filter.regions) {
                next = next.copyWith(appellations: {}, climats: {});
              }
              onChanged(next);
            }),
          ],
          if (filter.regions.isNotEmpty && appellations.isNotEmpty) ...[
            _divider(),
            _buildGroup('Appellation', appellations, filter.appellations, (v) {
              onChanged(filter.copyWith(appellations: v));
            }),
          ],
          if (filter.regions.isNotEmpty && climats.isNotEmpty) ...[
            _divider(),
            _buildGroup('Climat', climats, filter.climats, (v) {
              onChanged(filter.copyWith(climats: v));
            }),
          ],
          if (!filter.isEmpty) ...[
            const SizedBox(width: 8),
            _resetButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildGroup(
    String label,
    List<String> options,
    Set<String> selected,
    ValueChanged<Set<String>> onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppText.sans(
            color: AppColors.text3,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 6),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: options.map((opt) {
            final active = selected.contains(opt);
            return _FilterChip(
              label: opt,
              active: active,
              onTap: () {
                final next = {...selected};
                if (active) {
                  next.remove(opt);
                } else {
                  next.add(opt);
                }
                onChanged(next);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: AppColors.border,
      );

  Widget _resetButton() {
    return InkWell(
      onTap: () => onChanged(const CascadeFilterState()),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x44E07060)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.close, size: 10, color: Color(0xFFE07060)),
            const SizedBox(width: 4),
            Text(
              'Effacer',
              style: AppText.sans(
                color: const Color(0xFFE07060),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0x29C9A84C) : AppColors.bg3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? const Color(0x66C9A84C) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppText.sans(
            color: active ? AppColors.gold2 : AppColors.text3,
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
