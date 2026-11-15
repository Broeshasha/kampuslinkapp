import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/motivation/motivation_providers.dart';
import '../../data/motivation/motivation_store.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/step_layout.dart';
import 'mission_strip.dart' show whyLabel;

/// Onboarding (MOT-1): "my why" (1-2 values + optional sentence, phone only)
/// then 3 short "how to study" cards. Skip always works.
class MotivationStep extends ConsumerStatefulWidget {
  const MotivationStep({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<MotivationStep> createState() => _MotivationStepState();
}

class _MotivationStepState extends ConsumerState<MotivationStep> {
  final _picked = <String>[];
  final _text = TextEditingController();
  int _page = 0; // 0 = why, 1..3 = how-to cards

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _saveWhy() async {
    final why = MyWhy(values: List.of(_picked), text: _text.text);
    if (!why.isEmpty) {
      await ref.read(motivationStoreProvider).setWhy(why);
      ref.invalidate(myWhyProvider);
    }
    if (mounted) setState(() => _page = 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final title = Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800);
    if (_page == 0) {
      return OnboardingStepLayout(
        items: [
          const SizedBox(height: KSpace.lg),
          Icon(Icons.favorite_rounded, size: 56, color: kc.accentText),
          const SizedBox(height: KSpace.lg),
          Text(l10n.whyTitle, textAlign: TextAlign.center, style: title),
          const SizedBox(height: KSpace.sm),
          Text(l10n.whyBody, textAlign: TextAlign.center, style: TextStyle(color: kc.textSecondary)),
          const SizedBox(height: KSpace.lg),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: KSpace.xs,
            runSpacing: KSpace.xs,
            children: [
              for (final v in whyValues)
                FilterChip(
                  label: Text(whyLabel(l10n, v)),
                  selected: _picked.contains(v),
                  onSelected: (on) => setState(() {
                    if (on) {
                      if (_picked.length == 2) _picked.removeAt(0);
                      _picked.add(v);
                    } else {
                      _picked.remove(v);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: KSpace.md),
          TextField(
            controller: _text,
            maxLength: 200,
            maxLines: 2,
            minLines: 1,
            decoration: InputDecoration(hintText: l10n.whyTextHint),
          ),
        ],
        action: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(onPressed: _saveWhy, child: Text(l10n.motNext)),
            TextButton(
              onPressed: () => setState(() => _page = 1),
              child: Text(l10n.motSkip),
            ),
          ],
        ),
      );
    }
    final cards = [
      (Icons.timer_outlined, l10n.how1),
      (Icons.replay_rounded, l10n.how2),
      (Icons.psychology_alt_rounded, l10n.how3),
    ];
    final (icon, text) = cards[_page - 1];
    final last = _page == cards.length;
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.lg),
        Text(l10n.howTitle, textAlign: TextAlign.center, style: TextStyle(color: kc.textSecondary)),
        const SizedBox(height: KSpace.xl),
        Icon(icon, size: 72, color: kc.accentText),
        const SizedBox(height: KSpace.lg),
        Text(text, textAlign: TextAlign.center, style: title),
        const SizedBox(height: KSpace.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= cards.length; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page ? kc.accent : kc.border,
                ),
              ),
          ],
        ),
      ],
      action: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: last ? widget.onDone : () => setState(() => _page++),
            child: Text(last ? l10n.motStart : l10n.motNext),
          ),
          if (!last)
            TextButton(onPressed: widget.onDone, child: Text(l10n.motSkip)),
        ],
      ),
    );
  }
}
