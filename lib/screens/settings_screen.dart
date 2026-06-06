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
  String _imageQuality = 'high'; // low, medium, high
  String _customDownloadPath = '';
  final UpdateService _updateService = UpdateService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sfwMode = widget.sfwMode;
    _updateService.init();
    _loadSettings();
  }

  @override
  void dispose() {
    _updateService.dispose();
    super.dispose();
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
      debugPrint('=== SettingsScreen: Syncing SFW toggle with FA website...');
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
          backgroundColor: AppColors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text('Logout', style: TextStyle(color: AppColors.text)),
          content: const Text(
            'Are you sure you want to logout? You will need to sign in again.',
            style: TextStyle(color: AppColors.textDim),
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
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
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
            iconColor: AppColors.materialGreen,
            value: _sfwMode,
            onChanged: _onSfwToggle,
            title: 'SFW Mode',
            subtitle: 'Blur NSFW content',
          ),
          const Divider(height: 1, indent: 16, color: AppColors.border),
          _adaptiveSwitchTile(
            icon: Icons.download_outlined,
            iconColor: AppColors.fluentCyan,
            value: _autoDownloadOnFave,
            onChanged: (v) {
              setState(() => _autoDownloadOnFave = v);
              _saveSetting('auto_download_on_fave', v);
            },
            title: 'Auto-download on Fave',
            subtitle: 'Save image when favoriting',
          ),
          const Divider(height: 1, indent: 16, color: AppColors.border),
          _adaptiveSwitchTile(
            icon: Icons.close_fullscreen_outlined,
            iconColor: AppColors.cupertinoPurple,
            value: _autoCloseOnFave,
            onChanged: (v) {
              setState(() => _autoCloseOnFave = v);
              _saveSetting('auto_close_on_fave', v);
            },
            title: 'Auto-close on Fave',
            subtitle: 'Close submission view after favoriting',
          ),
          const Divider(height: 1, indent: 16, color: AppColors.border),
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
            color: AppColors.danger,
            title: 'Logout',
            onTap: _confirmLogout,
          ),
        ]),
        const SizedBox(height: 24),
        _sectionHeader('ABOUT'),
        _card([
          _infoTile(
            icon: Icons.pets,
            iconColor: AppColors.accentLight,
            title: 'FurClient',
            subtitle: 'A FurAffinity client',
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _infoTile(
            icon: Icons.info_outline,
            iconColor: AppColors.textDim,
            title: 'Version',
            trailing: '1.0.0',
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _buildUpdateTile(),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          _infoTile(
            icon: Icons.code,
            iconColor: AppColors.textDim,
            title: 'Built with Flutter',
            trailing: '3.x',
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDesktopBody() {
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
                accent: AppColors.cupertinoPurple,
                children: [_buildThemeTile()],
              ),
              const SizedBox(height: 20),
              _desktopSection(
                title: 'Content',
                icon: Icons.tune,
                accent: AppColors.materialGreen,
                children: [
                  _adaptiveSwitchTile(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.materialGreen,
                    value: _sfwMode,
                    onChanged: _onSfwToggle,
                    title: 'SFW Mode',
                    subtitle: 'Blur NSFW content',
                  ),
                  const Divider(height: 1, indent: 16, color: AppColors.border),
                  _adaptiveSwitchTile(
                    icon: Icons.download_outlined,
                    iconColor: AppColors.fluentCyan,
                    value: _autoDownloadOnFave,
                    onChanged: (v) {
                      setState(() => _autoDownloadOnFave = v);
                      _saveSetting('auto_download_on_fave', v);
                    },
                    title: 'Auto-download on Fave',
                    subtitle: 'Save image when favoriting',
                  ),
                  const Divider(height: 1, indent: 16, color: AppColors.border),
                  _adaptiveSwitchTile(
                    icon: Icons.close_fullscreen_outlined,
                    iconColor: AppColors.cupertinoPurple,
                    value: _autoCloseOnFave,
                    onChanged: (v) {
                      setState(() => _autoCloseOnFave = v);
                      _saveSetting('auto_close_on_fave', v);
                    },
                    title: 'Auto-close on Fave',
                    subtitle: 'Close submission view after favoriting',
                  ),
                  const Divider(height: 1, indent: 16, color: AppColors.border),
                  _buildImageQualityTile(),
                ],
              ),
              const SizedBox(height: 20),
              _desktopSection(
                title: 'Downloads',
                icon: Icons.folder_outlined,
                accent: AppColors.fluentCyan,
                children: [_buildDownloadFolderTile()],
              ),
              const SizedBox(height: 20),
              _desktopSection(
                title: 'Account',
                icon: Icons.person,
                accent: AppColors.fluentCyan,
                children: [
                  _actionTile(
                    icon: Icons.logout,
                    color: AppColors.danger,
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
                accent: AppColors.materialLavender,
                children: [
                  _infoTile(
                    icon: Icons.pets,
                    iconColor: AppColors.accentLight,
                    title: 'FurClient',
                    subtitle: 'A FurAffinity client',
                  ),
                  const Divider(height: 1, indent: 56, color: AppColors.border),
                  _infoTile(
                    icon: Icons.info_outline,
                    iconColor: AppColors.textDim,
                    title: 'Version',
                    trailing: '1.0.0',
                  ),
                  const Divider(height: 1, indent: 56, color: AppColors.border),
                  _buildUpdateTile(),
                  const Divider(height: 1, indent: 56, color: AppColors.border),
                  _infoTile(
                    icon: Icons.code,
                    iconColor: AppColors.textDim,
                    title: 'Built with Flutter',
                    trailing: '3.x',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared tile helpers (no Material widgets) ──────────────────────

  /// Info row — icon + title + optional subtitle + optional trailing text.
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
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          if (trailing != null)
            Text(trailing,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  /// Action row — icon + title + optional subtitle, tappable.
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
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Image quality tile with platform-conditional dropdown.
  Widget _buildImageQualityTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.high_quality_outlined,
              color: AppColors.materialLavender, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image Quality',
                    style:
                        TextStyle(color: AppColors.text, fontSize: 15)),
                SizedBox(height: 2),
                Text('Quality for full-size images',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 13)),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _imageQuality,
                  isDense: true,
                  style: const TextStyle(color: AppColors.text, fontSize: 13),
                  dropdownColor: AppColors.bgCard,
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

  /// Download folder tile — no Material/InkWell.
  Widget _buildDownloadFolderTile() {
    final displayPath =
        _customDownloadPath.isEmpty ? 'Default' : _customDownloadPath;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.folder_outlined,
              color: AppColors.fluentCyan, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Download Folder',
                    style:
                        TextStyle(color: AppColors.text, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  displayPath,
                  style: TextStyle(
                    color: _customDownloadPath.isEmpty
                        ? AppColors.textMuted
                        : AppColors.textDim,
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
              child: const Padding(
                padding: EdgeInsets.all(4),
                child:
                    Icon(Icons.close, size: 16, color: AppColors.textDim),
              ),
            ),
          GestureDetector(
            onTap: _pickFolder,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.bgInput,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 14, color: AppColors.fluentCyan),
                  SizedBox(width: 4),
                  Text('Change',
                      style:
                          TextStyle(color: AppColors.fluentCyan, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section helpers ──────────────────────────────────────────────────

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
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

  /// Update check tile — version + check/download button.
  Widget _buildUpdateTile() {
    return ListenableBuilder(
      listenable: _updateService,
      builder: (context, _) {
        final status = _updateService.status;
        final version = _updateService.currentVersion ?? '...';
        final latest = _updateService.latestVersion;

        Color iconColor = AppColors.textDim;
        String subtitle = 'v$version';

        if (status == UpdateStatus.checking) {
          iconColor = AppColors.fluentCyan;
          subtitle = 'Checking...';
        } else if (status == UpdateStatus.available) {
          iconColor = AppColors.materialGreen;
          subtitle = 'v$version \u2192 v$latest available!';
        } else if (status == UpdateStatus.downloading) {
          iconColor = AppColors.fluentCyan;
          final pct = (_updateService.downloadProgress * 100).toInt();
          subtitle = 'Downloading... $pct%';
        } else if (status == UpdateStatus.installing) {
          iconColor = AppColors.materialGreen;
          subtitle = 'Installing...';
        } else if (status == UpdateStatus.upToDate) {
          iconColor = AppColors.materialGreen;
          subtitle = 'v$version \u2014 up to date';
        } else if (status == UpdateStatus.error) {
          iconColor = AppColors.danger;
          subtitle = _updateService.errorMessage ?? 'Update check failed';
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
                    const Text('Update',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: status == UpdateStatus.error
                                ? AppColors.danger
                                : AppColors.textMuted,
                            fontSize: 13)),
                    if (status == UpdateStatus.downloading)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: _updateService.downloadProgress,
                            backgroundColor: AppColors.bgInput,
                            valueColor:
                                const AlwaysStoppedAnimation(AppColors.fluentCyan),
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
                  onTap: () => _updateService.checkForUpdate(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, size: 14, color: AppColors.fluentCyan),
                        SizedBox(width: 4),
                        Text('Check',
                            style: TextStyle(
                                color: AppColors.fluentCyan, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else if (status == UpdateStatus.available)
                GestureDetector(
                  onTap: () => _updateService.downloadAndInstall(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.materialGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Update',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13)),
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

  /// Theme selection tile — System / Light / Dark / Original.
  Widget _buildThemeTile() {
    return ListenableBuilder(
      listenable: widget.themeProvider,
      builder: (context, _) {
        final current = widget.themeProvider.mode;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.palette_outlined,
                  color: AppColors.cupertinoPurple, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Theme',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text('App appearance mode',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
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
                    color: AppColors.bgInput,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AppThemeMode>(
                      value: current,
                      isDense: true,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 13),
                      dropdownColor: AppColors.bgCard,
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
