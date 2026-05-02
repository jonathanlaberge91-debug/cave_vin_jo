import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

const _defaultBridgeUrl = 'http://localhost:8765';
const _bridgeUrlKey = 'wine_cellr_bridge_url';

class CellarStatus {
  final String name;
  final bool zoneHighOn;
  final int zoneHighTemp;
  final bool zoneLowOn;
  final int zoneLowTemp;
  final double? zoneHighCurrent;
  final double? zoneLowCurrent;
  final String ledColor;
  final String alarm;
  final String tempUnit;
  final bool childLock;
  final bool light;
  final int doorFault;

  CellarStatus({
    required this.name,
    required this.zoneHighOn,
    required this.zoneHighTemp,
    required this.zoneLowOn,
    required this.zoneLowTemp,
    this.zoneHighCurrent,
    this.zoneLowCurrent,
    this.ledColor = '',
    this.alarm = 'OFF',
    this.tempUnit = 'c',
    this.childLock = false,
    this.light = false,
    this.doorFault = 0,
  });

  factory CellarStatus.fromJson(Map<String, dynamic> json) {
    return CellarStatus(
      name: json['cellar']?.toString() ?? '',
      zoneHighOn: json['zoneHighOn'] == true,
      zoneHighTemp: (json['zoneHighTemp'] as num?)?.toInt() ?? 0,
      zoneLowOn: json['zoneLowOn'] == true,
      zoneLowTemp: (json['zoneLowTemp'] as num?)?.toInt() ?? 0,
      zoneHighCurrent: (json['zoneHighCurrent'] as num?)?.toDouble(),
      zoneLowCurrent: (json['zoneLowCurrent'] as num?)?.toDouble(),
      ledColor: json['ledColor']?.toString() ?? '',
      alarm: json['alarm']?.toString() ?? 'OFF',
      tempUnit: json['tempUnit']?.toString() ?? 'c',
      childLock: json['dps101'] == true,
      light: json['dps107'] == true,
      doorFault: (json['dps10'] as num?)?.toInt() ?? 0,
    );
  }
}

class WineCellarScreen extends StatefulWidget {
  const WineCellarScreen({super.key});

  @override
  State<WineCellarScreen> createState() => _WineCellarScreenState();
}

class _WineCellarScreenState extends State<WineCellarScreen> {
  List<CellarStatus>? _cellars;
  String? _error;
  bool _loading = true;
  Timer? _timer;
  String _bridgeUrl = _defaultBridgeUrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadBridgeUrl();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBridgeUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_bridgeUrlKey);
    if (saved != null && saved.isNotEmpty) _bridgeUrl = saved;
    _fetch();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetch());
  }

  Future<void> _saveBridgeUrl(String url) async {
    _bridgeUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bridgeUrlKey, url);
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await http.get(Uri.parse('$_bridgeUrl/status-all')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => CellarStatus.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() { _cellars = list; _error = null; _loading = false; });
      } else {
        if (mounted) setState(() { _error = 'Erreur ${res.statusCode}'; _loading = false; });
      }
    } on http.ClientException {
      if (mounted) setState(() { _error = 'Pont non connecté'; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erreur: ${e.runtimeType}'; _loading = false; });
    }
  }

  Future<void> _send(int cellarIndex, String dps, dynamic value) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await http.post(
        Uri.parse('$_bridgeUrl/set/$cellarIndex'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'dps': dps, 'value': value}),
      ).timeout(const Duration(seconds: 12));
      await _fetch();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  void _showBridgeUrlDialog() {
    final controller = TextEditingController(text: _bridgeUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('URL du pont', style: AppText.serif(color: AppColors.gold2, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Adresse du serveur tuya_bridge.\nExemple : http://10.0.0.50:8765',
              style: AppText.sans(color: AppColors.text3, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: AppText.sans(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
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
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: AppText.sans(color: AppColors.text3, fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () {
              _saveBridgeUrl(controller.text.trim());
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF1A1408),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Sauvegarder', style: AppText.sans(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wine CellR',
                    style: AppText.serif(color: AppColors.gold2, fontSize: 28, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Contrôle des celliers connectés',
                    style: AppText.sans(color: AppColors.text3, fontSize: 13),
                  ),
                ],
              ),
            ),
            _iconBtn(Icons.settings_outlined, 'Configurer le pont', _showBridgeUrlDialog),
            const SizedBox(width: 8),
            _iconBtn(Icons.refresh, 'Actualiser', () { setState(() => _loading = true); _fetch(); }),
          ],
        ),
        const SizedBox(height: 24),
        if (_loading)
          const Center(child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: CircularProgressIndicator(color: AppColors.gold),
          )),
        if (_error != null)
          _ErrorCard(
            message: _error!,
            bridgeUrl: _bridgeUrl,
            onRetry: () { setState(() { _loading = true; _error = null; }); _fetch(); },
            onConfigure: _showBridgeUrlDialog,
          ),
        if (_cellars != null)
          for (var i = 0; i < _cellars!.length; i++) ...[
            _CellarCard(
              status: _cellars![i],
              index: i,
              sending: _sending,
              onSend: _send,
            ),
            if (i < _cellars!.length - 1) const SizedBox(height: 20),
          ],
      ],
    );
  }

  Widget _iconBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.bg3,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border2),
          ),
          child: Icon(icon, size: 16, color: AppColors.text2),
        ),
      ),
    );
  }
}

