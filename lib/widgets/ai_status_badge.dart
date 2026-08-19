import 'package:flutter/material.dart';

import '../models/wine.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Pastille d'état IA affichée à côté du nom du vin.
///
/// « À identifier » : bouteille entrée en vitesse, l'analyse n'a pas encore
/// été lancée. « À vérifier » : l'IA a rempli la fiche toute seule, personne
/// ne l'a encore relue (la pastille disparaît à l'ouverture de la fiche).
class AiStatusBadge extends StatelessWidget {
  final Wine wine;
  final bool compact;

  const AiStatusBadge({super.key, required this.wine, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final bool pending = wine.aiPending;
    if (!pending && !wine.aiNeedsReview) return const SizedBox.shrink();

    final Color color = pending
        ? (wine.aiError != null ? const Color(0xFFB23A48) : AppColors.gold)
        : const Color(0xFF6B8E5A);
    final String label = pending
        ? (wine.aiError != null ? 'Analyse échouée' : 'À identifier')
        : 'À vérifier';
    final IconData icon = pending
        ? (wine.aiError != null
            ? Icons.error_outline
            : Icons.hourglass_empty)
        : Icons.auto_awesome;

    return Tooltip(
      message: pending
          ? (wine.aiError ??
              'Photo enregistrée. Lance l\'analyse IA quand tout est rentré.')
          : 'Fiche remplie par l\'IA — ouvre-la pour la valider.',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 7,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 9 : 11, color: color),
            if (!compact) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: AppText.sans(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
