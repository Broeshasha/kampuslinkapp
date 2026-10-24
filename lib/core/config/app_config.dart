import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/catalog/catalog.dart';
import '../../data/sync/sync_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/states.dart';
import '../l10n/locale_controller.dart';
import '../logging/logger.dart';
import '../supabase/supabase_bootstrap.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

const _cacheKey = 'app_version_config';

/// true when this build is older than [minSupported] (unknown build: never).
bool needsUpdate(int? build, int minSupported) =>
    build != null && build > 0 && build < minSupported;

int _toInt(Object? v) =>
    v is num ? v.toInt() : int.tryParse('${v ?? ''}'.replaceAll('"', '')) ?? 0;

String _toStr(Object? v) => v == null ? '' : '$v'.replaceAll('"', '').trim();

/// The update settings (lead WP17/18-4): min_supported_build (blocking
/// screen), latest_build (small banner) and update_url.
class VersionConfig {
  const VersionConfig({this.min = 0, this.latest = 0, this.updateUrl = ''});

  factory VersionConfig.fromMap(Map<String, dynamic> m) => VersionConfig(
    min: _toInt(m['min_supported_build']),
    latest: _toInt(m['latest_build']),
    updateUrl: _toStr(m['update_url']),
  );

  final int min;
  final int latest;
  final String updateUrl;

  Map<String, Object> toMap() => {
    'min_supported_build': min,
    'latest_build': latest,
    'update_url': updateUrl,
  };
}

final packageInfoProvider = FutureProvider<PackageInfo?>((ref) async {
  try {
    return await PackageInfo.fromPlatform();
  } catch (error) {
    appLog.info('package info unavailable: $error');
    return null;
  }
});

/// catalog.config when known; otherwise the app_config rows (read at start
/// and after each sync); cached so an offline start still knows it.
final versionConfigProvider = FutureProvider<VersionConfig>((ref) async {
  final prefs = ref.read(sharedPrefsProvider);
  VersionConfig cached() {
    try {
      final v = jsonDecode(prefs.getString(_cacheKey) ?? '');
      return v is Map
          ? VersionConfig.fromMap(v.cast<String, dynamic>())
          : const VersionConfig();
    } on FormatException {
      return const VersionConfig();
    }
  }

  Future<VersionConfig> keep(VersionConfig c) async {
    await prefs.setString(_cacheKey, jsonEncode(c.toMap()));
    return c;
  }

  final config = ref.watch(catalogValueProvider)?.config;
  if (config != null && config.containsKey('min_supported_build')) {
    return keep(VersionConfig.fromMap(config));
  }
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return cached();
  ref.watch(syncControllerProvider.select((s) => s.lastSyncedAt));
  try {
    final rows = await client
        .from('app_config')
        .select('key, value')
        .inFilter('key', const [
          'min_supported_build',
          'latest_build',
          'update_url',
        ])
        .timeout(const Duration(seconds: 10));
    return await keep(
      VersionConfig.fromMap({for (final r in rows) '${r['key']}': r['value']}),
    );
  } catch (error) {
    appLog.info('app_config offline: $error');
    return cached();
  }
});

int? _build(WidgetRef ref) =>
    int.tryParse(ref.watch(packageInfoProvider).value?.buildNumber ?? '');

final mustUpdateProvider = Provider<bool>((ref) {
  final build = int.tryParse(
    ref.watch(packageInfoProvider).value?.buildNumber ?? '',
  );
  final min = ref.watch(versionConfigProvider).value?.min ?? 0;
  return needsUpdate(build, min);
});

String _storeUrl(VersionConfig? c, PackageInfo? info) {
  final url = c?.updateUrl ?? '';
  if (url.isNotEmpty) return url;
  final id = info?.packageName ?? '';
  return id.isEmpty ? '' : 'https://play.google.com/store/apps/details?id=$id';
}

Future<void> openUpdate(WidgetRef ref) async {
  final url = _storeUrl(
    ref.read(versionConfigProvider).value,
    ref.read(packageInfoProvider).value,
  );
  if (url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// "New version available": build < latest_build (not blocking), hidden
/// with "x" until the next start.
class UpdateAvailableBanner extends ConsumerStatefulWidget {
  const UpdateAvailableBanner({super.key, this.margin = EdgeInsets.zero});

  final EdgeInsetsGeometry margin;

  @override
  ConsumerState<UpdateAvailableBanner> createState() =>
      _UpdateAvailableBannerState();
}

class _UpdateAvailableBannerState extends ConsumerState<UpdateAvailableBanner> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final latest = ref.watch(versionConfigProvider).value?.latest ?? 0;
    if (_hidden || kIsWeb || !needsUpdate(_build(ref), latest)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return Container(
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
        border: Border.all(color: kc.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.system_update_rounded, size: 18, color: kc.accentText),
          const SizedBox(width: KSpace.sm),
          Expanded(
            child: Text(
              l10n.updateAvailable,
              style: TextStyle(color: kc.textPrimary, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => openUpdate(ref),
            child: Text(l10n.updateAction),
          ),
          IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _hidden = true),
            icon: Icon(Icons.close_rounded, color: kc.textSecondary),
          ),
        ],
      ),
    );
  }
}

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
    final url = _storeUrl(ref.watch(versionConfigProvider).value, info);
    return Scaffold(
      body: SafeArea(
        child: EmptyView(
          icon: Icons.system_update_rounded,
          title: l10n.updateTitle,
          message: l10n.updateBody,
          actionLabel: url.isEmpty ? null : l10n.updateAction,
          onAction: url.isEmpty ? null : () => openUpdate(ref),
        ),
      ),
    );
  }
}
