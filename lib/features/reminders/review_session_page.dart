import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics.dart';
import '../../core/errors/result.dart';
import '../../core/theme/tokens.dart';
import '../../data/learning/feed_repository.dart';
import '../../data/learning/learning_providers.dart';
import '../../data/profile/study_level.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/max_width.dart';
import '../../ui/states.dart';
import '../home/flash_card.dart';
import '../home/study_activity.dart';

/// Where "Start" on a study reminder lands: 10 minutes of due cards (then
/// new ones) from the current semester, all from the phone.
class ReviewSessionPage extends ConsumerStatefulWidget {
  const ReviewSessionPage({super.key});

  static const length = Duration(minutes: 10);

  @override
  ConsumerState<ReviewSessionPage> createState() => _ReviewSessionPageState();
}

class _ReviewSessionPageState extends ConsumerState<ReviewSessionPage> {
  List<FeedCard>? _cards;
  int _index = 0;
  int _reviewed = 0;
  int _left = ReviewSessionPage.length.inSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _left > 0) {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    if (_reviewed > 0) {
      Analytics.log('cards_session', {'cards': _reviewed > 20 ? 20 : _reviewed});
    }
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final semester = ref.read(currentSemesterProvider);
    final all = await ref.read(feedRepositoryProvider).feed(limit: 60);
    if (!mounted) {
      return;
    }
    setState(
      () => _cards = [
        for (final c in all)
          if (inSemester(c.module, semester)) c,
      ],
    );
  }

  Future<void> _answer(FeedCard card, bool knewIt) async {
    await guard(
      () => ref
          .read(progressRepositoryProvider)
          .reviewCard(card.card.id, correct: knewIt),
    );
    if (mounted) {
      setState(() {
        _index++;
        _reviewed++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final cards = _cards;
    final Widget body;
    if (cards == null) {
      body = const LoadingView();
    } else if (cards.isEmpty) {
      body = EmptyView(
        icon: Icons.check_circle_outline_rounded,
        title: l10n.reviewEmpty,
        actionLabel: l10n.reviewBackHome,
        onAction: () => context.go('/home'),
      );
    } else if (_left == 0 || _index >= cards.length) {
      body = EmptyView(
        icon: Icons.celebration_rounded,
        title: l10n.reviewDoneTitle,
        message: l10n.reviewDoneBody(_reviewed),
        actionLabel: l10n.reviewBackHome,
        onAction: () => context.go('/home'),
      );
    } else {
      final card = cards[_index];
      final text = card.text(lang);
      body = Padding(
        padding: const EdgeInsets.all(KSpace.md),
        child: MaxWidth(
          child: FlashCardView(
            key: ValueKey<int>(card.card.id),
            front: text.front,
            back: text.back,
            language: text.language,
            moduleName: card.module.name,
            accent: moduleAccent(card.module.id),
            liked: card.liked,
            saved: card.saved,
            onAnswer: (knewIt) => _answer(card, knewIt),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reviewTitle),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: KSpace.lg),
              child: Text(l10n.reviewTimeLeft((_left / 60).ceil())),
            ),
          ),
        ],
      ),
      body: StudyActivity(child: SafeArea(child: body)),
    );
  }
}
