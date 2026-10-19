import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import '../l10n/app_localizations.dart';

/// The 3-tab frame. compact (<600): bottom bar. medium: rail with labels.
/// expanded (>=840): extended rail. Each tab keeps its own stack.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _go(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tabs = [
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
            bottomNavigationBar: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _go,
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: Icon(t.$1),
                    selectedIcon: Icon(t.$2),
                    label: t.$3,
                  ),
              ],
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
                Expanded(child: navigationShell),
              ],
            ),
          ),
        );
      },
    );
  }
}
