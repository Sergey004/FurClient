import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../screens/gallery_screen.dart';
import '../screens/search_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';

class AppNavigator extends StatefulWidget {
  final FAClient client;
  final UserSession session;
  final VoidCallback onLogout;

  const AppNavigator({
    super.key,
    required this.client,
    required this.session,
    required this.onLogout,
  });

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator> {
  int _currentIndex = 0;
  bool _sfwMode = false;

  void _onSfwModeChanged(bool value) {
    setState(() {
      _sfwMode = value;
    });
  }

  static const _tabs = [
    _NavTab(icon: Icons.photo_library, label: 'Gallery'),
    _NavTab(icon: Icons.search, label: 'Search'),
    _NavTab(icon: Icons.notifications, label: 'Notifications'),
    _NavTab(icon: Icons.person, label: 'Profile'),
    _NavTab(icon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final screens = [
      GalleryScreen(client: widget.client, sfwMode: _sfwMode),
      SearchScreen(client: widget.client, sfwMode: _sfwMode),
      NotificationsScreen(client: widget.client),
      ProfileScreen(client: widget.client, session: widget.session),
      SettingsScreen(
        sfwMode: _sfwMode,
        onSfwModeChanged: _onSfwModeChanged,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: _tabs
              .map((tab) => BottomNavigationBarItem(
                    icon: Icon(tab.icon),
                    label: tab.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final String label;

  const _NavTab({required this.icon, required this.label});
}
