import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

/// One shared report flow — used from Community posts/comments,
/// Marketplace listings, and user profiles/messages.
class ReportDialog {
  static const _reasons = [
    'Spam or scam',
    'Harassment or hate speech',
    'False information',
    'Inappropriate content',
    'Other',
  ];

  static Future<void> show({
    required BuildContext context,
    required String targetType,
    required String targetId,
  }) async {
    String? selectedReason;
    final detailsController = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Report', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 12),
              ..._reasons.map((r) => RadioListTile<String>(
                    value: r,
                    groupValue: selectedReason,
                    onChanged: (v) => setModalState(() => selectedReason = v),
                    title: Text(r, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    activeColor: AppColors.accent,
                    contentPadding: EdgeInsets.zero,
                  )),
              const SizedBox(height: 8),
              TextField(
                controller: detailsController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: selectedReason == null
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Submit report', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (submitted == true && selectedReason != null) {
      try {
        final userId = Supabase.instance.client.auth.currentUser!.id;
        await Supabase.instance.client.from('reports').insert({
          'reporter_id': userId,
          'target_type': targetType,
          'target_id': targetId,
          'reason': selectedReason,
          'details': detailsController.text.trim(),
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted. Thank you.')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not submit report. Try again.')),
          );
        }
      }
    }
  }
}