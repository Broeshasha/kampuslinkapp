import 'package:flutter/material.dart';

import '../config/connectivity_service.dart';
import '../theme/app_theme.dart';

/// Thin banner that appears the moment the device goes offline and
/// disappears the moment connectivity returns. Self-contained -- no
/// state to wire up, just drop it at the top of a screen's widget tree.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.isOnline,
      builder: (context, online, _) {
        if (online) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: AppColors.accent.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 14, color: AppColors.accent),
              SizedBox(width: 8),
              Text(
                "You're offline -- showing saved content",
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
