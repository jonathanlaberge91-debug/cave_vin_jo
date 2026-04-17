import 'package:flutter/material.dart';
import '../theme/app_text.dart';
import '../services/gemini_service.dart';
import 'home_screen.dart' show AppColors;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _geminiKey = TextEditingController(text: GeminiService.apiKey ?? '');
  bool _obscure = true;
  bool _saved = false;

  @override
  void dispose() {
    _geminiKey.dispose();
    super.dispose();
  }

  void _save() {
    final key = _geminiKey.text.trim();
    GeminiService.apiKey = key.isEmpty ? null : key;
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLÉS API',
                  style: AppText.sans(
                    color: AppColors.text3,
                    fontSize: 11,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Google Gemini',
                  style: AppText.serif(
                    color: AppColors.gold2,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Utilisé pour remplir automatiquement les fiches de vin (identification, fenêtre de dégustation, descriptions).',
                  style: AppText.sans(
                    color: AppColors.text3,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _geminiKey,
                        obscureText: _obscure,
                        style: AppText.sans(color: AppColors.text, fontSize: 13),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.bg3,
                          hintText: 'Coller votre clé API Gemini ici…',
                          hintStyle: AppText.sans(color: AppColors.text3, fontSize: 12),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.gold),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.text3,
                              size: 18,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF1A1408),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _saved ? '✓ Sauvegardé' : 'Sauvegarder',
                        style: AppText.sans(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      GeminiService.isConfigured
                          ? Icons.check_circle
                          : Icons.warning_amber_rounded,
                      size: 14,
                      color: GeminiService.isConfigured
                          ? const Color(0xFF4A7C59)
                          : const Color(0xFFE07060),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      GeminiService.isConfigured
                          ? 'Clé configurée'
                          : 'Aucune clé configurée',
                      style: AppText.sans(
                        color: GeminiService.isConfigured
                            ? const Color(0xFF6AAA7A)
                            : const Color(0xFFE07060),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
