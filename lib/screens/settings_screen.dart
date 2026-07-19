import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_selector/file_selector.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive/adaptive.dart';
import '../services/fa_client.dart';
import '../services/update_service.dart';
import '../utils/platform_utils.dart';
import '../theme/theme_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io' show Platform;

class SettingsScreen extends StatefulWidget {
  final bool sfwMode;
  final ValueChanged<bool> onSfwModeChanged;
  final VoidCallback onLogout;
  final FAClient? client;
  final ThemeProvider themeProvider;

  const SettingsScreen({
    super.key,
    this.sfwMode = false,
    required this.onSfwModeChanged,
    required this.onLogout,
    this.client,
    required this.themeProvider,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  bool _sfwMode = false;
  bool _autoDownloadOnFave = false;
  bool _autoCloseOnFave = true;
  String _imageQuality = 'high';
  String _customDownloadPath = '';
  UpdateService? _updateService;
  String _appVersion = '...';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sfwMode = widget.sfwMode;
    // UpdateService is Windows-only; Android uses the upgrader package.
    if (Platform.isWindows) {
      _updateService = UpdateService()..init();
    }
    _loadSettings();
    _loadVersionInfo();
  }

  @override
  void dispose() {
    _updateService?.dispose();
    super.dispose();
  }

  Future<void> _loadVersionInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoDownloadOnFave = prefs.getBool('auto_download_on_fave') ?? false;
        _autoCloseOnFave = prefs.getBool('auto_close_on_fave') ?? true;
        _imageQuality = prefs.getString('image_quality') ?? 'high';
        _customDownloadPath = prefs.getString('custom_download_path') ?? '';
      });
    }
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  Future<void> _onSfwToggle(bool value) async {
    setState(() => _sfwMode = value);
    widget.onSfwModeChanged(value);
    await _saveSetting('sfw_mode', value);
    if (widget.client != null) {
      await widget.client!.toggleSiteSfwMode();
    }
  }

  void _confirmLogout() {
    if (isWindows) {
      fluent.showDialog(
        context: context,
        builder: (context) => fluent.ContentDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout? You will need to sign in again.',
          ),
          actions: [
            fluent.Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            fluent.FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
              child: const Text('Logout'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.12)),
          ),
          title: Text('Logout',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          content: Text(
            'Are you sure you want to logout? You will need to sign in again.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onLogout();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Logout'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

    return AdaptiveScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: isDesktop ? _buildDesktopBody() : _buildMobileBody(),
    );
  }

  Widget _buildMobileBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final secondary = colorScheme.primary;
    final tertiary = colorScheme.tertiary;
    final outline = colorScheme.outlineVariant.withValues(alpha: 0.12);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _sectionHeader('APPEARANCE'),
        _card([_buildThemeTile()]),
        const SizedBox(height: 24),
        _sectionHeader('CONTENT'),
        _card([
          _adaptiveSwitchTile(
            icon: Icons.shield_outlined,
            iconColor: primary,
            value: _sfwMode,
            onChanged: _onSfwToggle,
            title: 'SFW Mode',
            subtitle: 'Blur NSFW content',
          ),
          Divider(height: 1, indent: 16, color: outline),
          _adaptiveSwitchTile(
            icon: Icons.download_outlined,
            iconColor: secondary,
            value: _autoDownloadOnFave,
            onChanged: (v) {
              setState(() => _autoDownloadOnFave = v);
              _saveSetting('auto_download_on_fave', v);
            },
            title: 'Auto-download on Fave',
            subtitle: 'Save image when favoriting',
          ),
          Divider(height: 1, indent: 16, color: outline),
          Divider(height: 1, indent: 16, color: outline),
          _adaptiveSwitchTile(
            icon: Icons.close_fullscreen_outlined,
            iconColor: tertiary,
            value: _autoCloseOnFave,
            onChanged: (v) {
              setState(() => _autoCloseOnFave = v);
              _saveSetting('auto_close_on_fave', v);
            },
            title: 'Auto-close on Fave',
            subtitle: 'Close submission view after favoriting',
          ),
          Divider(height: 1, indent: 16, color: outline),
          Divider(height: 1, indent: 56, color: outline),
          _buildImageQualityTile(),
        ]),
        const SizedBox(height: 24),
        _sectionHeader('DOWNLOADS'),
        _card([_buildDownloadFolderTile()]),
        const SizedBox(height: 24),
        _sectionHeader('ACCOUNT'),
        _card([
          _actionTile(
            icon: Icons.logout,
            color: Theme.of(context).colorScheme.error,
            title: 'Logout',
            onTap: _confirmLogout,
          ),
        ]),
        const SizedBox(height: 24),
        _sectionHeader('ABOUT'),
        _card([
          _infoTile(
            icon: Icons.pets,
            iconColor: primary,
            title: 'FurClient',
            subtitle: 'A FurAffinity client',
          ),
          Divider(height: 1, indent: 56, color: outline),
          _infoTile(
            icon: Icons.info_outline,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            title: 'Version',
            trailing: _appVersion,
          ),
          if (Platform.isWindows) ...[
            Divider(
                height: 1,
                indent: 56,
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.12)),
            _buildUpdateTile(),
          ],
          Divider(
              height: 1,
              indent: 56,
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.12)),
          _infoTile(
            icon: Icons.code,
            iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
            title: 'Built with Flutter',
            trailing: 'Flutter',
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDesktopBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final secondary = colorScheme.primary;
    final tertiary = colorScheme.tertiary;
    final outline = colorScheme.outlineVariant.withValues(alpha: 0.12);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              _desktopSection(
                title: 'Appearance',
                icon: Icons.palette_outlined,
                accent: primary,
                children: [_buildThemeTile()],
              ),
              const SizedBox(height: 20),
              _desktopSection(
                title: 'Content',
                icon: Icons.tune,
                accent: tertiary,
                children: [
                  _adaptiveSwitchTile(
                    icon: Icons.shield_outlined,
                    iconColor: primary,
                    value: _sfwMode,
                    onChanged: _onSfwToggle,
                    title: 'SFW Mode',
                    subtitle: 'Blur NSFW content',
                  ),
                  Divider(height: 1, indent: 16, color: outline),
                  _adaptiveSwitchTile(
                    icon: Icons.download_outlined,
                    iconColor: secondary,
                    value: _autoDownloadOnFave,
                    onChanged: (v) {
                      setState(() => _autoDownloadOnFave = v);
                      _saveSetting('auto_download_on_fave', v);
                    },
                    title: 'Auto-download on Fave',
                    subtitle: 'Save image when favoriting',
                  ),
                  Divider(height: 1, indent: 16, color: outline),
                  _adaptiveSwitchTile(
                    icon: Icons.close_fullscreen_outlined,
                    iconColor: tertiary,
                    value: _autoCloseOnFave,
                    onChanged: (v) {
                      setState(() => _autoCloseOnFave = v);
                      _saveSetting('auto_close_on_fave', v);
                    },
                    title: 'Auto-close on Fave',
                    subtitle: 'Close submission view after favoriting',
                  ),
                  Divider(height: 1, indent: 16, color: outline),
                  _buildImageQualityTile(),
                ],
              ),
              const SizedBox(height: 20),
              _desktopSection(
                title: 'Downloads',
                icon: Icons.folder_outlined,
                accent: secondary,
                children: [_buildDownloadFolderTile()],
              ),
              const SizedBox(height: 20),
              _desktopSection(
                title: 'Account',
                icon: Icons.person,
                accent: secondary,
                children: [
                  _actionTile(
                    icon: Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                    title: 'Logout',
                    subtitle: 'Sign out and clear session',
                    onTap: _confirmLogout,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _desktopSection(
                title: 'About',
                icon: Icons.info_outline,
                accent: tertiary,
                children: [
                  _infoTile(
                    icon: Icons.pets,
                    iconColor: primary,
                    title: 'FurClient',
                    subtitle: 'A FurAffinity client',
                  ),
                  Divider(height: 1, indent: 56, color: outline),
                  _infoTile(
                    icon: Icons.info_outline,
                    iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    title: 'Version',
                    trailing: _appVersion,
                  ),
                  if (Platform.isWindows) ...[
                    Divider(
                        height: 1,
                        indent: 56,
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.12)),
                    _buildUpdateTile(),
                  ],
                  Divider(
                      height: 1,
                      indent: 56,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.12)),
                  _infoTile(
                    icon: Icons.code,
                    iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
                    title: 'Built with Flutter',
                    trailing: 'Flutter',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14)),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageQualityTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.high_quality_outlined,
              color: Theme.of(context).colorScheme.tertiary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image Quality',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text('Quality for full-size images',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isWindows)
            SizedBox(
              width: 120,
              child: fluent.ComboBox<String>(
                value: _imageQuality,
                isExpanded: true,
                items: ['low', 'medium', 'high']
                    .map((e) => fluent.ComboBoxItem<String>(
                          value: e,
                          child: Text(e == 'low'
                              ? 'Low'
                              : e == 'medium'
                                  ? 'Medium'
                                  : 'High'),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _imageQuality = v);
                    _saveSetting('image_quality', v);
                  }
                },
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.12)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _imageQuality,
                  isDense: true,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13),
                  dropdownColor: Theme.of(context).cardColor,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _imageQuality = v);
                      _saveSetting('image_quality', v);
                    }
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadFolderTile() {
    final displayPath =
        _customDownloadPath.isEmpty ? 'Default' : _customDownloadPath;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.folder_outlined,
              color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Download Folder',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  displayPath,
                  style: TextStyle(
                    color: _customDownloadPath.isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_customDownloadPath.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() => _customDownloadPath = '');
                _saveSetting('custom_download_path', '');
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          GestureDetector(
            onTap: _pickFolder,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit,
                      size: 14, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 4),
                  Text('Change',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = colorScheme.surfaceContainerHighest;
    final outline = colorScheme.outlineVariant.withValues(alpha: 0.12);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: outline),
      ),
      child: Column(children: children),
    );
  }

  Widget _desktopSection({
    required String title,
    required IconData icon,
    required Color accent,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: accent, size: 20),
            const SizedBox(width: 10),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _card(children),
      ],
    );
  }

  Future<void> _pickFolder() async {
    try {
      final result = await getDirectoryPath(
        confirmButtonText: 'Select Folder',
      );
      if (result != null && result.isNotEmpty) {
        setState(() => _customDownloadPath = result);
        await _saveSetting('custom_download_path', result);
      }
    } catch (e) {
      debugPrint('=== Settings: Folder picker error: $e');
    }
  }

  Widget _buildUpdateTile() {
    final svc = _updateService!;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final status = svc.status;
        final version = svc.currentVersion ?? '...';
        final latest = svc.latestVersion;

        Color iconColor = Theme.of(context).colorScheme.onSurfaceVariant;
        String subtitle = 'v$version';

        if (status == UpdateStatus.checking) {
          iconColor = Theme.of(context).colorScheme.primary;
          subtitle = 'Checking...';
        } else if (status == UpdateStatus.available) {
          iconColor = Theme.of(context).colorScheme.primary;
          subtitle = 'v$version -> v$latest available!';
        } else if (status == UpdateStatus.downloading) {
          iconColor = Theme.of(context).colorScheme.primary;
          final pct = (svc.downloadProgress * 100).toInt();
          subtitle = 'Downloading... $pct%';
        } else if (status == UpdateStatus.installing) {
          iconColor = Theme.of(context).colorScheme.primary;
          subtitle = 'Installing...';
        } else if (status == UpdateStatus.upToDate) {
          iconColor = Theme.of(context).colorScheme.primary;
          subtitle = 'v$version - up to date';
        } else if (status == UpdateStatus.error) {
          iconColor = Theme.of(context).colorScheme.error;
          subtitle = svc.errorMessage ?? 'Update check failed';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.system_update_outlined, color: iconColor, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Update',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: status == UpdateStatus.error
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontSize: 13)),
                    if (status == UpdateStatus.downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: svc.downloadProgress,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                                Theme.of(context).colorScheme.primary),
                            minHeight: 4,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (status == UpdateStatus.idle ||
                  status == UpdateStatus.upToDate ||
                  status == UpdateStatus.error)
                GestureDetector(
                  onTap: () => svc.checkForUpdate(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 4),
                        Text('Check',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else if (status == UpdateStatus.available)
                GestureDetector(
                  onTap: () => svc.downloadAndInstall(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Update',
                            style:
                                TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeTile() {
    return ListenableBuilder(
      listenable: widget.themeProvider,
      builder: (context, _) {
        final current = widget.themeProvider.mode;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.palette_outlined,
                  color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('App appearance mode',
                        style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isWindows)
                SizedBox(
                  width: 130,
                  child: fluent.ComboBox<AppThemeMode>(
                    value: current,
                    isExpanded: true,
                    items: AppThemeMode.values
                        .map((e) => fluent.ComboBoxItem<AppThemeMode>(
                              value: e,
                              child: Text(e.label),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) widget.themeProvider.setMode(v);
                    },
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.12)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AppThemeMode>(
                      value: current,
                      isDense: true,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13),
                      dropdownColor: Theme.of(context).cardColor,
                      items: AppThemeMode.values
                          .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(e.label),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) widget.themeProvider.setMode(v);
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _adaptiveSwitchTile({
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
  }) {
    return AdaptiveSwitchTile(
      icon: icon,
      iconColor: iconColor,
      value: value,
      onChanged: onChanged,
      title: title,
      subtitle: subtitle,
    );
  }
}
