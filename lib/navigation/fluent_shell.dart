import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../models/models.dart';
import '../services/fa_client.dart';
import '../services/search_history.dart';
import '../theme/theme_provider.dart';
import '../screens/gallery_screen.dart';
import '../screens/watch_feed_screen.dart';
import '../screens/search_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/settings_screen.dart';
import '../utils/scroll_to_top.dart';

class FluentShell extends StatefulWidget {
  final FAClient client;
  final UserSession session;
  final VoidCallback onLogout;
  final ThemeProvider themeProvider;

  const FluentShell({
    super.key,
    required this.client,
    required this.session,
    required this.onLogout,
    required this.themeProvider,
  });

  @override
  State<FluentShell> createState() => _FluentShellState();
}

class _FluentShellState extends State<FluentShell> {
  int _currentIndex = 0;
  // Default to SFW on (NSFW off) until the site cookie is checked.
  bool _sfwMode = true;

  @override
  void initState() {
    super.initState();
    _loadSfwMode();
    SearchHistory.externalQuery.addListener(_onExternalSearch);
  }

  void _onExternalSearch() {
    if (SearchHistory.externalQuery.value != null && mounted) {
      setState(() => _currentIndex = 2);
    }
  }

  @override
  void dispose() {
    SearchHistory.externalQuery.removeListener(_onExternalSearch);
    super.dispose();
  }

  Future<void> _loadSfwMode() async {
    // Истина по приоритету: кука сайта → локальный преф → дефолт ON.
    // При «ON без куки» кука sfw_toggle=on дописывается — сайт тоже
    // начинает отдавать SFW-контент (см. resolveStartupSfwMode).
    final value = await widget.client.resolveStartupSfwMode();
    debugPrint('=== FluentShell: startup SFW mode = $value');
    if (mounted && value != _sfwMode) {
      setState(() => _sfwMode = value);
    }
  }

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
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: fluent.NavigationView(
      pane: fluent.NavigationPane(
        selected: _currentIndex,
        onChanged: (index) {
          // Повторный тап по активному пункту — скролл текущего списка
          // наверх (та же шина, что и в Material-шелле).
          if (index == _currentIndex) ScrollToTopBus.fire(index);
          setState(() => _currentIndex = index);
        },
        displayMode: fluent.PaneDisplayMode.auto,
        size: const fluent.NavigationPaneSize(openWidth: 280),
        header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: widget.session.avatarUrl.isNotEmpty
                      ? Image.network(
                          widget.session.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const fluent.Icon(
                            fluent.FluentIcons.contact,
                          ),
                        )
                      : const fluent.Icon(fluent.FluentIcons.contact),
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
              client: widget.client,
              sfwMode: _sfwMode,
              onLogout: widget.onLogout,
            ),
          ),
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.radio_bullet),
            title: const fluent.Text('Watch'),
            body: WatchFeedScreen(
              client: widget.client,
              sfwMode: _sfwMode,
              onLogout: widget.onLogout,
            ),
          ),
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.search),
            title: const fluent.Text('Search'),
            body: SearchScreen(
              client: widget.client,
              sfwMode: _sfwMode,
              onLogout: widget.onLogout,
            ),
          ),
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.ringer),
            title: const fluent.Text('Notifications'),
            body: NotificationsScreen(
              client: widget.client,
              onLogout: widget.onLogout,
            ),
          ),
          fluent.PaneItem(
            icon: const fluent.Icon(fluent.FluentIcons.contact),
            title: const fluent.Text('Profile'),
            body: ProfileScreen(
              client: widget.client,
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
              client: widget.client,
              themeProvider: widget.themeProvider,
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
      ),
    );
  }
}
