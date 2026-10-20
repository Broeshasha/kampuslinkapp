import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/connectivity/connectivity.dart';
import '../../core/errors/failure_mapper.dart';
import '../../core/logging/logger.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/db/app_database.dart';
import '../../data/lessons/lesson_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';

IconData _formatIcon(String? format) => switch (format) {
  'pdf' => Icons.picture_as_pdf_outlined,
  'image' || 'image_set' => Icons.image_outlined,
  'doc' => Icons.description_outlined,
  'ppt' => Icons.slideshow_outlined,
  'sheet' => Icons.table_chart_outlined,
  _ => Icons.insert_drive_file_outlined,
};

String _size(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  final mb = bytes / (1024 * 1024);
  return mb >= 1
      ? '${mb.toStringAsFixed(1)} MB'
      : '${(bytes / 1024).ceil()} KB';
}

List<String> _urls(String json) {
  try {
    final v = jsonDecode(json);
    return v is List ? [for (final u in v) '$u'] : const <String>[];
  } on FormatException {
    return const <String>[];
  }
}

/// Module LIBRARY: files grouped by type, trust label, tap to open.
/// For now files open online (in the browser / phone viewer).
class LibraryTab extends ConsumerWidget {
  const LibraryTab({super.key, required this.moduleId});

  final int moduleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return switch (ref.watch(resourcesProvider(moduleId))) {
      AsyncData(:final value) =>
        value.isEmpty
            ? EmptyView(
                icon: Icons.folder_open_outlined,
                title: l10n.libraryEmpty,
              )
            : _FileList(files: value),
      AsyncError(:final error) => ErrorView(failure: mapError(error)),
      _ => const LoadingView(),
    };
  }
}

class _FileList extends ConsumerWidget {
  const _FileList({required this.files});

  final List<ResourceRow> files;

  Future<void> _open(BuildContext context, WidgetRef ref, ResourceRow f) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!ref.read(isOnlineProvider)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.needInternetForFile)));
      return;
    }
    final urls = _urls(f.fileUrlsJson);
    var opened = false;
    if (urls.isNotEmpty) {
      try {
        opened = await launchUrl(
          Uri.parse(urls.first),
          mode: LaunchMode.externalApplication,
        );
      } catch (error, stack) {
        appLog.error(error, stack, reason: 'open file ${f.id}');
      }
    }
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.fileOpenFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final children = <Widget>[];
    String? currentType;
    for (final f in files) {
      if (f.type != currentType) {
        currentType = f.type;
        children.add(
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: KSpace.lg,
              bottom: KSpace.sm,
              start: KSpace.xs,
            ),
            child: Text(
              l10n.resourceType(f.type),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: kc.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: KSpace.sm),
          child: _FileTile(file: f, onTap: () => _open(context, ref, f)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KSpace.lg,
        0,
        KSpace.lg,
        KSpace.xxl * 3,
      ),
      children: [for (final c in children) MaxWidth(child: c)],
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onTap});

  final ResourceRow file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final trust = file.trustLabel;
    final trustColor = switch (trust) {
      'official' => kc.official,
      'verified' => kc.accentText,
      _ => kc.community,
    };
    final details = [
      if (file.format != null) file.format!.toUpperCase(),
      _size(file.sizeBytes),
    ].where((s) => s.isNotEmpty).join(' \u00b7 ');
    return Material(
      color: kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.chip),
        side: BorderSide(color: kc.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpace.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kc.surfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_formatIcon(file.format), color: kc.accentText),
              ),
              const SizedBox(width: KSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details,
                        style: TextStyle(color: kc.textSecondary, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (trust != null) ...[
                const SizedBox(width: KSpace.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KSpace.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: trustColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l10n.trustLabel(trust),
                    style: TextStyle(
                      color: trustColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
