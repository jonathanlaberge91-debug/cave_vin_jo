import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class CarteScreen extends StatelessWidget {
  const CarteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 64, color: AppColors.gold.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Carte des domaines',
            style: AppText.serif(color: AppColors.gold2, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Bientôt disponible sur mobile',
            style: AppText.sans(color: AppColors.text3, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
