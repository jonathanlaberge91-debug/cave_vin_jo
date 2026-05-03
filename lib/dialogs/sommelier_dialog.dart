import 'package:flutter/material.dart';
import '../models/wine.dart';
import '../services/gemini_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

Future<void> showSommelierDialog(BuildContext context, Wine wine) {
  return showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => _SommelierDialog(wine: wine),
  );
}

class _SommelierDialog extends StatefulWidget {
  final Wine wine;
  const _SommelierDialog({required this.wine});

  @override
  State<_SommelierDialog> createState() => _SommelierDialogState();
}

class _SommelierDialogState extends State<_SommelierDialog> {
  SommelierResult? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final r = await GeminiService.sommelierAdvice(widget.wine);
      if (mounted) setState(() { _result = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border2),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(),
              if (_loading) _loadingBody(),
              if (_error != null) _errorBody(),
              if (_result != null) _resultBody(),
            ],
          ),
        ),
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
          const Icon(Icons.local_bar_outlined, color: AppColors.gold2, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sommelier',
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.wine.name,
                  style: AppText.sans(color: AppColors.text3, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  Widget _loadingBody() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold),
          ),
          SizedBox(height: 16),
          Text('Consultation du sommelier…',
              style: TextStyle(color: AppColors.text3, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _errorBody() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        _error!,
        style: AppText.sans(color: const Color(0xFFC62828), fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _resultBody() {
    final r = _result!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _adviceRow(Icons.thermostat_outlined, 'Température', r.temperature),
          const SizedBox(height: 14),
          _adviceRow(Icons.hourglass_top_outlined, 'Décantage', r.decantage),
          const SizedBox(height: 14),
          _adviceRow(Icons.wine_bar_outlined, 'Verre', r.verre),
          const SizedBox(height: 14),
          _adviceRow(Icons.lock_open_outlined, 'Ouverture', r.ouverture),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSEIL DU SOMMELIER',
                  style: AppText.sans(
                    color: AppColors.gold,
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  r.conseil,
                  style: AppText.sans(
                    color: AppColors.text,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adviceRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Icon(icon, size: 16, color: AppColors.gold2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppText.sans(
                  color: AppColors.text3,
                  fontSize: 10,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppText.sans(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
