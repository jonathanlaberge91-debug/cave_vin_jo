import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

const _defaultBridgeUrl = 'http://localhost:8765';
const _cloudUrl = 'https://us-east1-cave-vin-jo.cloudfunctions.net/tuyaProxy';
const _bridgeUrlKey = 'wine_cellr_bridge_url';

class CellarStatus {
  final String name;
  final bool power;         // DPS 1: cellier ON/OFF
  final int targetTemp;     // DPS 2: température consigne
  final String tempUnit;    // DPS 4: 'c' ou 'f'
  final bool keyLock;       // DPS 5: verrouillage clavier
  final int currentTemp;    // DPS 6: température actuelle
  final int dps10;          // DPS 10: inconnu
  final bool door;          // DPS 101: porte (true=ouverte)
  final String topLed;      // DPS 102: LEDs haut (red/blue/OFF)
  final int currentTempF;   // DPS 103: temp actuelle °F
  final int targetTempF;    // DPS 104: temp consigne °F
  final int sideLight;      // DPS 106: éclairage latéral (0/25/50/75/100)
  final bool sideLightColor;// DPS 107: couleur éclairage (false=blanc, true=bleu)
  final Map<String, dynamic> raw;

  CellarStatus({
    required this.name,
    this.power = false,
    this.targetTemp = 0,
    this.tempUnit = 'c',
    this.keyLock = false,
    this.currentTemp = 0,
    this.dps10 = 0,
    this.door = false,
    this.topLed = 'OFF',
    this.currentTempF = 0,
    this.targetTempF = 0,
    this.sideLight = 0,
    this.sideLightColor = false,
    this.raw = const {},
  });

  static int _toInt(dynamic v) => v is num ? v.toInt() : (int.tryParse('$v') ?? 0);

  factory CellarStatus.fromJson(Map<String, dynamic> json) {
    final rawDps = <String, dynamic>{};
    if (json['raw'] is Map) {
      (json['raw'] as Map).forEach((k, v) => rawDps['$k'] = v);
    }
    return CellarStatus(
      name: json['cellar']?.toString() ?? '',
      power: json['power'] == true,
      targetTemp: _toInt(json['targetTemp']),
      tempUnit: json['tempUnit']?.toString() ?? 'c',
      keyLock: json['keyLock'] == true,
      currentTemp: _toInt(json['currentTemp']),
      dps10: _toInt(json['dps10']),
      door: json['door'] == true,
      topLed: json['topLed']?.toString() ?? 'OFF',
      currentTempF: _toInt(json['currentTempF']),
      targetTempF: _toInt(json['targetTempF']),
      sideLight: _toInt(json['sideLight']),
      sideLightColor: json['sideLightColor'] == true,
      raw: rawDps,
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
  bool _useCloud = false;
  Timer? _timer;
  String _bridgeUrl = _defaultBridgeUrl;
  final Set<int> _sendingFor = {};

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

  String get _activeUrl => _useCloud ? _cloudUrl : _bridgeUrl;

  Future<void> _fetch() async {
    // Try local bridge first, then cloud fallback
    if (!_useCloud) {
      try {
        final res = await http.get(Uri.parse('$_bridgeUrl/status-all')).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final list = (jsonDecode(res.body) as List)
              .map((e) => CellarStatus.fromJson(e as Map<String, dynamic>))
              .toList();
          if (mounted) setState(() { _cellars = list; _error = null; _loading = false; _useCloud = false; });
          return;
        }
      } catch (_) {}
    }
    // Cloud fallback
    try {
      final res = await http.get(Uri.parse('$_cloudUrl/status-all')).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => CellarStatus.fromJson(e as Map<String, dynamic>))
            .toList();
        if (mounted) setState(() { _cellars = list; _error = null; _loading = false; _useCloud = true; });
      } else {
        if (mounted) setState(() { _error = 'Erreur ${res.statusCode}'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Impossible de joindre les celliers'; _loading = false; });
    }
  }

  Future<String?> _rawSend(int cellarIndex, String dps, dynamic value) async {
    final res = await http.post(
      Uri.parse('$_activeUrl/set/$cellarIndex'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'dps': dps, 'value': value}),
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        return body['error']?.toString() ?? 'Erreur ${res.statusCode}';
      } catch (_) {
        return 'Erreur ${res.statusCode}';
      }
    }
    return null;
  }

