import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../services/search_history.dart';
import '../screens/gallery_screen.dart';
import '../screens/search_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../main.dart' show themeProvider;

class MaterialShell extends StatefulWidget {
  final FAClient client;
  final UserSession session;
  final VoidCallback onLogout;

  const MaterialShell({
    super.key,
    required this.client,
    required this.session,
    required this.onLogout,
  });

  @override
  State<MaterialShell> createState() => _MaterialShellState();
}

class _MaterialShellState extends State<MaterialShell> {
  int _currentIndex = 0;
  bool _sfwMode = false;

  /// Nav items use M3 color roles when in M3 mode, fall back to AppColors
  /// in Original mode.
  List<_NavItemData> get _navItems {
    final cs = Theme.of(context).colorScheme;
    final isM3 = themeProvider.mode != AppThemeMode.original;
    return [
      _NavItemData(
        icon: Icons.photo_library_outlined,
        selectedIcon: Icons.photo_library,
        label: 'Gallery',
        accent: isM3 ? cs.primary : AppColors.fluentCyan,
      ),
      _NavItemData(
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
        label: 'Search',
        accent: isM3 ? cs.tertiary : AppColors.materialGreen,
      ),
      _NavItemData(
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: 'Notifications',
        accent: isM3 ? cs.secondary : AppColors.cupertinoPurple,
      ),
      _NavItemData(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile',
        accent: isM3 ? cs.tertiary : AppColors.materialLavender,
      ),
      _NavItemData(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
        accent: isM3 ? cs.outline : AppColors.textMuted,
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadSfwMode();
    SearchHistory.externalQuery.addListener(_onExternalSearch);
  }

  void _onExternalSearch() {
    if (SearchHistory.externalQuery.value != null && mounted) {
      setState(() => _currentIndex = 1);
    }
  }

  @override
  void dispose() {
    SearchHistory.externalQuery.removeListener(_onExternalSearch);
    super.dispose();
  }

  Future<void> _loadSfwMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('sfw_mode') ?? false;
    if (mounted && saved != _sfwMode) {
      setState(() => _sfwMode = saved);
    }
  }

  void _onSfwModeChanged(bool value) {
    setState(() => _sfwMode = value);
  }

  List<Widget> _buildScreens() {
    return [
      GalleryScreen(client: widget.client, sfwMode: _sfwMode, onLogout: widget.onLogout),
      SearchScreen(client: widget.client, sfwMode: _sfwMode, onLogout: widget.onLogout),
      NotificationsScreen(client: widget.client, onLogout: widget.onLogout),
      ProfileScreen(client: widget.client, session: widget.session, onLogout: widget.onLogout),
      SettingsScreen(
        sfwMode: _sfwMode,
        onSfwModeChanged: _onSfwModeChanged,
        onLogout: widget.onLogout,
        client: widget.client,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

    final screens = _buildScreens();

    if (isDesktop) {
      return _buildDesktopLayout(screens);
    }
    return _buildMobileLayout(screens);
  }

  Widget _buildDesktopLayout(List<Widget> screens) {
    final isExtended = MediaQuery.of(context).size.width >= 1000;
    final items = _navItems;
    final currentAccent = items[_currentIndex].accent;

    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) =>
                  setState(() => _currentIndex = index),
              extended: isExtended,
              backgroundColor: Colors.transparent, // M3: inherit from theme
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: isExtended
                    ? Row(
                        children: [
                          Icon(Icons.pets, color: currentAccent, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            'FurClient',
                            style: TextStyle(
                              color: currentAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Icon(Icons.pets, color: currentAccent, size: 28),
              ),
              destinations: items.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon, color: currentAccent),
                  label: Text(item.label),
                );
              }).toList(),
            ),
          ),
          Expanded(child: screens[_currentIndex]),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(List<Widget> screens) {
    final items = _navItems;
    final currentAccent = items[_currentIndex].accent;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        // Let M3 theme handle background/indicator colors automatically
        backgroundColor: cs.surfaceContainer,
        indicatorColor: currentAccent.withValues(alpha: 0.15),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: items.map((item) {
          return NavigationDestination(
            icon: Icon(item.icon, size: 22),
            selectedIcon: Icon(item.selectedIcon, size: 24),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color accent;

  const _NavItemData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.accent,
  });
}
