import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

import 'offline_banner_web.dart' if (dart.library.io) 'offline_banner_mobile.dart'
    as platform;

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final platform.ConnectivityChecker _checker;

  @override
  void initState() {
    super.initState();
    _checker = platform.ConnectivityChecker(
      onChanged: (offline) {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _checker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_checker.isOffline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: const Color(0xFF3D2E0A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 14, color: AppColors.gold2),
          const SizedBox(width: 8),
          Text(
            'Mode hors-ligne — données en cache',
            style: AppText.sans(color: AppColors.gold2, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