  Future<void> _send(int cellarIndex, String dps, dynamic value) async {
    if (_sendingFor.contains(cellarIndex)) return;
    setState(() => _sendingFor.add(cellarIndex));
    String? error;
    try {
      final needsUnlock = dps == '106' || dps == '107' || dps == '102';
      final wasLocked = _cellars != null && cellarIndex < _cellars!.length && _cellars![cellarIndex].keyLock;
      if (needsUnlock && wasLocked) {
        error = await _rawSend(cellarIndex, '5', false);
        if (error != null) throw Exception(error);
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      error = await _rawSend(cellarIndex, dps, value);
      if (error != null) throw Exception(error);
      if (needsUnlock && wasLocked) {
        await Future.delayed(const Duration(milliseconds: 1500));
        await _rawSend(cellarIndex, '5', true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: const Color(0xFFB23A48)),
        );
      }
    }
    if (mounted) setState(() => _sendingFor.remove(cellarIndex));
    _fetch();
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
                filled: true, fillColor: AppColors.bg3,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.gold)),
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
                  Text('Wine CellR', style: AppText.serif(color: AppColors.gold2, fontSize: 28, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Contrôle des celliers connectés', style: AppText.sans(color: AppColors.text3, fontSize: 13)),
                ],
              ),
            ),
            _iconBtn(Icons.settings_outlined, 'Configurer le pont', _showBridgeUrlDialog),
            const SizedBox(width: 8),
            _iconBtn(Icons.refresh, 'Actualiser', () { setState(() => _loading = true); _fetch(); }),
          ],
        ),
        const SizedBox(height: 24),
        if (_loading && _cellars == null)
          const Center(child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: CircularProgressIndicator(color: AppColors.gold),
          )),
        if (_error != null && _cellars == null)
          _OfflineBanner(
            bridgeUrl: _bridgeUrl,
            onRetry: () { setState(() { _loading = true; _error = null; }); _fetch(); },
            onConfigure: _showBridgeUrlDialog,
          ),
        if (_cellars != null)
          for (var i = 0; i < _cellars!.length; i++) ...[
            _CellarCard(status: _cellars![i], index: i, sending: _sendingFor.contains(i), onSend: _send),
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
          width: 36, height: 36,
          decoration: BoxDecoration(color: AppColors.bg3, shape: BoxShape.circle, border: Border.all(color: AppColors.border2)),
          child: Icon(icon, size: 16, color: AppColors.text2),
        ),
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  final String bridgeUrl;
  final VoidCallback onRetry;
  final VoidCallback onConfigure;
  const _OfflineBanner({required this.bridgeUrl, required this.onRetry, required this.onConfigure});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.text3, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Celliers hors ligne', style: AppText.sans(color: AppColors.text2, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Connexion au pont impossible. Vérifiez que vous êtes sur le même réseau Wi-Fi que vos celliers.',
                  style: AppText.sans(color: AppColors.text3, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border2),
              ),
              child: const Icon(Icons.refresh, size: 16, color: AppColors.text2),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onConfigure,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bg3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border2),
              ),
              child: const Icon(Icons.settings_outlined, size: 16, color: AppColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}

class _CellarCard extends StatelessWidget {
  final CellarStatus status;
  final int index;
  final bool sending;
  final Future<void> Function(int, String, dynamic) onSend;

  const _CellarCard({required this.status, required this.index, required this.sending, required this.onSend});

