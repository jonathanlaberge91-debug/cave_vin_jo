import 'dart:async';
import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/cellar.dart';
import '../services/cellar_service.dart';
import '../services/govee_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class GoveeSensorsScreen extends StatefulWidget {
  const GoveeSensorsScreen({super.key});

  @override
  State<GoveeSensorsScreen> createState() => _GoveeSensorsScreenState();
}

class _GoveeSensorsScreenState extends State<GoveeSensorsScreen> {
  List<GoveeSensor>? _sensors;
  List<Cellar> _cellars = [];
  StreamSubscription<List<Cellar>>? _cellarSub;
  Timer? _timer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _cellarSub = CellarService.watch().listen((list) {
      if (mounted) setState(() => _cellars = list);
    });
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _fetch());
  }

  @override
  void dispose() {
    _cellarSub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final cached = await GoveeService.loadCache();
    if (mounted && cached.isNotEmpty) setState(() => _sensors = cached);
    _fetch();
  }

  Future<void> _fetch() async {
    if (!GoveeService.isConfigured) return;
    if (mounted) setState(() => _loading = true);
    try {
      final devices = await GoveeService.fetchDevices();
      if (devices.isEmpty) {
        if (mounted) setState(() { _sensors = []; _loading = false; });
        return;
      }
      final statuses = await Future.wait(
        devices.map((d) => GoveeService.fetchStatus(d.device, d.sku, d.name)),
      );
      final results = statuses.whereType<GoveeSensor>().toList();
      if (mounted) {
        setState(() { _sensors = results; _loading = false; });
        GoveeService.saveCache(results);
        for (final s in results) {
          GoveeService.recordReading(s);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static double? _goveeTemp(double? raw) {
    if (raw == null) return null;
    if (raw > 1000) return raw / 100;
    if (raw > 45) return (raw - 32) * 5 / 9;
    return raw;
  }

  Future<void> _assign(GoveeSensor sensor, String? cellarId, String? position) async {
    for (final c in _cellars) {
      if (c.goveeTopDevice == sensor.device) {
        await CellarService.update(c.id, clearGoveeTop: true);
      }
      if (c.goveeBottomDevice == sensor.device) {
        await CellarService.update(c.id, clearGoveeBottom: true);
      }
    }
    if (cellarId == null || position == null) return;
    if (position == 'top') {
      await CellarService.update(cellarId, goveeTopDevice: sensor.device);
    } else {
      await CellarService.update(cellarId, goveeBottomDevice: sensor.device);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!GoveeService.isConfigured) {
      return Center(
        child: Text(
          'Clé API Govee non configurée.\nVa dans Paramètres > Clés API.',
          textAlign: TextAlign.center,
          style: AppText.sans(color: AppColors.text3, fontSize: 13),
        ),
      );
    }

    if (_sensors == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    if (_sensors!.isEmpty) {
      return Center(
        child: Text(
          'Aucun capteur Govee trouvé.',
          style: AppText.sans(color: AppColors.text3, fontSize: 13),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Capteurs Govee',
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
                  '${_sensors!.length}',
                  style: AppText.sans(
                    color: AppColors.text2,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              if (_loading)
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.gold),
                ),
              const SizedBox(width: 8),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _fetch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh, size: 14, color: AppColors.text2),
                        const SizedBox(width: 4),
                        Text('Rafraîchir', style: AppText.sans(color: AppColors.text2, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final s in _sensors!) _buildCard(s),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(GoveeSensor sensor) {
    final tempC = _goveeTemp(sensor.temperature);
    final hum = sensor.humidity;

    Cellar? assignedCellar;
    String? assignedPosition;
    for (final c in _cellars) {
      if (c.goveeTopDevice == sensor.device) {
        assignedCellar = c;
        assignedPosition = 'top';
        break;
      }
      if (c.goveeBottomDevice == sensor.device) {
        assignedCellar = c;
        assignedPosition = 'bottom';
        break;
      }
    }

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: sensor.online ? const Color(0xFF7CD492) : const Color(0xFFE8667A),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (sensor.online ? const Color(0xFF7CD492) : const Color(0xFFE8667A)).withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sensor.name,
                  style: AppText.sans(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (tempC != null) ...[
                const Icon(Icons.thermostat, size: 16, color: AppColors.gold2),
                const SizedBox(width: 4),
                Text(
                  '${tempC.toStringAsFixed(1)}°C',
                  style: AppText.sans(color: AppColors.gold2, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
              if (tempC != null && hum != null) const SizedBox(width: 14),
              if (hum != null) ...[
                const Icon(Icons.water_drop_outlined, size: 14, color: Color(0xFF70B8E8)),
                const SizedBox(width: 3),
                Text(
                  '${hum.toStringAsFixed(0)}%',
                  style: AppText.sans(color: const Color(0xFF70B8E8), fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
              if (tempC == null && hum == null)
                Text('—', style: AppText.sans(color: AppColors.text3, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sensor.online ? 'En ligne' : 'Hors ligne',
            style: AppText.sans(
              color: sensor.online ? const Color(0xFF7CD492) : const Color(0xFFE8667A),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          _buildAssignment(sensor, assignedCellar, assignedPosition),
          const SizedBox(height: 10),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => showGoveeHistory(context, sensor),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.bg3,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.show_chart,
                        size: 13, color: AppColors.text2),
                    const SizedBox(width: 4),
                    Text('Historique',
                        style: AppText.sans(
                            color: AppColors.text2, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignment(GoveeSensor sensor, Cellar? current, String? position) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border2),
          ),
          child: DropdownButton<String?>(
            value: current?.id,
            isExpanded: true,
            underline: const SizedBox(),
            isDense: true,
            dropdownColor: AppColors.bg3,
            style: AppText.sans(color: AppColors.text, fontSize: 11),
            hint: Text('— Aucun cellier', style: AppText.sans(color: AppColors.text3, fontSize: 11)),
            icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.text3),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('— Aucun', style: AppText.sans(color: AppColors.text3, fontSize: 11)),
              ),
              ..._cellars.map((c) => DropdownMenuItem<String?>(
                value: c.id,
                child: Text(
                  c.name.isNotEmpty ? c.name : 'Cellier ${c.number}',
                  style: AppText.sans(color: AppColors.text, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              )),
            ],
            onChanged: (cellarId) {
              final pos = (current?.id == cellarId) ? (position ?? 'top') : 'top';
              _assign(sensor, cellarId, cellarId == null ? null : pos);
            },
          ),
        ),
        if (current != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _posBtn('Haut', position == 'top', () => _assign(sensor, current.id, 'top'))),
              const SizedBox(width: 4),
              Expanded(child: _posBtn('Bas', position == 'bottom', () => _assign(sensor, current.id, 'bottom'))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _posBtn(String label, bool selected, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.bg3,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: selected ? AppColors.gold : AppColors.border2),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.sans(
              color: selected ? AppColors.gold : AppColors.text3,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

double? _goveeNormalizeTemp(double? raw) {
  if (raw == null) return null;
  if (raw > 1000) return raw / 100;
  if (raw > 45) return (raw - 32) * 5 / 9;
  return raw;
}

Future<void> showGoveeHistory(BuildContext context, GoveeSensor sensor) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (_) => GoveeHistoryDialog(sensor: sensor),
  );
}

class GoveeHistoryDialog extends StatefulWidget {
  final GoveeSensor sensor;
  const GoveeHistoryDialog({super.key, required this.sensor});

  @override
  State<GoveeHistoryDialog> createState() => _GoveeHistoryDialogState();
}

class _GoveeHistoryDialogState extends State<GoveeHistoryDialog> {
  int _windowIdx = 0;
  List<GoveeReading>? _readings;
  bool _loading = true;

  static const _windows = [
    (Duration(hours: 24), '24 h'),
    (Duration(days: 7), '7 jours'),
    (Duration(days: 30), '30 jours'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await GoveeService.getHistory(
      widget.sensor.device,
      window: _windows[_windowIdx].$1,
    );
    if (!mounted) return;
    setState(() {
      _readings = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final modalW = screenW < 720 ? screenW - 32 : 680.0;
    final modalH = screenH * 0.78;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: modalW,
        height: modalH,
        decoration: BoxDecoration(
          color: AppColors.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sensor.name,
                        style: AppText.serif(
                          color: AppColors.gold2,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Historique des relevés',
                        style: AppText.sans(
                            color: AppColors.text3, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border2),
                    ),
                    child: const Icon(Icons.close, size: 16, color: AppColors.text2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < _windows.length; i++) ...[
                  GestureDetector(
                    onTap: () {
                      if (_windowIdx == i) return;
                      setState(() => _windowIdx = i);
                      _load();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _windowIdx == i
                            ? AppColors.gold.withValues(alpha: 0.15)
                            : AppColors.bg3,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _windowIdx == i
                              ? AppColors.gold
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        _windows[i].$2,
                        style: AppText.sans(
                          color: _windowIdx == i
                              ? AppColors.gold
                              : AppColors.text2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (i < _windows.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    final r = _readings ?? [];
    if (r.length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timeline,
                size: 36, color: AppColors.text3),
            const SizedBox(height: 12),
            Text(
              r.isEmpty
                  ? 'Aucune donnée pour cette période.'
                  : 'Pas assez de données pour tracer une courbe.',
              style: AppText.sans(color: AppColors.text3, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              'Les relevés sont enregistrés à chaque rafraîchissement\nde la page Capteurs (max. 1 / 5 min).',
              textAlign: TextAlign.center,
              style: AppText.sans(color: AppColors.text3, fontSize: 11),
            ),
          ],
        ),
      );
    }

    final temps = <double>[];
    final hums = <double>[];
    final tempSpots = <FlSpot>[];
    final humSpots = <FlSpot>[];
    final start = r.first.timestamp.millisecondsSinceEpoch.toDouble();
    final end = r.last.timestamp.millisecondsSinceEpoch.toDouble();
    for (final rd in r) {
      final x = rd.timestamp.millisecondsSinceEpoch.toDouble();
      final t = _goveeNormalizeTemp(rd.temperature);
      if (t != null) {
        tempSpots.add(FlSpot(x, t));
        temps.add(t);
      }
      final h = rd.humidity;
      if (h != null) {
        humSpots.add(FlSpot(x, h));
        hums.add(h);
      }
    }

    final tempMin = temps.isEmpty ? 0.0 : temps.reduce(math.min);
    final tempMax = temps.isEmpty ? 0.0 : temps.reduce(math.max);
    final tempAvg = temps.isEmpty
        ? 0.0
        : temps.reduce((a, b) => a + b) / temps.length;
    final humMin = hums.isEmpty ? 0.0 : hums.reduce(math.min);
    final humMax = hums.isEmpty ? 0.0 : hums.reduce(math.max);
    final humAvg =
        hums.isEmpty ? 0.0 : hums.reduce((a, b) => a + b) / hums.length;

    final tempColor = AppColors.gold;
    const humColor = Color(0xFF70B8E8);

    return Column(
      children: [
        Row(
          children: [
            if (temps.isNotEmpty)
              Expanded(
                child: _statBlock(
                  label: 'Température',
                  color: tempColor,
                  current: '${tempAvg.toStringAsFixed(1)}°C',
                  range:
                      '${tempMin.toStringAsFixed(1)} – ${tempMax.toStringAsFixed(1)}°C',
                ),
              ),
            if (temps.isNotEmpty && hums.isNotEmpty)
              const SizedBox(width: 12),
            if (hums.isNotEmpty)
              Expanded(
                child: _statBlock(
                  label: 'Humidité',
                  color: humColor,
                  current: '${humAvg.toStringAsFixed(0)}%',
                  range:
                      '${humMin.toStringAsFixed(0)} – ${humMax.toStringAsFixed(0)}%',
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (temps.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Température',
                style: AppText.sans(
                    color: tempColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _buildLineChart(
              spots: tempSpots,
              color: tempColor,
              minY: tempMin - 1,
              maxY: tempMax + 1,
              minX: start,
              maxX: end,
              suffix: '°C',
              decimals: 1,
            ),
          ),
        ],
        if (temps.isNotEmpty && hums.isNotEmpty) const SizedBox(height: 12),
        if (hums.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Humidité',
                style: AppText.sans(
                    color: humColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _buildLineChart(
              spots: humSpots,
              color: humColor,
              minY: math.max(0, humMin - 5),
              maxY: math.min(100, humMax + 5),
              minX: start,
              maxX: end,
              suffix: '%',
              decimals: 0,
            ),
          ),
        ],
      ],
    );
  }

  Widget _statBlock({
    required String label,
    required Color color,
    required String current,
    required String range,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.bg3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.sans(
                  color: AppColors.text3,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                current,
                style: AppText.sans(
                    color: color, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'moy.',
                  style: AppText.sans(color: AppColors.text3, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('Min/Max : $range',
              style: AppText.sans(color: AppColors.text3, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildLineChart({
    required List<FlSpot> spots,
    required Color color,
    required double minY,
    required double maxY,
    required double minX,
    required double maxX,
    required String suffix,
    required int decimals,
  }) {
    final spanMs = maxX - minX;
    final showTime = spanMs <= Duration(days: 1).inMilliseconds * 1.5;

    return LineChart(LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: ((maxY - minY) / 4).clamp(0.5, 100).toDouble(),
        getDrawingHorizontalLine: (_) =>
            FlLine(color: AppColors.border, strokeWidth: 0.5),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            interval: (spanMs / 5).clamp(60000, double.infinity),
            getTitlesWidget: (v, _) {
              final dt = DateTime.fromMillisecondsSinceEpoch(v.toInt());
              final label = showTime
                  ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
                  : '${dt.day}/${dt.month}';
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(label,
                    style: AppText.sans(
                        color: AppColors.text3, fontSize: 9)),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            interval: ((maxY - minY) / 4).clamp(0.5, 100).toDouble(),
            getTitlesWidget: (v, _) => Text(
              '${v.toStringAsFixed(decimals)}$suffix',
              style: AppText.sans(color: AppColors.text3, fontSize: 9),
            ),
          ),
        ),
      ),
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData:
              BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => AppColors.bg3,
          getTooltipItems: (touched) => touched.map((s) {
            final dt =
                DateTime.fromMillisecondsSinceEpoch(s.x.toInt());
            final time =
                '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            return LineTooltipItem(
              '${s.y.toStringAsFixed(decimals)}$suffix\n$time',
              AppText.sans(color: color, fontSize: 11),
            );
          }).toList(),
        ),
      ),
    ));
  }
}
