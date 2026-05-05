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
import '../services/govee_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/wine_type_helpers.dart';
import '../widgets/cave_table.dart' show GardeInfo;
import '../widgets/native_image.dart';
import '../dialogs/cellar_form_dialog.dart';
import '../widgets/cascade_filter.dart';
import 'slot_picker.dart';
import 'wine_cellar_screen.dart' show CellarStatus;
import 'wine_detail_screen.dart';

double _cellSizeFromZoom(int zoom) => 14.0 + (zoom - 1) * 3.5;

class CellierScreen extends StatefulWidget {
  final CascadeFilterState filter;
  final ValueChanged<CascadeFilterState> onFilterChanged;
  const CellierScreen({super.key, required this.filter, required this.onFilterChanged});

  @override
  State<CellierScreen> createState() => _CellierScreenState();
}

class _CellierScreenState extends State<CellierScreen> {
  static const _cloudUrl = 'https://us-east1-cave-vin-jo.cloudfunctions.net/tuyaProxy';
  final _isDragging = ValueNotifier<bool>(false);
  List<CellarStatus>? _physical;
  String _bridgeUrl = 'http://localhost:8765';
  bool _useCloud = false;
  Timer? _bridgeTimer;
  final Set<int> _sending = {};
  final Map<int, int> _optimisticTemp = {};
  List<GoveeSensor>? _goveeSensors;
  Timer? _goveeTimer;

  // Cached streams — never recreated, avoids StreamBuilder flicker on every setState
  late final Stream<List<Cellar>> _cellarStream;
  late final Stream<List<Wine>> _wineStream;
  late final Stream<List<Bottle>> _unplacedStream;
  final Map<String, Stream<List<Bottle>>> _bottleStreams = {};

  Stream<List<Bottle>> _bottleStreamFor(String cellarId) =>
      _bottleStreams.putIfAbsent(cellarId, () => CaveService.bottlesByCellar(cellarId));

  @override
  void initState() {
    super.initState();
    _cellarStream = CellarService.watch();
    _wineStream = CaveService.wines();
    _unplacedStream = CaveService.unplacedBottlesInCave();
    _loadCachedTuya();
    _loadBridge();
    _loadCachedGovee();
    _goveeTimer = Timer.periodic(const Duration(seconds: 60), (_) => _fetchGovee());
  }

  @override
  void dispose() {
    _goveeTimer?.cancel();
    _bridgeTimer?.cancel();
    _isDragging.dispose();
    super.dispose();
  }

