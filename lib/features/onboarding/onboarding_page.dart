import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/brand_logo.dart';
import '../auth/google_sign_in_button.dart';
import '../profile/language_picker.dart';
import 'download_step.dart';
import 'onboarding_status.dart';
import 'step_layout.dart';
import 'studies_step.dart';

/// 4 steps: welcome (+ language) -> Google -> studies -> download.
/// Already signed in (old accounts) -> starts at studies. Back always works.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late int _step;

  @override
  void initState() {
    super.initState();
    _step = ref.read(isSignedInProvider) ? 2 : 0;
  }

  void _go(int step) => setState(() => _step = step);

  void _back() => _go(_step == 2 ? 0 : _step - 1);

  Future<void> _finish() async {
    final uid = ref.read(authRepositoryProvider).session?.user.id;
    await markOnboardingDone(ref, uid);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isSignedInProvider, (previous, next) {
      if (next && _step < 2) _go(2);
    });
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Widget body = switch (_step) {
      0 => _WelcomeStep(
        onNext: () => _go(ref.read(isSignedInProvider) ? 2 : 1),
      ),
      1 => const _SignInStep(),
      2 => StudiesStep(onDone: () => _go(3)),
      _ => DownloadStep(onFinish: _finish),
    };
    final canGoBack = _step == 1 || _step == 2;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && canGoBack) _back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  KSpace.sm,
                  KSpace.sm,
                  KSpace.sm,
                  0,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: canGoBack
                          ? IconButton(
                              onPressed: _back,
                              tooltip: MaterialLocalizations.of(context)
                                  .backButtonTooltip,
                              icon: const BackButtonIcon(),
                            )
                          : null,
                    ),
                    Expanded(
                      child: Center(child: _StepDots(current: _step)),
                    ),
                    const SizedBox(width: 48, height: 48),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduceMotion ? Duration.zero : KMotion.normal,
                  child: KeyedSubtree(key: ValueKey(_step), child: body),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++)
          AnimatedContainer(
            duration: KMotion.normal,
            curve: KMotion.curve,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= current ? kc.accent : kc.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final theme = Theme.of(context).textTheme;
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.xxl),
        const BrandLogo(),
        const SizedBox(height: KSpace.xl),
        Text(
          l10n.appTitle,
          style: theme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: KSpace.sm),
        Text(
          l10n.splashTagline,
          textAlign: TextAlign.center,
          style: theme.titleMedium?.copyWith(color: kc.textSecondary),
        ),
        const SizedBox(height: KSpace.xxl),
        Text(l10n.languageLabel, style: TextStyle(color: kc.textSecondary)),
        const SizedBox(height: KSpace.sm),
        const LanguagePicker(),
      ],
      action: FilledButton(onPressed: onNext, child: Text(l10n.onboardingNext)),
    );
  }
}

class _SignInStep extends StatelessWidget {
  const _SignInStep();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    return OnboardingStepLayout(
      items: [
        const SizedBox(height: KSpace.xxl),
        Icon(Icons.cloud_sync_rounded, size: 72, color: kc.accentText),
        const SizedBox(height: KSpace.xl),
        Text(
          l10n.onboardingSignInTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: KSpace.md),
        Text(
          l10n.onboardingSignInBody,
          textAlign: TextAlign.center,
          style: TextStyle(color: kc.textSecondary),
        ),
      ],
      action: const GoogleSignInButton(),
    );
  }
}