// ---------- Error card ----------

class _ErrorCard extends StatelessWidget {
  final String message;
  final String bridgeUrl;
  final VoidCallback onRetry;
  final VoidCallback onConfigure;
  const _ErrorCard({required this.message, required this.bridgeUrl, required this.onRetry, required this.onConfigure});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x40C62828)),
      ),
      child: Column(
        children: [
          const Icon(Icons.power_off_outlined, color: Color(0xFFE8667A), size: 44),
          const SizedBox(height: 14),
          Text(message, style: AppText.sans(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Lancer "node server.js" dans tuya_bridge/\npuis vérifier l\'URL : $bridgeUrl',
            style: AppText.sans(color: AppColors.text3, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF1A1408),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Réessayer', style: AppText.sans(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onConfigure,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text2,
                  side: const BorderSide(color: AppColors.border2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Configurer URL', style: AppText.sans(fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------- Cellar card ----------

class _CellarCard extends StatelessWidget {
  final CellarStatus status;
  final int index;
  final bool sending;
  final Future<void> Function(int, String, dynamic) onSend;

  const _CellarCard({
    required this.status,
    required this.index,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          // Zones
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ZoneWidget(
                    label: 'Zone haute',
                    isOn: status.zoneHighOn,
                    targetTemp: status.zoneHighTemp,
                    currentTemp: status.zoneHighCurrent,
                    unit: status.tempUnit,
                    dpsOn: '1',
                    dpsTemp: '2',
                    index: index,
                    sending: sending,
                    onSend: onSend,
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 180, color: AppColors.border),
                const SizedBox(width: 16),
                Expanded(
                  child: _ZoneWidget(
                    label: 'Zone basse',
                    isOn: status.zoneLowOn,
                    targetTemp: status.zoneLowTemp,
                    currentTemp: status.zoneLowCurrent,
                    unit: status.tempUnit,
                    dpsOn: '5',
                    dpsTemp: '6',
                    index: index,
                    sending: sending,
                    onSend: onSend,
                  ),
                ),
              ],
            ),
          ),
          // Bottom controls
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: _buildControls(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final online = status.zoneHighOn || status.zoneLowOn;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF7CD492) : const Color(0xFFE8667A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (online ? const Color(0xFF7CD492) : const Color(0xFFE8667A)).withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            status.name,
            style: AppText.serif(color: AppColors.gold2, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (status.alarm != 'OFF')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8A04C).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE8A04C).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.door_front_door_outlined, size: 14, color: Color(0xFFE8A04C)),
                  const SizedBox(width: 4),
                  Text('PORTE OUVERTE', style: AppText.sans(color: const Color(0xFFE8A04C), fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          if (sending)
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // LED color
        _ControlChip(
          icon: Icons.lightbulb_outline,
          label: 'LED',
          value: _ledLabel(status.ledColor),
          color: _ledColor(status.ledColor),
          onTap: () => _showLedPicker(context),
        ),
        // Child lock
        _ControlChip(
          icon: status.childLock ? Icons.lock_outline : Icons.lock_open_outlined,
          label: 'Verrou',
          value: status.childLock ? 'ON' : 'OFF',
          color: status.childLock ? const Color(0xFFE8667A) : const Color(0xFF7CD492),
          onTap: () => onSend(index, '101', !status.childLock),
        ),
        // Temp unit
        _ControlChip(
          icon: Icons.thermostat_outlined,
          label: 'Unité',
          value: status.tempUnit == 'c' ? '°C' : '°F',
          color: AppColors.gold2,
          onTap: () => onSend(index, '4', status.tempUnit == 'c' ? 'f' : 'c'),
        ),
        // Interior light
        _ControlChip(
          icon: status.light ? Icons.wb_incandescent : Icons.wb_incandescent_outlined,
          label: 'Lumière',
          value: status.light ? 'ON' : 'OFF',
          color: status.light ? const Color(0xFFE8C97A) : AppColors.text3,
          onTap: () => onSend(index, '107', !status.light),
        ),
      ],
    );
  }

  void _showLedPicker(BuildContext context) {
    final colors = [
      ('red', 'Rouge', const Color(0xFFE8667A)),
      ('blue', 'Bleu', const Color(0xFF70B8E8)),
      ('OFF', 'Éteinte', AppColors.text3),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text('Couleur LED', style: AppText.serif(color: AppColors.gold2, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in colors)
              _ledOption(ctx, c.$1, c.$2, c.$3),
          ],
        ),
      ),
    );
  }

  Widget _ledOption(BuildContext ctx, String value, String label, Color color) {
    final selected = status.ledColor == value;
    return GestureDetector(
      onTap: () {
        onSend(index, '102', value);
        Navigator.pop(ctx);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.bg3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 14, height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 12),
            Text(label, style: AppText.sans(color: selected ? color : AppColors.text2, fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            const Spacer(),
            if (selected) Icon(Icons.check, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  String _ledLabel(String color) => switch (color) {
    'red' => 'Rouge',
    'green' => 'Vert',
    'blue' => 'Bleu',
    'white' => 'Blanc',
    _ => color,
  };

  Color _ledColor(String color) => switch (color) {
    'red' => const Color(0xFFE8667A),
    'green' => const Color(0xFF7CD492),
    'blue' => const Color(0xFF70B8E8),
    'white' => const Color(0xFFE8E0D0),
    _ => AppColors.text3,
  };
}

// ---------- Control chip ----------

class _ControlChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _ControlChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ControlChip> createState() => _ControlChipState();
}

class _ControlChipState extends State<_ControlChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hover ? widget.color.withValues(alpha: 0.1) : AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hover ? widget.color.withValues(alpha: 0.3) : AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 15, color: widget.color),
              const SizedBox(width: 8),
              Text(widget.label, style: AppText.sans(color: AppColors.text3, fontSize: 11)),
              const SizedBox(width: 6),
              Text(widget.value, style: AppText.sans(color: widget.color, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Zone widget ----------

class _ZoneWidget extends StatelessWidget {
  final String label;
  final bool isOn;
  final int targetTemp;
  final double? currentTemp;
  final String unit;
  final String dpsOn;
  final String dpsTemp;
  final int index;
  final bool sending;
  final Future<void> Function(int, String, dynamic) onSend;

  const _ZoneWidget({
    required this.label,
    required this.isOn,
    required this.targetTemp,
    required this.currentTemp,
    required this.unit,
    required this.dpsOn,
    required this.dpsTemp,
    required this.index,
    required this.sending,
    required this.onSend,
  });

  String get _unitSymbol => unit == 'f' ? '°F' : '°C';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Zone header + power toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: AppText.sans(color: AppColors.text3, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w700),
            ),
            _PowerToggle(isOn: isOn, onTap: sending ? null : () => onSend(index, dpsOn, !isOn)),
          ],
        ),
        const SizedBox(height: 16),
        // Current temp
        Text(
          currentTemp != null ? '${currentTemp!.toStringAsFixed(1)}$_unitSymbol' : '--',
          style: AppText.serif(color: AppColors.text, fontSize: 36, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text('actuelle', style: AppText.sans(color: AppColors.text3, fontSize: 11)),
        // Delta indicator
        if (currentTemp != null) _buildDelta(),
        const SizedBox(height: 16),
        // Target temp controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _tempButton(Icons.remove, sending ? null : () => onSend(index, dpsTemp, targetTemp - 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Text(
                      '$targetTemp$_unitSymbol',
                      style: AppText.sans(color: AppColors.gold2, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    Text('consigne', style: AppText.sans(color: AppColors.text3, fontSize: 9)),
                  ],
                ),
              ),
              _tempButton(Icons.add, sending ? null : () => onSend(index, dpsTemp, targetTemp + 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDelta() {
    final delta = currentTemp! - targetTemp;
    if (delta.abs() < 0.5) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF7CD492).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('Stable', style: AppText.sans(color: const Color(0xFF7CD492), fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      );
    }
    final warming = delta > 0;
    final c = warming ? const Color(0xFFE8A04C) : const Color(0xFF70B8E8);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(warming ? Icons.arrow_upward : Icons.arrow_downward, size: 10, color: c),
            const SizedBox(width: 3),
            Text(
              '${delta.abs().toStringAsFixed(1)}°',
              style: AppText.sans(color: c, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tempButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.gold.withValues(alpha: 0.15) : AppColors.bg2,
          shape: BoxShape.circle,
          border: Border.all(color: onTap != null ? AppColors.gold.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Icon(icon, size: 18, color: onTap != null ? AppColors.gold2 : AppColors.text3),
      ),
    );
  }
}

// ---------- Power toggle ----------

class _PowerToggle extends StatefulWidget {
  final bool isOn;
  final VoidCallback? onTap;
  const _PowerToggle({required this.isOn, this.onTap});

  @override
  State<_PowerToggle> createState() => _PowerToggleState();
}

class _PowerToggleState extends State<_PowerToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.isOn ? const Color(0xFF7CD492) : const Color(0xFFE8667A);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.withValues(alpha: _hover ? 0.25 : 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withValues(alpha: _hover ? 0.6 : 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.power_settings_new, size: 12, color: c),
              const SizedBox(width: 4),
              Text(
                widget.isOn ? 'ON' : 'OFF',
                style: AppText.sans(color: c, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
