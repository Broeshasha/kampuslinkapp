import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/states.dart';
import '../l10n/locale_controller.dart';
import '../logging/logger.dart';
import '../supabase/supabase_bootstrap.dart';

const _minBuildKey = 'min_supported_build';

/// true when this build is older than app_config.min_supported_build.
bool needsUpdate(int? build, int minSupported) =>
    build != null && build > 0 && build < minSupported;

int _toInt(Object? v) =>
    v is num ? v.toInt() : int.tryParse('${v ?? ''}'.replaceAll('"', '')) ?? 0;

final packageInfoProvider = FutureProvider<PackageInfo?>((ref) async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (error) {
    appLog.info('package info unavailable: $error');
    return null;
  }
});

/// BACKEND_CONTRACT E: read at start and after each sync; cached so an
/// offline start still knows it.
final minSupportedBuildProvider = FutureProvider<int>((ref) async {
  final prefs = ref.read(sharedPrefsProvider);
  final cached = prefs.getInt(_minBuildKey) ?? 0;
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return cached;
  ref.watch(syncControllerProvider.select((s) => s.lastSyncedAt));
  try {
    final row = await client
        .from('app_config')
        .select('value')
        .eq('key', 'min_supported_build')
        .maybeSingle()
        .timeout(const Duration(seconds: 10));
    final value = _toInt(row?['value']);
    await prefs.setInt(_minBuildKey, value);
    return value;
  } catch (error) {
    appLog.info('app_config offline: $error');
    return cached;
  }
});

final mustUpdateProvider = Provider<bool>((ref) {
  final info = switch (ref.watch(packageInfoProvider)) {
    AsyncData(:final value) => value,
    _ => null,
  };
  final min = switch (ref.watch(minSupportedBuildProvider)) {
    AsyncData(:final value) => value,
    _ => 0,
  };
  return needsUpdate(int.tryParse(info?.buildNumber ?? ''), min);
});

/// Shows "please update" over the whole app when the build is too old.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(mustUpdateProvider)) return child;
    final l10n = AppLocalizations.of(context);
    final info = switch (ref.watch(packageInfoProvider)) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final id = info?.packageName ?? '';
    return Scaffold(
      body: SafeArea(
        child: EmptyView(
          icon: Icons.system_update_rounded,
          title: l10n.updateTitle,
          message: l10n.updateBody,
          actionLabel: kIsWeb || id.isEmpty ? null : l10n.updateAction,
          onAction: kIsWeb || id.isEmpty
              ? null
              : () => launchUrl(
                  Uri.parse(
                    'https://play.google.com/store/apps/details?id=$id',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
        ),
      ),
    );
  }
}
