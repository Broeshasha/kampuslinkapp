import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure_mapper.dart';
import '../../core/errors/result.dart';
import '../../core/l10n/locale_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/learning/feed_repository.dart';
import '../../data/learning/learning_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../render/block_style.dart';
import '../../render/rich_block_text.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';

/// Saved flashcards: tap to see the answer, bookmark to remove.
class SavedCardsPage extends ConsumerWidget {
  const SavedCardsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.savedCards)),
      body: switch (ref.watch(savedCardsProvider)) {
        AsyncData(:final value) when value.isEmpty => EmptyView(
          icon: Icons.bookmark_border_rounded,
          title: l10n.savedCards,
          message: l10n.savedCardsEmpty,
        ),
        AsyncData(:final value) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            KSpace.lg,
            KSpace.md,
            KSpace.lg,
            KSpace.xxl * 3,
          ),
          itemCount: value.length,
          separatorBuilder: (_, _) => const SizedBox(height: KSpace.sm),
          itemBuilder: (context, i) => MaxWidth(
            child: _SavedCard(
              key: ValueKey<int>(value[i].card.id),
              card: value[i],
            ),
          ),
        ),
        AsyncError(:final error) => ErrorView(failure: mapError(error)),
        _ => const LoadingView(),
      },
    );
  }
}

class _SavedCard extends ConsumerStatefulWidget {
  const _SavedCard({super.key, required this.card});

  final FeedCard card;

  @override
  ConsumerState<_SavedCard> createState() => _SavedCardState();
}

class _SavedCardState extends ConsumerState<_SavedCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final l10n = AppLocalizations.of(context);
    final accent = moduleAccent(widget.card.module.id);
    final text = widget.card.text(Localizations.localeOf(context).languageCode);
    final lang = supportedLanguageCodes.contains(text.language)
        ? text.language
        : fallbackLanguageCode;
    final style = BlockStyle(
      language: lang,
      scale: 1,
      kc: kc,
      labels: lookupAppLocalizations(Locale(lang)),
      base: Theme.of(context).textTheme.bodyLarge ?? const TextStyle(),
    );
    return Material(
      color: kc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KRadius.chip),
        side: BorderSide(color: accent.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(KSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.card.module.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.saveLabel,
                    icon: Icon(Icons.bookmark_rounded, color: kc.xp),
                    onPressed: () => guard(
                      () => ref
                          .read(feedRepositoryProvider)
                          .setSaved(widget.card.card.id, on: false),
                    ),
                  ),
                ],
              ),
              Directionality(
                textDirection: style.direction,
                child: RichBlockText(text: text.front, style: style),
              ),
              AnimatedCrossFade(
                duration: KMotion.normal,
                crossFadeState: _open
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: KSpace.sm),
                  child: Text(
                    l10n.tapToFlip,
                    style: TextStyle(color: kc.textSecondary, fontSize: 12),
                  ),
                ),
                secondChild: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: KSpace.sm),
                  padding: const EdgeInsets.all(KSpace.sm),
                  decoration: BoxDecoration(
                    color: kc.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Directionality(
                    textDirection: style.direction,
                    child: RichBlockText(text: text.back, style: style),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
