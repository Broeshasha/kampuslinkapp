import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';
import '../ui/offline_banner.dart';
import '../ui/storage_banner.dart';

typedef _Tab = (IconData icon, IconData selectedIcon, String label);

/// The 3-tab frame. compact (<600): floating glass pill bar.
/// medium: rail with labels. expanded (>=840): extended rail.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int index) {
    if (index != navigationShell.currentIndex) {
      HapticFeedback.selectionClick();
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final List<_Tab> tabs = [
      (Icons.style_outlined, Icons.style, l10n.tabHome),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, l10n.tabModules),
      (Icons.person_outline, Icons.person, l10n.tabProfile),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < KBreakpoints.medium) {
          return Scaffold(
            body: navigationShell,
            bottomNavigationBar: _FloatingNavBar(
              tabs: tabs,
              selectedIndex: navigationShell.currentIndex,
              onSelected: _go,
            ),
          );
        }
        final extended = width >= KBreakpoints.expanded;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  extended: extended,
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _go,
                  labelType: extended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: [
                    for (final t in tabs)
                      NavigationRailDestination(
                        icon: Icon(t.$1),
                        selectedIcon: Icon(t.$2),
                        label: Text(t.$3),
                      ),
                  ],
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.kc.border,
                ),
                Expanded(
                  child: Column(
                    children: [
                      const OfflineBanner(margin: EdgeInsets.all(KSpace.sm)),
                      const StorageWarningBanner(
                        margin: EdgeInsets.all(KSpace.sm),
                      ),
                      Expanded(child: navigationShell),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Floating, frosted-glass pill with a soft brand glow.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Tab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final kc = context.kc;
    final radius = BorderRadius.circular(KRadius.sheet);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: KSpace.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: KSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OfflineBanner(margin: EdgeInsets.only(bottom: KSpace.sm)),
            const StorageWarningBanner(
              margin: EdgeInsets.only(bottom: KSpace.sm),
            ),
            MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: [
                    BoxShadow(
                      color: kc.accent.withValues(alpha: 0.18),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: kc.surface.withValues(alpha: 0.88),
                        borderRadius: radius,
                        border: Border.all(color: kc.border),
                      ),
                      child: NavigationBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        selectedIndex: selectedIndex,
                        onDestinationSelected: onSelected,
                        destinations: [
                          for (final t in tabs)
                            NavigationDestination(
                              icon: Icon(t.$1),
                              selectedIcon: Icon(t.$2),
                              label: t.$3,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
