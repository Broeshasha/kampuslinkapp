import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'kampus_mark.dart';

class ResponsiveShell extends StatefulWidget {
  final List<Widget> screens;
  final VoidCallback? onAvatarTap;
  const ResponsiveShell({super.key, required this.screens, this.onAvatarTap});

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

  Widget _avatarButton() {
    return IconButton(
      onPressed: widget.onAvatarTap,
      icon: const CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.surface,
        child: Icon(Icons.person, size: 18, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _mobileLayout() {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KampusMark(size: 22, color: AppColors.accent),
            const SizedBox(width: 8),
            const Text('KampusLink',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [_avatarButton(), const SizedBox(width: 8)],
      ),
      body: SafeArea(top: false, child: widget.screens[_selectedIndex]),
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

  Widget _tabletLayout() => _mobileLayout();

  Widget _desktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppColors.surface,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const KampusMark(size: 28, color: AppColors.accent),
                  const SizedBox(height: 16),
                  _avatarButton(),
                ],
              ),
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
