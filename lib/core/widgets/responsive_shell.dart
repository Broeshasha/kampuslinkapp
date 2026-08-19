import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ResponsiveShell extends StatefulWidget {
  final List<Widget> screens;
  const ResponsiveShell({super.key, required this.screens});

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  int _selectedIndex = 0;

  static const _destinations = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.groups_rounded, label: 'Community'),
    _NavItem(icon: Icons.chat_bubble_rounded, label: 'Messages'),
    _NavItem(icon: Icons.storefront_rounded, label: 'Marketplace'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 600) {
          return _mobileLayout();
        } else if (width < 1024) {
          return _tabletLayout();
        } else {
          return _desktopLayout();
        }
      },
    );
  }

  // Mobile: bottom nav + floating center action button
  Widget _mobileLayout() {
    return Scaffold(
      body: SafeArea(child: widget.screens[_selectedIndex]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () {},
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.surface,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_destinations.length, (i) => _navIcon(i)),
        ),
      ),
    );
  }

  Widget _navIcon(int index) {
    final selected = _selectedIndex == index;
    return IconButton(
      onPressed: () => setState(() => _selectedIndex = index),
      icon: Icon(
        _destinations[index].icon,
        color: selected ? AppColors.accent : AppColors.textSecondary,
      ),
    );
  }

  // Tablet: same bottom nav for now, wider content area
  Widget _tabletLayout() => _mobileLayout();

  // Desktop/Web: side NavigationRail instead of bottom nav
  Widget _desktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppColors.surface,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.link_rounded, color: AppColors.accent, size: 28),
            ),
            selectedIconTheme: const IconThemeData(color: AppColors.accent),
            unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
            selectedLabelTextStyle: const TextStyle(color: AppColors.accent),
            unselectedLabelTextStyle: const TextStyle(color: AppColors.textSecondary),
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: widget.screens[_selectedIndex],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () {},
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}