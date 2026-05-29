import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../models/models.dart';
import '../screens/gallery_screen.dart';
import '../screens/search_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';

class FluentShell extends StatefulWidget {
  final OnlineFASession session;
  final VoidCallback onLogout;

  const FluentShell({
    super.key,
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

  Future<void> _confirmLogout() async {
    final confirmed = await fluent.showDialog<bool>(
      context: context,
      builder: (ctx) => fluent.ContentDialog(
        title: const fluent.Text('Sign out'),
        content: fluent.Text(
          'Sign out of ${widget.session.username}?',
        ),
        actions: [
          fluent.Button(
            child: const fluent.Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          fluent.FilledButton(
            style: fluent.ButtonStyle(
              backgroundColor: fluent.WidgetStateProperty.all(
                fluent.Colors.errorPrimaryColor,
              ),
            ),
            child: const fluent.Text('Sign out'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: _currentIndex,
        onChanged: (index) => setState(() => _currentIndex = index),
        displayMode: fluent.PaneDisplayMode.auto,
        header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Image.network(
                    'https://a.furaffinity.net/${widget.session.username}.gif',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const fluent.Icon(
                      fluent.FluentIcons.contact,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    fluent.Text(
                      widget.session.username,
                      style:
                          fluent.FluentTheme.of(context).typography.bodyStrong,
                      overflow: TextOverflow.ellipsis,
                    ),
                    fluent.Text(
                      'FurAffinity',
                      style: fluent.FluentTheme.of(context)
                          .typography
                          .caption
                          ?.copyWith(
                            color: fluent.FluentTheme.of(context).inactiveColor,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        items: [
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.photo2),
            title: const fluent.Text('Gallery'),
            body: GalleryScreen(
              session: widget.session,
              sfwMode: _sfwMode,
              onLogout: widget.onLogout,
            ),
          ),
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.search),
            title: const fluent.Text('Search'),
            body: SearchScreen(
              session: widget.session,
              sfwMode: _sfwMode,
              onLogout: widget.onLogout,
            ),
          ),
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.ringer),
            title: const fluent.Text('Notifications'),
            body: NotificationsScreen(
              session: widget.session,
              onLogout: widget.onLogout,
            ),
          ),
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.contact),
            title: const fluent.Text('Profile'),
            body: ProfileScreen(
              session: widget.session,
              onLogout: widget.onLogout,
            ),
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
        footerItems: [
          fluent.PaneItemSeparator(),
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.sign_out),
            title: const fluent.Text('Sign out'),
            body: const SizedBox.shrink(),
            onTap: _confirmLogout,
          ),
        ],
      ),
    );
  }
}
