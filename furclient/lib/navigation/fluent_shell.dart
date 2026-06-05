import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../models/models.dart';
import '../widgets/caption_buttons.dart';
import '../services/fa_client.dart';
import '../services/search_history.dart';
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

  final _searchController = fluent.TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSfwMode();
    SearchHistory.externalQuery.addListener(_onExternalSearch);
  }

  @override
  void dispose() {
    SearchHistory.externalQuery.removeListener(_onExternalSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onExternalSearch() {
    if (SearchHistory.externalQuery.value != null && mounted) {
      setState(() => _currentIndex = 1);
    }
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

  void _onSearchSubmitted(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    SearchHistory.triggerSearch(trimmed);
    _searchController.clear();
    if (mounted) setState(() => _currentIndex = 1);
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
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 640;

    return fluent.NavigationView(
      // ── Title bar with drag support via fluent_ui TitleBar callbacks ──
      // fluent.TitleBar uses a GestureDetector internally and fires
      // onDragStarted / onDoubleTap when the user drags/double-taps
      // empty areas. We wire them to window_manager for native move.
      titleBar: fluent.TitleBar(
        isBackButtonVisible: false,
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(fluent.FluentIcons.photo2, size: 16),
            const SizedBox(width: 8),
            Text(
              'FurClient',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        title: isCompact ? null : _buildTitleSearch(),
        captionControls: isCompact
            ? null
            : SizedBox(
                width: 138,
                height: 46,
                child: CaptionButtons(
                  brightness: fluent.FluentTheme.of(context).brightness,
                ),
              ),
        // ← fluent TitleBar's built-in drag callbacks → window_manager
        onDragStarted: () => windowManager.startDragging(),
        onDoubleTap: () async {
          final isMax = await windowManager.isMaximized();
          if (isMax) {
            windowManager.restore();
          } else {
            windowManager.maximize();
          }
        },
      ),
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
                      style: fluent.FluentTheme.of(context)
                          .typography
                          .bodyStrong,
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

  /// Search box for the title bar center area.
  Widget _buildTitleSearch() {
    return Center(
      child: SizedBox(
        width: 280,
        height: 30,
        child: fluent.TextBox(
          controller: _searchController,
          placeholder: 'Search FurAffinity...',
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8, right: 4),
            child: Icon(fluent.FluentIcons.search, size: 14),
          ),
          onSubmitted: _onSearchSubmitted,
          style: const TextStyle(fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        ),
      ),
    );
  }
}
