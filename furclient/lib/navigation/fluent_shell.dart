import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../models/models.dart';
import '../services/fa_client.dart';
import '../screens/gallery_screen.dart';
import '../screens/search_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';

class FluentShell extends StatefulWidget {
  final FAClient client;
  final UserSession session;
  final VoidCallback onLogout;

  const FluentShell({
    super.key,
    required this.client,
    required this.session,
    required this.onLogout,
  });

  @override
  State<FluentShell> createState() => _FluentShellState();
}

class _FluentShellState extends State<FluentShell> {
  int _currentIndex = 0;
  bool _sfwMode = false;

  void _onSfwModeChanged(bool value) {
    setState(() => _sfwMode = value);
  }

  @override
  Widget build(BuildContext context) {
    return fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: _currentIndex,
        onChanged: (index) => setState(() => _currentIndex = index),
        displayMode: fluent.PaneDisplayMode.auto,
        items: [
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.photo2),
            title: const fluent.Text('Gallery'),
      body: GalleryScreen(client: widget.client, sfwMode: _sfwMode, onLogout: widget.onLogout),
        ),
        fluent.PaneItem(
          icon: const fluent.Icon(fluent.FluentIcons.search),
          title: const fluent.Text('Search'),
          body: SearchScreen(client: widget.client, sfwMode: _sfwMode, onLogout: widget.onLogout),
        ),
        fluent.PaneItem(
          icon: const fluent.Icon(fluent.FluentIcons.ringer),
          title: const fluent.Text('Notifications'),
          body: NotificationsScreen(client: widget.client, onLogout: widget.onLogout),
        ),
        fluent.PaneItem(
          icon: const fluent.Icon(fluent.FluentIcons.contact),
          title: const fluent.Text('Profile'),
          body: ProfileScreen(client: widget.client, session: widget.session, onLogout: widget.onLogout),
          ),
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.settings),
            title: const fluent.Text('Settings'),
            body: SettingsScreen(
              sfwMode: _sfwMode,
              onSfwModeChanged: _onSfwModeChanged,
              onLogout: widget.onLogout,
            ),
          ),
        ],
      ),
    );
  }
}
