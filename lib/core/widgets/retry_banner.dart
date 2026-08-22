import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Reusable "this failed, tap to retry" banner — used anywhere a write
/// action (post, comment, like, upload) fails, instead of failing silently.
class RetryBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const RetryBanner({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry', style: TextStyle(color: AppColors.danger, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}