  Future<void> _loadCachedTuya() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cellier_tuya_cache');
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => CellarStatus.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted && list.isNotEmpty) setState(() => _physical = list);
    } catch (_) {}
  }

  Future<void> _saveTuyaCache(String jsonBody) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cellier_tuya_cache', jsonBody);
  }

  Future<void> _loadBridge() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('wine_cellr_bridge_url');
    if (saved != null && saved.isNotEmpty) _bridgeUrl = saved;
    _fetchBridge();
    _bridgeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchBridge());
  }

  String get _activeUrl => _useCloud ? _cloudUrl : _bridgeUrl;

  Future<void> _fetchBridge() async {
    if (!_useCloud) {
      try {
        final res = await http.get(Uri.parse('$_bridgeUrl/status-all')).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final list = (jsonDecode(res.body) as List)
              .map((e) => CellarStatus.fromJson(e as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() { _physical = list; _useCloud = false; _optimisticTemp.clear(); });
          _saveTuyaCache(res.body);
          return;
        }
      } catch (_) {}
    }
    try {
      final res = await http.get(Uri.parse('$_cloudUrl/status-all')).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => CellarStatus.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() { _physical = list; _useCloud = true; _optimisticTemp.clear(); });
        _saveTuyaCache(res.body);
      }
    } catch (_) {}
  }

  int? _findPhysicalIndex(Cellar c) {
    if (_physical == null) return null;
    final vName = (c.name.isEmpty ? 'Cellier ${c.number}' : c.name).toUpperCase();
    for (var i = 0; i < _physical!.length; i++) {
      final key = _physical![i].name.trim().split(RegExp(r'\s+')).last.toUpperCase();
      if (key.length <= 2 && vName.contains(key)) return i;
    }
    return null;
  }

  Future<http.Response> _rawPost(int idx, String dps, dynamic value) {
    return http.post(
      Uri.parse('$_activeUrl/set/$idx'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dps': dps, 'value': value}),
    ).timeout(const Duration(seconds: 15));
  }

  Future<void> _sendDps(int idx, String dps, dynamic value) async {
    if (_sending.contains(idx)) return;
    setState(() => _sending.add(idx));
    try {
      final needsUnlock = dps == '106' || dps == '107' || dps == '102';
      final wasLocked = _physical != null && idx < _physical!.length && _physical![idx].keyLock;
      if (needsUnlock && wasLocked) {
        await _rawPost(idx, '5', false);
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      final res = await _rawPost(idx, dps, value);
      if (res.statusCode != 200 && mounted) {
        String error = 'Erreur ${res.statusCode}';
        try {
          final body = jsonDecode(res.body);
          error = body['error']?.toString() ?? error;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error, style: AppText.sans(color: AppColors.text)), backgroundColor: const Color(0xFF6E2A20)),
        );
      }
      if (needsUnlock && wasLocked) {
        await Future.delayed(const Duration(milliseconds: 1500));
        await _rawPost(idx, '5', true);
      }
    } catch (_) {}
    if (mounted) setState(() => _sending.remove(idx));
    _fetchBridge();
  }

  Future<void> _loadCachedGovee() async {
    final cached = await GoveeService.loadCache();
    if (mounted && cached.isNotEmpty) {
      setState(() => _goveeSensors = cached);
    }
    _fetchGovee();
  }

  Future<void> _fetchGovee() async {
    if (!GoveeService.isConfigured) return;
    try {
      final devices = await GoveeService.fetchDevices();
      if (devices.isEmpty) {
        if (mounted) setState(() => _goveeSensors = []);
        return;
      }
      final statuses = await Future.wait(
        devices.map((d) => GoveeService.fetchStatus(d.device, d.sku, d.name)),
      );
      final results = statuses.whereType<GoveeSensor>().toList();
      if (mounted && results.isNotEmpty) {
        setState(() => _goveeSensors = results);
        GoveeService.saveCache(results);
      }
    } catch (_) {}
  }

  static double? _goveeTemp(double? raw) {
    if (raw == null) return null;
    if (raw > 1000) return raw / 100;
    if (raw > 45) return (raw - 32) * 5 / 9;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Cellar>>(
      stream: _cellarStream,
      builder: (context, snap) {
        if (snap.data == null) {
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

  List<CascadeFilterData> _buildFilterData(List<Wine> wines) {
    return wines
        .where((w) => w.country.isNotEmpty || w.region.isNotEmpty)
        .map((w) => CascadeFilterData(
              country: w.country,
              region: w.region,
              appellation: w.appellation,
              climat: w.climat,
            ))
        .toList();
  }

  bool _wineMatchesFilter(Wine? wine) {
    if (widget.filter.isEmpty) return true;
    if (wine == null) return false;
    return widget.filter.matchesWine(
      country: wine.country,
      region: wine.region,
      appellation: wine.appellation,
      climat: wine.climat,
    );
  }

  Widget _buildDesktopLayout(List<Cellar> cellars) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<Wine>>(
          stream: _wineStream,
          builder: (context, wSnap) {
            final wines = wSnap.data ?? [];
            final filterData = wines.isEmpty ? <CascadeFilterData>[] : _buildFilterData(wines);
            if (!filterData.any((e) => e.country.isNotEmpty)) return const SizedBox.shrink();
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.bg2,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: CascadeFilterBar(
                filter: widget.filter,
                allItems: filterData,
                onChanged: widget.onFilterChanged,
              ),
            );
          },
        ),
        Expanded(
          child: Padding(
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
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<Cellar> cellars) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StreamBuilder<List<Wine>>(
          stream: _wineStream,
          builder: (context, wSnap) {
            final wines = wSnap.data ?? [];
            final filterData = wines.isEmpty ? <CascadeFilterData>[] : _buildFilterData(wines);
            if (!filterData.any((e) => e.country.isNotEmpty)) return const SizedBox.shrink();
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.bg2,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: CascadeFilterBar(
                filter: widget.filter,
                allItems: filterData,
                onChanged: widget.onFilterChanged,
              ),
            );
          },
        ),
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
    return StreamBuilder<List<Wine>>(
      stream: _wineStream,
      builder: (context, winesSnap) {
        final wines = winesSnap.data ?? [];
        final winesById = {for (final w in wines) w.id: w};

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          itemCount: cellars.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return _buildMobileAddCellarBtn(cellars);
            final ai = i;
            final c = cellars[ai - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildMobileCellarCard(c, winesById, 0, cellarIndex: ai - 1),
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

  Widget _buildMobileCellarCard(Cellar c, Map<String, Wine> winesById, double _, {int cellarIndex = -1}) {
    return StreamBuilder<List<Bottle>>(
      stream: _bottleStreamFor(c.id),
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
        final pIdx = _findPhysicalIndex(c);
        final status = pIdx != null ? _physical![pIdx] : null;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopLedBar(status: status, physicalIdx: pIdx, height: 6),
              _buildCellarHeader(c, occupiedCount, status, pIdx, compact: true),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLightBar(isLeft: true, status: status, physicalIdx: pIdx, width: 6),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const labelW = 24.0;
                            const gap = 1.0;
                            final availW = constraints.maxWidth - labelW;
                            final fitCellSize = (availW - gap * (c.cols - 1)) / c.cols;
                            final mobileCellSize = fitCellSize.clamp(8.0, 44.0);
                            return _buildGridStatic(c, occupied, winesById, cellSize: mobileCellSize, anchors: anchors);
                          },
                        ),
                      ),
                    ),
                    _buildLightBar(isLeft: false, status: status, physicalIdx: pIdx, width: 6),
                  ],
                ),
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
          stream: _wineStream,
          builder: (context, winesSnap) {
            final wines = winesSnap.data ?? [];
            final winesById = {for (final w in wines) w.id: w};

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < cellars.length; i++) ...[
                        SizedBox(
                          width: _cardWidth(cellars[i], cellSize),
                          height: constraints.maxHeight - 40,
                          child: _buildCellarCard(cellars[i], winesById, cellSize, cellarIndex: i),
                        ),
                        if (i < cellars.length - 1) const SizedBox(width: 20),
                      ],
                    ],
                  ),
                );
              },
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
      stream: _bottleStreamFor(c.id),
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
        final pIdx = _findPhysicalIndex(c);
        final status = pIdx != null ? _physical![pIdx] : null;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopLedBar(status: status, physicalIdx: pIdx, height: 12),
              _buildCellarHeader(c, occupiedCount, status, pIdx),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLightBar(isLeft: true, status: status, physicalIdx: pIdx),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
                        child: _buildGridStatic(c, occupied, winesById, cellSize: cellSize, anchors: anchors),
                      ),
                    ),
                    _buildLightBar(isLeft: false, status: status, physicalIdx: pIdx),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  GoveeSensor? _findSensorByDevice(String? device) {
    if (device == null || device.isEmpty || _goveeSensors == null) return null;
    try {
      return _goveeSensors!.firstWhere((s) => s.device == device);
    } catch (_) {
      return null;
    }
  }

  Widget _buildCellarHeader(Cellar c, int occupiedCount, CellarStatus? status, int? pIdx, {bool compact = false}) {
    final topSensor = _findSensorByDevice(c.goveeTopDevice);
    final bottomSensor = _findSensorByDevice(c.goveeBottomDevice);
    final topTemp = _goveeTemp(topSensor?.temperature);
    final topHum = topSensor?.humidity;
    final bottomTemp = _goveeTemp(bottomSensor?.temperature);
    final bottomHum = bottomSensor?.humidity;

    final bool hasTuya = status != null && pIdx != null;
    final bool busy = hasTuya && _sending.contains(pIdx);
    final bool isCelsius = status?.tempUnit != 'f';
    final int p = pIdx ?? 0;
    final int? target = (status == null || pIdx == null)
        ? null
        : (_optimisticTemp[p] ?? (isCelsius ? status.targetTemp : status.targetTempF));
    final String unit = isCelsius ? '°C' : '°F';
    final Color powerColor = (status?.power ?? false) ? const Color(0xFF7CD492) : const Color(0xFFE8667A);
    final Color lockColor = (status?.keyLock ?? false) ? const Color(0xFFE8667A) : const Color(0xFF7CD492);
    final double fillRatio = c.totalSlots > 0 ? occupiedCount / c.totalSlots : 0.0;

    final double btnSize = compact ? 24.0 : 30.0;
    final double tempFontSize = compact ? 17.0 : 21.0;
    final double sensorFontSize = compact ? 13.0 : 15.0;
    final double labelFontSize = compact ? 7.0 : 8.0;

    Widget goveeCol(bool isTop, double? temp, double? hum) {
      final Color color = isTop ? const Color(0xFFE8A04C) : const Color(0xFF70B8E8);
      final String label = isTop ? '▲ HAUT' : '▼ BAS';
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 8.0 : 10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: AppText.sans(color: AppColors.text3, fontSize: labelFontSize, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            SizedBox(height: compact ? 4.0 : 5.0),
            Text(
              temp != null ? '${temp.toStringAsFixed(1)}°C' : '—',
              style: AppText.sans(color: temp != null ? color : AppColors.text3, fontSize: sensorFontSize, fontWeight: FontWeight.w700),
            ),
            if (hum != null) ...[
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.water_drop, size: 9, color: Color(0xFF70B8E8)),
                  const SizedBox(width: 2),
                  Text('${hum.toStringAsFixed(0)}%', style: AppText.sans(color: AppColors.text3, fontSize: compact ? 9.0 : 10.0)),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget consigneCol() {
      return Padding(
        padding: EdgeInsets.fromLTRB(compact ? 8.0 : 10.0, compact ? 8.0 : 10.0, compact ? 8.0 : 10.0, compact ? 8.0 : 10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('CONSIGNE', style: AppText.sans(color: AppColors.text3, fontSize: labelFontSize, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            SizedBox(height: compact ? 5.0 : 6.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ctrlTap(
                  onTap: (!hasTuya || busy) ? null : () {
                    setState(() => _optimisticTemp[p] = (target ?? 0) - 1);
                    _sendDps(p, '2', (target ?? 0) - 1);
                  },
                  child: Container(
                    width: btnSize, height: btnSize,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border2),
                    ),
                    child: Center(child: Icon(Icons.remove, size: btnSize * 0.5, color: AppColors.text2)),
                  ),
                ),
                SizedBox(width: compact ? 5.0 : 10.0),
                SizedBox(
                  width: compact ? 34.0 : 52.0,
                  child: Text(
                    hasTuya ? '$target$unit' : '—',
                    textAlign: TextAlign.center,
                    style: AppText.sans(color: AppColors.gold2, fontSize: tempFontSize, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(width: compact ? 5.0 : 10.0),
                _ctrlTap(
                  onTap: (!hasTuya || busy) ? null : () {
                    setState(() => _optimisticTemp[p] = (target ?? 0) + 1);
                    _sendDps(p, '2', (target ?? 0) + 1);
                  },
                  child: Container(
                    width: btnSize, height: btnSize,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border2),
                    ),
                    child: Center(child: Icon(Icons.add, size: btnSize * 0.5, color: AppColors.text2)),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 4.0 : 5.0),
            if (hasTuya)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ctrlTap(
                    onTap: busy ? null : () => _sendDps(p, '1', !(status?.power ?? false)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: powerColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: powerColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.power_settings_new, size: 9, color: powerColor),
                          const SizedBox(width: 3),
                          Text((status?.power ?? false) ? 'ON' : 'OFF', style: AppText.sans(color: powerColor, fontSize: 9, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  _ctrlTap(
                    onTap: busy ? null : () => _sendDps(p, '5', !(status?.keyLock ?? false)),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: lockColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: lockColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon((status?.keyLock ?? false) ? Icons.lock_outline : Icons.lock_open_outlined, size: 11, color: lockColor),
                    ),
                  ),
                  const SizedBox(width: 5),
                  _ctrlTap(
                    onTap: busy ? null : () => _sendDps(p, '4', isCelsius ? 'f' : 'c'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border2),
                      ),
                      child: Text(unit, style: AppText.sans(color: AppColors.gold2, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  if (busy) ...[
                    const SizedBox(width: 5),
                    const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold)),
                  ],
                ],
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(18, compact ? 10.0 : 12.0, 18, compact ? 7.0 : 9.0),
          child: Text(
            c.name.isEmpty ? 'Cellier ${c.number}' : c.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.serif(color: AppColors.gold2, fontSize: compact ? 15.0 : 18.0, fontWeight: FontWeight.w600),
          ),
        ),
        if (status?.door == true)
          Container(
            decoration: const BoxDecoration(
              color: Color(0x1AE8A04C),
              border: Border(
                top: BorderSide(color: Color(0x44E8A04C)),
                bottom: BorderSide(color: Color(0x44E8A04C)),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.door_front_door_outlined, size: 13, color: Color(0xFFE8A04C)),
                const SizedBox(width: 6),
                Text('Porte ouverte', style: AppText.sans(color: const Color(0xFFE8A04C), fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        () {
          final showTopGovee = !compact || topTemp != null || (c.goveeTopDevice?.isNotEmpty ?? false);
          final showConsigne = !compact || hasTuya;
          final showBottomGovee = !compact || bottomTemp != null || (c.goveeBottomDevice?.isNotEmpty ?? false);
          if (!showTopGovee && !showConsigne && !showBottomGovee) return const SizedBox.shrink();
          return Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showTopGovee) ...[
                    Expanded(flex: 3, child: goveeCol(true, topTemp, topHum)),
                    if (showConsigne || showBottomGovee) Container(width: 1, color: AppColors.border),
                  ],
                  if (showConsigne) ...[
                    Expanded(flex: 4, child: consigneCol()),
                    if (showBottomGovee) Container(width: 1, color: AppColors.border),
                  ],
                  if (showBottomGovee) Expanded(flex: 3, child: goveeCol(false, bottomTemp, bottomHum)),
                ],
              ),
            ),
          );
        }(),
        Padding(
          padding: EdgeInsets.fromLTRB(compact ? 12.0 : 16.0, compact ? 7.0 : 8.0, compact ? 12.0 : 16.0, compact ? 8.0 : 10.0),
          child: Row(
            children: [
              Text('$occupiedCount / ${c.totalSlots}', style: AppText.sans(color: AppColors.text3, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(
                      children: [
                        Container(color: AppColors.bg),
                        FractionallySizedBox(
                          widthFactor: fillRatio.clamp(0.0, 1.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0x55C9A84C), Color(0xFFD4B96A)]),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(fillRatio * 100).round()}%', style: AppText.sans(color: AppColors.text3, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ctrlTap({required VoidCallback? onTap, required Widget child}) {
    return MouseRegion(
      cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(onTap: onTap, child: child),
    );
  }

  Widget _buildLightBar({
    required bool isLeft,
    CellarStatus? status,
    int? physicalIdx,
    double width = 12,
  }) {
    final sideLight = status?.sideLight ?? 0;
    final isBlue = status?.sideLightColor ?? false;
    final isOn = sideLight > 0;

    List<Color> gradientColors;
    List<BoxShadow> shadows;

    if (!isOn) {
      gradientColors = const [Color(0xFF2A2520), Color(0xFF242018), Color(0xFF2A2520)];
      shadows = const [];
    } else if (isBlue) {
      switch (sideLight) {
        case 25:
          gradientColors = const [Color(0xFF2A3A48), Color(0xFF253545), Color(0xFF202E3A), Color(0xFF253545), Color(0xFF2A3A48)];
          shadows = [BoxShadow(color: const Color(0xFF70B8E8).withValues(alpha: 0.06), blurRadius: 4)];
        case 50:
          gradientColors = const [Color(0xFF3A5A70), Color(0xFF305060), Color(0xFF284858), Color(0xFF305060), Color(0xFF3A5A70)];
          shadows = [BoxShadow(color: const Color(0xFF70B8E8).withValues(alpha: 0.15), blurRadius: 8)];
        case 75:
          gradientColors = const [Color(0xFF5A90B0), Color(0xFF4A80A0), Color(0xFF3A7090), Color(0xFF4A80A0), Color(0xFF5A90B0)];
          shadows = [
            BoxShadow(color: const Color(0xFF70B8E8).withValues(alpha: 0.3), blurRadius: 14),
            BoxShadow(color: const Color(0xFF70B8E8).withValues(alpha: 0.12), blurRadius: 28),
          ];
        default:
          gradientColors = const [Color(0xFF90D0F8), Color(0xFF70B8E8), Color(0xFF5A9DD8), Color(0xFF70B8E8), Color(0xFF90D0F8)];
          shadows = [
            BoxShadow(color: const Color(0xFF70B8E8).withValues(alpha: 0.55), blurRadius: 20),
            BoxShadow(color: const Color(0xFF70B8E8).withValues(alpha: 0.2), blurRadius: 40),
          ];
      }
    } else {
      switch (sideLight) {
        case 25:
          gradientColors = const [Color(0xFF5A5540), Color(0xFF504A38), Color(0xFF454030), Color(0xFF504A38), Color(0xFF5A5540)];
          shadows = [BoxShadow(color: const Color(0xFFF5ECD0).withValues(alpha: 0.06), blurRadius: 4)];
        case 50:
          gradientColors = const [Color(0xFF8A8468), Color(0xFF7A7858), Color(0xFF6A6850), Color(0xFF7A7858), Color(0xFF8A8468)];
          shadows = [BoxShadow(color: const Color(0xFFF5ECD0).withValues(alpha: 0.15), blurRadius: 8)];
        case 75:
          gradientColors = const [Color(0xFFD0C8A0), Color(0xFFC0B890), Color(0xFFB0A878), Color(0xFFC0B890), Color(0xFFD0C8A0)];
          shadows = [
            BoxShadow(color: const Color(0xFFF5ECD0).withValues(alpha: 0.3), blurRadius: 14),
            BoxShadow(color: const Color(0xFFF5ECD0).withValues(alpha: 0.12), blurRadius: 28),
          ];
        default:
          gradientColors = const [Color(0xFFFFFDE8), Color(0xFFF5ECD0), Color(0xFFE8DDB8), Color(0xFFF5ECD0), Color(0xFFFFFDE8)];
          shadows = [
            BoxShadow(color: const Color(0xFFF5ECD0).withValues(alpha: 0.5), blurRadius: 20),
            BoxShadow(color: const Color(0xFFF5ECD0).withValues(alpha: 0.2), blurRadius: 40),
          ];
      }
    }

    final borderRadius = BorderRadius.only(
      topRight: isLeft ? const Radius.circular(6) : Radius.zero,
      bottomRight: isLeft ? const Radius.circular(6) : Radius.zero,
      topLeft: !isLeft ? const Radius.circular(6) : Radius.zero,
      bottomLeft: !isLeft ? const Radius.circular(6) : Radius.zero,
    );

    return MouseRegion(
      cursor: physicalIdx != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: physicalIdx != null && status != null
            ? () => _showLightPicker(status, physicalIdx)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: width,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradientColors,
            ),
            boxShadow: shadows,
          ),
        ),
      ),
    );
  }

  void _showLightPicker(CellarStatus status, int idx) {
    showDialog(
      context: context,
      builder: (ctx) => _LightPickerDialog(
        currentIntensity: status.sideLight,
        isBlue: status.sideLightColor,
        onChanged: (dps, value) => _sendDps(idx, dps, value),
      ),
    );
  }

  Widget _buildTopLedBar({
    CellarStatus? status,
    int? physicalIdx,
    double height = 12,
  }) {
    final topLed = status?.topLed ?? 'OFF';
    final isOff = topLed == 'OFF';
    final isRed = topLed == 'red';

    Color barColor;
    List<BoxShadow> shadows;

    if (isOff) {
      barColor = const Color(0xFF2A2520);
      shadows = const [];
    } else if (isRed) {
      barColor = const Color(0xFFE8667A);
      shadows = [
        BoxShadow(color: const Color(0xFFE8667A).withValues(alpha: 0.5), blurRadius: 16),
        BoxShadow(color: const Color(0xFFE8667A).withValues(alpha: 0.2), blurRadius: 32),
      ];
    } else {
      barColor = const Color(0xFF70B8E8);
      shadows = [
        BoxShadow(color: const Color(0xFF70B8E8).withValues(alpha: 0.5), blurRadius: 16),
        BoxShadow(color: const Color(0xFF70B8E8).withValues(alpha: 0.2), blurRadius: 32),
      ];
    }

    return Align(
      alignment: Alignment.center,
      child: MouseRegion(
        cursor: physicalIdx != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: physicalIdx != null && status != null
              ? () => _showTopLedPicker(status, physicalIdx)
              : null,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: height,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(height / 2)),
                boxShadow: shadows,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTopLedPicker(CellarStatus status, int idx) {
    showDialog(
      context: context,
      builder: (ctx) {
        final options = [
          ('red', 'Rouge', const Color(0xFFE8667A)),
          ('blue', 'Bleu', const Color(0xFF70B8E8)),
          ('OFF', 'Éteinte', const Color(0xFF6A6050)),
        ];
        return AlertDialog(
          backgroundColor: AppColors.bg2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          title: Text('LEDs du haut',
              style: AppText.serif(color: AppColors.gold2, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        _sendDps(idx, '102', o.$1);
                        Navigator.pop(ctx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: status.topLed == o.$1
                              ? o.$3.withValues(alpha: 0.15)
                              : AppColors.bg3,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: status.topLed == o.$1
                                ? o.$3.withValues(alpha: 0.5)
                                : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 6,
                              decoration: BoxDecoration(
                                color: o.$3,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: o.$1 != 'OFF'
                                    ? [BoxShadow(color: o.$3.withValues(alpha: 0.4), blurRadius: 6)]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              o.$2,
                              style: AppText.sans(
                                color: status.topLed == o.$1 ? o.$3 : AppColors.text2,
                                fontSize: 14,
                                fontWeight: status.topLed == o.$1
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            if (status.topLed == o.$1)
                              Icon(Icons.check, size: 16, color: o.$3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
    const labelW = 24.0;
    const headerH = 18.0;
    const gap = 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
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
            isDimmed: widget.filter.isEmpty ? null : (wine) => !_wineMatchesFilter(wine),
          ),
          if (row < c.rows - 1) const SizedBox(height: gap),
        ],
      ],
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
    bool Function(Wine?)? isDimmed,
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
        final wine = winesById[anchor.wineId];
        children.add(
          _SlotCell(
            size: cellSize,
            spanWidth: w,
            span: span,
            label: formatFullSlotLabel(c.number, row, currentCol),
            shortLabel: '${formatRowLetter(row)}${currentCol + 1}',
            bottle: anchor,
            wine: wine,
            dimmed: isDimmed?.call(wine) ?? false,
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
    final wineBottles = allBottles
        .where((b) => b.wineId == wine.id && b.format == bottle.format)
        .toList();
    if (!mounted) return;
    showWineDetail(context, wine: wine, bottles: wineBottles, format: bottle.format);
  }

  Widget _buildUnplacedBar() {
    return StreamBuilder<List<Bottle>>(
      stream: _unplacedStream,
      builder: (context, bottlesSnap) {
        final bottles = bottlesSnap.data ?? [];
        return StreamBuilder<List<Wine>>(
          stream: _wineStream,
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
        goveeSensors: _goveeSensors ?? [],
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
      goveeTopDevice: result.goveeTopDevice,
      goveeBottomDevice: result.goveeBottomDevice,
    );
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
  final bool dimmed;
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
    this.dimmed = false,
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
          if (widget.dimmed) {
            child = Opacity(opacity: 0.2, child: child);
          }
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
  late final Stream<List<Bottle>> _unplacedStream;
  late final Stream<List<Wine>> _wineStream;

  @override
  void initState() {
    super.initState();
    _unplacedStream = CaveService.unplacedBottlesInCave();
    _wineStream = CaveService.wines();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Bottle>>(
      stream: _unplacedStream,
      builder: (context, bottlesSnap) {
        final bottles = bottlesSnap.data ?? [];
        return StreamBuilder<List<Wine>>(
          stream: _wineStream,
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

class _LightPickerDialog extends StatefulWidget {
  final int currentIntensity;
  final bool isBlue;
  final void Function(String dps, dynamic value) onChanged;

  const _LightPickerDialog({
    required this.currentIntensity,
    required this.isBlue,
    required this.onChanged,
  });

  @override
  State<_LightPickerDialog> createState() => _LightPickerDialogState();
}

class _LightPickerDialogState extends State<_LightPickerDialog> {
  late int _intensity;
  late bool _isBlue;

  @override
  void initState() {
    super.initState();
    _intensity = widget.currentIntensity;
    _isBlue = widget.isBlue;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _isBlue ? const Color(0xFF70B8E8) : const Color(0xFFF5ECD0);

    return AlertDialog(
      backgroundColor: AppColors.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      title: Text('Éclairage latéral',
          style: AppText.serif(color: AppColors.gold2, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _colorOption(
                  label: 'Blanc',
                  selected: !_isBlue,
                  color: const Color(0xFFF5ECD0),
                  barGradient: const [Color(0xFFE8DDB8), Color(0xFFF5ECD0)],
                  onTap: () {
                    setState(() => _isBlue = false);
                    widget.onChanged('107', false);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _colorOption(
                  label: 'Bleu',
                  selected: _isBlue,
                  color: const Color(0xFF70B8E8),
                  barGradient: const [Color(0xFF5A9DD8), Color(0xFF70B8E8)],
                  onTap: () {
                    setState(() => _isBlue = true);
                    widget.onChanged('107', true);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('INTENSITÉ',
              style: AppText.sans(
                  color: AppColors.text3,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final entry in [(0, 'OFF'), (25, '25%'), (50, '50%'), (75, '75%'), (100, '100%')]) ...[
                  if (entry.$1 > 0) const SizedBox(width: 4),
                  Expanded(
                    child: _intensityBar(
                      value: entry.$1,
                      label: entry.$2,
                      selected: _intensity == entry.$1,
                      activeColor: activeColor,
                      onTap: () {
                        setState(() => _intensity = entry.$1);
                        widget.onChanged('106', entry.$1);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorOption({
    required String label,
    required bool selected,
    required Color color,
    required List<Color> barGradient,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(colors: barGradient),
                  boxShadow: selected
                      ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6)]
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppText.sans(
                  color: selected ? color : AppColors.text3,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intensityBar({
    required int value,
    required String label,
    required bool selected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final fraction = value / 100.0;
    final barHeight = value == 0 ? 4.0 : 8.0 + 28.0 * fraction;

    Color barColor;
    if (value == 0) {
      barColor = selected ? const Color(0xFF5A5040) : const Color(0xFF3A3428);
    } else if (selected) {
      barColor = activeColor;
    } else {
      barColor = activeColor.withValues(alpha: 0.2 + 0.15 * fraction);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: barHeight,
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                border: selected
                    ? Border.all(color: activeColor.withValues(alpha: 0.6))
                    : Border.all(color: AppColors.border),
                boxShadow: selected && value > 0
                    ? [BoxShadow(color: activeColor.withValues(alpha: 0.3), blurRadius: 6)]
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppText.sans(
                color: selected ? AppColors.gold2 : AppColors.text3,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
