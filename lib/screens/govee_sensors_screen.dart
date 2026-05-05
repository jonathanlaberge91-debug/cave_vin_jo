import 'dart:async';
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
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in _sensors!) _buildCard(s),
              ],
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
