import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../theme/theme_provider.dart';
import '../screens/gallery_screen.dart';
import '../screens/search_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';

class AppNavigator extends StatefulWidget {
  final FAClient client;
  final UserSession session;
  final VoidCallback onLogout;
  final ThemeProvider themeProvider;

  const AppNavigator({
    super.key,
    required this.client,
    required this.session,
    required this.onLogout,
    required this.themeProvider,
  });

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  int _currentIndex = 0;
  // Default to SFW on (NSFW off) until the site cookie is checked.
  bool _sfwMode = true;

  static const _navItems = [
    _NavItem(
        icon: Icons.photo_library_outlined,
        selectedIcon: Icons.photo_library,
        label: 'Gallery',
        accent: AppColors.fluentCyan),
    _NavItem(
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
        label: 'Search',
        accent: AppColors.materialGreen),
    _NavItem(
        icon: Icons.notifications_outlined,
        selectedIcon: Icons.notifications,
        label: 'Notifications',
        accent: AppColors.cupertinoPurple),
    _NavItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile',
        accent: AppColors.materialLavender),
    _NavItem(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: 'Settings',
        accent: AppColors.textMuted),
  ];

  @override
  void initState() {
    super.initState();
    _loadSfwMode();
  }

  Future<void> _loadSfwMode() async {
    // Always check the site's sfw_toggle cookie first
    final siteSfw = widget.client.checkSiteSfwMode();
    debugPrint('=== AppNavigator: site SFW mode = $siteSfw');

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('sfw_mode') ?? false;
    // Site cookie is authoritative — overwrite local setting
    final value = siteSfw;
    if (value != saved) {
      await prefs.setBool('sfw_mode', value);
    }
    if (mounted && value != _sfwMode) {
      setState(() => _sfwMode = value);
    }
  }

  void _onSfwModeChanged(bool value) {
    setState(() => _sfwMode = value);
  }

  List<Widget> _buildScreens() {
    return [
      GalleryScreen(
          client: widget.client, sfwMode: _sfwMode, onLogout: widget.onLogout),
      SearchScreen(
          client: widget.client, sfwMode: _sfwMode, onLogout: widget.onLogout),
      NotificationsScreen(client: widget.client, onLogout: widget.onLogout),
      ProfileScreen(
          client: widget.client,
          session: widget.session,
          onLogout: widget.onLogout),
      SettingsScreen(
        sfwMode: _sfwMode,
        onSfwModeChanged: _onSfwModeChanged,
        onLogout: widget.onLogout,
        client: widget.client,
        themeProvider: widget.themeProvider,
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
    final currentAccent = _navItems[_currentIndex].accent;

    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              border: Border(
                right: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) =>
                  setState(() => _currentIndex = index),
              extended: isExtended,
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
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      )
                    : Icon(Icons.pets, color: currentAccent, size: 28),
              ),
              indicatorColor: currentAccent.withValues(alpha: 0.15),
              destinations: _navItems.map((item) {
                return NavigationRailDestination(
                  icon: Icon(item.icon, color: AppColors.textMuted),
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) =>
              setState(() => _currentIndex = index),
          backgroundColor: AppColors.bgCard,
          indicatorColor:
              _navItems[_currentIndex].accent.withValues(alpha: 0.15),
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: _navItems.map((item) {
            return NavigationDestination(
              icon: Icon(item.icon, size: 22),
              selectedIcon: Icon(item.selectedIcon, size: 24),
              label: item.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color accent;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.accent,
  });
}
