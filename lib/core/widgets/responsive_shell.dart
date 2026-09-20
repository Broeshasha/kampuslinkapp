import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../config/cached_fetch.dart';
import 'kampus_mark.dart';
import 'blurhash_image.dart';
import '../../features/library/library_screen.dart';
import '../../features/marketplace/marketplace_screen.dart';
import '../../features/notifications/notifications_screen.dart';

class ResponsiveShell extends StatefulWidget {
  final List<Widget> screens;
  final Future<void> Function()? onAvatarTap;
  final GlobalKey<LibraryScreenState> libraryKey;
  final GlobalKey<MarketplaceScreenState> marketplaceKey;
  const ResponsiveShell({
    super.key,
    required this.screens,
    required this.libraryKey,
    required this.marketplaceKey,
    this.onAvatarTap,
  });

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  int _selectedIndex = 0;
  String? _avatarUrl;
  String? _avatarBlurhash;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadUnreadCount();
  }

  Future<void> _loadAvatar() async {
    final cached = await CachedFetch.readCacheMap('my_profile');
    if (cached != null && mounted) {
      setState(() {
        _avatarUrl = cached['avatar_url'] as String?;
        _avatarBlurhash = cached['avatar_blurhash'] as String?;
      });
    }
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('avatar_url, avatar_blurhash')
          .eq('id', userId)
          .single()
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() {
        _avatarUrl = data['avatar_url'] as String?;
        _avatarBlurhash = data['avatar_blurhash'] as String?;
      });
    } catch (_) {
      // Keep whatever the cache gave us -- not worth surfacing an error for a nav icon.
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false)
          .timeout(const Duration(seconds: 6));
      if (!mounted) return;
      setState(() => _unreadCount = (data as List).length);
    } catch (_) {
      // Keep whatever count we already had -- not worth surfacing an error for a nav badge.
    }
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Share something',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_rounded, color: AppColors.accent),
              title: const Text('Library resource', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _selectedIndex = 1);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.libraryKey.currentState?.openUpload();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_rounded, color: AppColors.accent),
              title: const Text('Marketplace listing', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _selectedIndex = 3);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  widget.marketplaceKey.currentState?.openCreate();
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static const _destinations = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.menu_book_rounded, label: 'Library'),
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
      onPressed: () async {
        await widget.onAvatarTap?.call();
        _loadAvatar();
      },
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.surface,
        child: _avatarUrl != null
            ? ClipOval(
                child: BlurHashImage(
                  imageUrl: _avatarUrl!,
                  blurhash: _avatarBlurhash,
                  width: 32,
                  height: 32,
                ),
              )
            : const Icon(Icons.person, size: 18, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _notificationsButton() {
    return IconButton(
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        );
        _loadUnreadCount();
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none, color: AppColors.textSecondary),
          if (_unreadCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
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
        actions: [_notificationsButton(), _avatarButton(), const SizedBox(width: 8)],
      ),
      body: SafeArea(top: false, child: widget.screens[_selectedIndex]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: _openCreateSheet,
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
                  _notificationsButton(),
                  const SizedBox(height: 8),
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
        onPressed: _openCreateSheet,
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

