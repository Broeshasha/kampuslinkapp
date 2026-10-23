import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../data/db/app_database.dart';
import '../l10n/app_localizations.dart';

/// Web only (WP16 E): when this browser cannot keep the database (drift
/// fell back to unsafe IndexedDB or memory), say so plainly. "x" hides it
/// until the next start.
class StorageWarningBanner extends StatefulWidget {
  const StorageWarningBanner({
    super.key,
    this.margin = EdgeInsets.zero,
    this.status,
  });

  final EdgeInsetsGeometry margin;

  /// Tests pass their own notifier; the app uses [webStorageStatus].
  final ValueNotifier<String?>? status;

  @override
  State<StorageWarningBanner> createState() => _StorageWarningBannerState();
}

class _StorageWarningBannerState extends State<StorageWarningBanner> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.status ?? webStorageStatus,
      builder: (context, value, _) {
        if (_hidden || !webStorageUnsafe(value)) {
          return const SizedBox.shrink();
        }
        final kc = context.kc;
        return Semantics(
          liveRegion: true,
          child: Container(
            width: double.infinity,
            margin: widget.margin,
            padding: const EdgeInsetsDirectional.fromSTEB(
              KSpace.lg,
              KSpace.xs,
              KSpace.xs,
              KSpace.xs,
            ),
            decoration: BoxDecoration(
              color: kc.surfaceRaised,
              borderRadius: BorderRadius.circular(KRadius.chip),
              border: Border.all(color: kc.warning.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(Icons.sd_card_alert_outlined, size: 18, color: kc.warning),
                const SizedBox(width: KSpace.sm),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).webStorageWarning,
                    style: TextStyle(color: kc.textPrimary, fontSize: 13),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => _hidden = true),
                  icon: Icon(Icons.close_rounded, color: kc.textSecondary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