  String get _unit => '°C';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg2, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildTempSection(),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: _buildControls(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: status.power ? const Color(0xFF7CD492) : const Color(0xFFE8667A),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: (status.power ? const Color(0xFF7CD492) : const Color(0xFFE8667A)).withValues(alpha: 0.5), blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 12),
          Text(status.name, style: AppText.serif(color: AppColors.gold2, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          _PowerToggle(isOn: status.power, onTap: sending ? null : () => onSend(index, '1', !status.power)),
          const Spacer(),
          if (status.door)
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
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)),
        ],
      ),
    );
  }

  Widget _buildTempSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('${status.currentTemp}$_unit', style: AppText.serif(color: AppColors.text, fontSize: 42, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('actuelle', style: AppText.sans(color: AppColors.text3, fontSize: 11)),
              ],
            ),
          ),
          Container(width: 1, height: 80, color: AppColors.border),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.bg3, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tempButton(Icons.remove, sending ? null : () => onSend(index, '2', status.targetTemp - 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text('${status.targetTemp}$_unit', style: AppText.sans(color: AppColors.gold2, fontSize: 22, fontWeight: FontWeight.w700)),
                      ),
                      _tempButton(Icons.add, sending ? null : () => onSend(index, '2', status.targetTemp + 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('consigne', style: AppText.sans(color: AppColors.text3, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tempButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.gold.withValues(alpha: 0.15) : AppColors.bg2,
          shape: BoxShape.circle,
          border: Border.all(color: onTap != null ? AppColors.gold.withValues(alpha: 0.4) : AppColors.border),
        ),
        child: Icon(icon, size: 18, color: onTap != null ? AppColors.gold2 : AppColors.text3),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ControlChip(
          icon: Icons.brightness_6, label: 'Éclairage',
          value: _sideLightLabel(status.sideLight),
          color: status.sideLight > 0 ? const Color(0xFFE8C97A) : AppColors.text3,
          onTap: () => _showSideLightPicker(context),
        ),
        _ControlChip(
          icon: Icons.color_lens_outlined, label: 'Couleur écl.',
          value: status.sideLightColor ? 'Bleu' : 'Blanc',
          color: status.sideLightColor ? const Color(0xFF70B8E8) : const Color(0xFFE8E0D0),
          onTap: () => onSend(index, '107', !status.sideLightColor),
        ),
        _ControlChip(
          icon: Icons.lightbulb_outline, label: 'LEDs haut',
          value: _topLedLabel(status.topLed),
          color: _topLedColor(status.topLed),
          onTap: () => _showTopLedPicker(context),
        ),
        _ControlChip(
          icon: status.keyLock ? Icons.lock_outline : Icons.lock_open_outlined,
          label: 'Clavier',
          value: status.keyLock ? 'Verrouillé' : 'Libre',
          color: status.keyLock ? const Color(0xFFE8667A) : const Color(0xFF7CD492),
          onTap: () => onSend(index, '5', !status.keyLock),
        ),
        _ControlChip(
          icon: Icons.thermostat_outlined, label: 'Unité',
          value: status.tempUnit == 'c' ? '°C' : '°F',
          color: AppColors.gold2,
          onTap: () => onSend(index, '4', status.tempUnit == 'c' ? 'f' : 'c'),
        ),
      ],
    );
  }

  String _sideLightLabel(int v) => switch (v) {
    0 => 'OFF', 25 => '25%', 50 => '50%', 75 => '75%', 100 => '100%', _ => '$v',
  };

  void _showSideLightPicker(BuildContext context) {
    final options = [
      (0, 'OFF', AppColors.text3),
      (25, '25%', const Color(0xFFE8C97A).withValues(alpha: 0.4)),
      (50, '50%', const Color(0xFFE8C97A).withValues(alpha: 0.6)),
      (75, '75%', const Color(0xFFE8C97A).withValues(alpha: 0.8)),
      (100, '100%', const Color(0xFFE8C97A)),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
        title: Text('Éclairage latéral', style: AppText.serif(color: AppColors.gold2, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              _pickerOption(ctx, '106', o.$1, o.$2, o.$3, status.sideLight == o.$1),
          ],
        ),
      ),
    );
  }

  String _topLedLabel(String v) => switch (v) { 'red' => 'Rouge', 'blue' => 'Bleu', _ => 'OFF' };

  Color _topLedColor(String v) => switch (v) { 'red' => const Color(0xFFE8667A), 'blue' => const Color(0xFF70B8E8), _ => AppColors.text3 };

  void _showTopLedPicker(BuildContext context) {
    final options = [
      ('red', 'Rouge', const Color(0xFFE8667A)),
      ('blue', 'Bleu', const Color(0xFF70B8E8)),
      ('OFF', 'Éteinte', AppColors.text3),
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
        title: Text('LEDs du haut', style: AppText.serif(color: AppColors.gold2, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options)
              _pickerOption(ctx, '102', o.$1, o.$2, o.$3, status.topLed == o.$1),
          ],
        ),
      ),
    );
  }

  Widget _pickerOption(BuildContext ctx, String dps, dynamic value, String label, Color color, bool selected) {
    return GestureDetector(
      onTap: () { onSend(index, dps, value); Navigator.pop(ctx); },
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
            Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text(label, style: AppText.sans(color: selected ? color : AppColors.text2, fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
            const Spacer(),
            if (selected) Icon(Icons.check, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _ControlChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _ControlChip({required this.icon, required this.label, required this.value, required this.color, required this.onTap});

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
              Text(widget.isOn ? 'ON' : 'OFF', style: AppText.sans(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
