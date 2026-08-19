import 'package:flutter/material.dart';

import '../models/wine.dart';
import '../services/pending_ai_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Bandeau « X bouteilles à identifier — Lancer l'analyse IA ».
///
/// Affiché en haut de Ma Cave dès qu'il reste des bouteilles entrées en
/// vitesse. C'est le seul endroit d'où part l'analyse différée.
class PendingAiBanner extends StatelessWidget {
  final List<Wine> wines;

  const PendingAiBanner({super.key, required this.wines});

  @override
  Widget build(BuildContext context) {
    final pending = wines.where((w) => w.aiPending).toList();

    return ValueListenableBuilder<PendingAiProgress>(
      valueListenable: PendingAiService.progress,
      builder: (context, p, _) {
        if (pending.isEmpty && !p.running) return const SizedBox.shrink();

        final failed = pending.where((w) => w.aiError != null).length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.10),
            border: const Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            children: [
              Icon(
                p.running ? Icons.auto_awesome : Icons.hourglass_empty,
                size: 17,
                color: AppColors.gold2,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.running
                          ? 'Analyse IA en cours — ${p.done + 1}/${p.total}'
                          : '${pending.length} bouteille'
                              '${pending.length > 1 ? 's' : ''} à identifier',
                      style: AppText.sans(
                        color: AppColors.gold2,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.running
                          ? (p.currentLabel ?? 'Lecture de l\'étiquette…')
                          : failed > 0
                              ? 'Dont $failed en échec — réessaie quand tu veux.'
                              : 'Photos enregistrées, fiches à remplir.',
                      style: AppText.sans(
                        color: AppColors.text2,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (p.running)
                TextButton(
                  onPressed: PendingAiService.cancel,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.text2,
                  ),
                  child: const Text('Arrêter'),
                )
              else
                FilledButton.icon(
                  onPressed: () => PendingAiService.runAll(wines),
                  icon: const Icon(Icons.auto_awesome, size: 15),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF1A1408),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                  label: Text(
                    'Lancer l\'analyse IA',
                    style: AppText.sans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
