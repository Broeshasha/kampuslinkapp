import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../data/sync/sync_results.dart';
import '../../l10n/app_localizations.dart';
import '../profile/share_app.dart';

/// TikTok-style side rail of the Home feed. It stays still while the cards
/// move; its buttons always act on the card on screen. In Arabic it sits on
/// the left (it is placed with "end", which flips with the language).
class FeedRail extends StatelessWidget {
  const FeedRail({
    super.key,
    required this.moduleName,
    required this.accent,
    required this.onMore,
    this.onModule,
    this.liked,
    this.onLike,
    this.saved,
    this.onSave,
    this.onShare,
  });

  /// Room the cards keep free for the rail.
  static const double width = 64;

  final String moduleName;
  final Color accent;
  final VoidCallback onMore;
  final VoidCallback? onModule;

  /// null = no like / save button for this kind of post.
  final bool? liked;
  final VoidCallback? onLike;
  final bool? saved;
  final VoidCallback? onSave;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kc = context.kc;
    final like = liked;
    final save = saved;
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModuleDot(name: moduleName, accent: accent, onTap: onModule),
          const SizedBox(height: KSpace.md),
          if (like != null)
            _PopButton(
              active: like,
              icon: Icons.favorite_rounded,
              idleIcon: Icons.favorite_border_rounded,
              activeColor: kc.danger,
              tooltip: l10n.likeLabel,
              onTap: onLike,
            ),
          if (save != null)
            _PopButton(
              active: save,
              icon: Icons.bookmark_rounded,
              idleIcon: Icons.bookmark_border_rounded,
              activeColor: kc.xp,
              tooltip: l10n.saveLabel,
              onTap: onSave,
            ),
          if (onShare case final share?)
            _PopButton(
              active: false,
              icon: Icons.share_rounded,
              idleIcon: Icons.share_rounded,
              activeColor: kc.textPrimary,
              tooltip: l10n.feedShare,
              onTap: share,
            ),
          _PopButton(
            active: false,
            icon: Icons.more_horiz_rounded,
            idleIcon: Icons.more_horiz_rounded,
            activeColor: kc.textPrimary,
            tooltip: l10n.feedMore,
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

class _ModuleDot extends StatelessWidget {
  const _ModuleDot({required this.name, required this.accent, this.onTap});

  final String name;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty
        ? null
        : name.trim().characters.first.toUpperCase();
    return Tooltip(
      message: name,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: SizedBox(
          width: 56,
          height: 56,
          child: Center(
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: letter == null
                  ? const Icon(Icons.auto_awesome_rounded, color: Colors.white)
                  : Text(
                      letter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round rail button; turning [active] on makes it pop (unless reduce
/// motion is on).
class _PopButton extends StatefulWidget {
  const _PopButton({
    required this.active,
    required this.icon,
    required this.idleIcon,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final IconData idleIcon;
  final Color activeColor;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_PopButton> createState() => _PopButtonState();
}

class _PopButtonState extends State<_PopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.35), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.92), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.92, end: 1), weight: 30),
  ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut));

  @override
  void didUpdateWidget(_PopButton old) {
    super.didUpdateWidget(old);
    if (!old.active &&
        widget.active &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    return Padding(
      padding: const EdgeInsets.only(bottom: KSpace.xs),
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: widget.tooltip,
            iconSize: 28,
            constraints: const BoxConstraints.tightFor(width: 56, height: 56),
            onPressed: widget.onTap == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    widget.onTap!();
                  },
            icon: Icon(
              widget.active ? widget.icon : widget.idleIcon,
              color: widget.active ? widget.activeColor : kc.textPrimary,
              shadows: [
                Shadow(color: kc.surface.withValues(alpha: 0.9), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// WhatsApp / Telegram / Facebook / SMS / copy, like the Profile share.
Future<void> showShareSheet(BuildContext context, String text) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in shareTargets(text))
            ListTile(
              leading: Icon(t.icon),
              title: Text(t.label),
              onTap: () async {
                Navigator.of(sheet).pop();
                await launchUrl(t.uri, mode: LaunchMode.externalApplication);
              },
            ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: Text(l10n.shareCopy),
            onTap: () async {
              Navigator.of(sheet).pop();
              await Clipboard.setData(ClipboardData(text: text));
              messenger.showSnackBar(SnackBar(content: Text(l10n.shareCopied)));
            },
          ),
        ],
      ),
    ),
  );
}

/// The big heart of a double-tap like.
class BigHeart extends StatefulWidget {
  const BigHeart({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<BigHeart> createState() => _BigHeartState();
}

class _BigHeartState extends State<BigHeart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    final color = context.kc.danger;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final scale = reduce
            ? 1.0
            : (v < 0.35
                  ? Curves.easeOutBack.transform(v / 0.35) * 1.15
                  : 1.15 - 0.15 * ((v - 0.35) / 0.65));
        final opacity = v < 0.7 ? 1.0 : (1 - (v - 0.7) / 0.3).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Icon(Icons.favorite_rounded, size: 120, color: color),
          ),
        );
      },
    );
  }
}

/// "+N" coins near the coin chip when a sync pays coins (the server decides;
/// several payments close together add up into one bubble).
class CoinBurstLayer extends ConsumerStatefulWidget {
  const CoinBurstLayer({super.key});

  @override
  ConsumerState<CoinBurstLayer> createState() => _CoinBurstLayerState();
}

class _CoinBurstLayerState extends ConsumerState<CoinBurstLayer> {
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _hide;
  int _amount = 0;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(syncResultsProvider).results.listen((r) {
      final coins = r['coins'];
      if (coins is! num || coins <= 0 || !mounted) return;
      setState(() {
        _amount = (_show ? _amount : 0) + coins.toInt();
        _show = true;
      });
      _hide?.cancel();
      _hide = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _show = false);
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: Align(
        alignment: AlignmentDirectional.topEnd,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            top: KSpace.sm,
            end: KSpace.lg,
          ),
          child: AnimatedSlide(
            offset: _show ? Offset.zero : const Offset(0, 0.8),
            duration: reduce ? Duration.zero : KMotion.slow,
            curve: KMotion.curve,
            child: AnimatedOpacity(
              opacity: _show ? 1 : 0,
              duration: reduce ? Duration.zero : KMotion.normal,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KSpace.md,
                  vertical: KSpace.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: kc.xp,
                  borderRadius: BorderRadius.circular(KRadius.chip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.monetization_on_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: KSpace.xs),
                    Text(
                      '+$_amount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
