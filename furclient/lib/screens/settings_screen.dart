import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/adaptive/adaptive.dart';
import '../services/fa_client.dart';
import '../main.dart' show themeProvider;

class SettingsScreen extends StatefulWidget {
  final bool sfwMode;
  final ValueChanged<bool> onSfwModeChanged;
  final VoidCallback onLogout;
  final FAClient? client;

  const SettingsScreen({
    super.key,
    this.sfwMode = false,
    required this.onSfwModeChanged,
    required this.onLogout,
    this.client,
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sfwMode = widget.sfwMode;
    _loadSettings();
    themeProvider.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoDownloadOnFave = prefs.getBool('auto_download_on_fave') ?? false;
        _autoCloseOnFave = prefs.getBool('auto_close_on_fave') ?? true;
        _imageQuality = prefs.getString('image_quality') ?? 'high';
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
    if (Platform.isWindows) {
      _confirmLogoutFluent();
      return;
    }
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

  void _confirmLogoutFluent() async {
    final confirmed = await fluent.showDialog<bool>(
      context: context,
      builder: (ctx) => fluent.ContentDialog(
        title: const fluent.Text('Sign out'),
        content: fluent.Text('Sign out of your account?'),
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
    super.build(context);

    if (Platform.isWindows) {
      return _buildFluentSettings();
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

    return AdaptiveScaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: isDesktop ? _buildDesktopBody() : _buildMobileBody(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FLUENT SETTINGS (Windows)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFluentSettings() {
    final currentMode = themeProvider.mode;
    final p = Palette.of(context);

    return fluent.ScaffoldPage(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      content: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Appearance ──────────────────────────────────────────────
                _fluentSectionHeader('APPEARANCE', Icons.palette_outlined,
                    AppColors.materialLavender),
                const SizedBox(height: 8),
                _fluentCard([
                  fluent.InfoLabel(
                    label: 'Theme',
                    child: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppThemeMode.values.map((m) {
                          final active = m == currentMode;
                          return fluent.ToggleButton(
                            checked: active,
                            onChanged: (v) {
                              if (v) themeProvider.setMode(m);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_themeIcon(m),
                                      size: 16,
                                      color: active
                                          ? Colors.white
                                          : p.textDim),
                                  const SizedBox(width: 8),
                                  fluent.Text(m.label),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _fluentDivider(),
                  _fluentSwitch(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.materialGreen,
                    value: _sfwMode,
                    onChanged: _onSfwToggle,
                    title: 'SFW Mode',
                    subtitle: 'Blur NSFW content',
                  ),
                  const SizedBox(height: 4),
                  _fluentDivider(),
                  _fluentSwitch(
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
                  const SizedBox(height: 4),
                  _fluentDivider(),
                  _fluentSwitch(
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
                  const SizedBox(height: 8),
                  _fluentImageQuality(),
                ]),
                const SizedBox(height: 24),

                // ── Account ────────────────────────────────────────────────
                _fluentSectionHeader('ACCOUNT', Icons.person_outline,
                    AppColors.fluentCyan),
                const SizedBox(height: 8),
                _fluentCard([
                  fluent.Button(
                    style: fluent.ButtonStyle(
                      backgroundColor: fluent.WidgetStateProperty.all(
                          AppColors.danger),
                    ),
                    onPressed: _confirmLogoutFluent,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.logout, size: 18),
                        SizedBox(width: 8),
                        fluent.Text('Sign out'),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 24),

                // ── About ─────────────────────────────────────────────────
                _fluentSectionHeader('ABOUT', Icons.info_outline,
                    AppColors.materialLavender),
                const SizedBox(height: 8),
                _fluentCard([
                  _fluentInfoRow(
                      Icons.pets, 'FurClient', 'A FurAffinity client',
                      iconColor: AppColors.accentLight),
                  _fluentDivider(),
                  _fluentInfoRow(
                      Icons.info_outline, 'Version', '1.0.0',
                      trailing: true),
                  _fluentDivider(),
                  _fluentInfoRow(
                      Icons.code, 'Built with', 'Flutter 3.x',
                      trailing: true),
                ]),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fluentSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _fluentCard(List<Widget> children) {
    final p = Palette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _fluentDivider() {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(height: 1, color: p.border),
    );
  }

  Widget _fluentSwitch({
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
  }) {
    final p = Palette.of(context);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: p.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              Text(subtitle,
                  style: TextStyle(
                      color: p.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        fluent.ToggleSwitch(
          checked: value,
          onChanged: (v) => onChanged(v),
        ),
      ],
    );
  }

  Widget _fluentImageQuality() {
    final p = Palette.of(context);
    return Row(
      children: [
        const Icon(Icons.high_quality_outlined,
            color: AppColors.materialLavender, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Image Quality',
                  style: TextStyle(
                      color: p.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              Text('Quality for full-size images',
                  style: TextStyle(color: p.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        fluent.ComboBox<String>(
          value: _imageQuality,
          items: const [
            fluent.ComboBoxItem(value: 'low', child: Text('Low')),
            fluent.ComboBoxItem(value: 'medium', child: Text('Medium')),
            fluent.ComboBoxItem(value: 'high', child: Text('High')),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() => _imageQuality = v);
              _saveSetting('image_quality', v);
            }
          },
        ),
      ],
    );
  }

  Widget _fluentInfoRow(IconData icon, String title, String subtitle,
      {Color? iconColor, bool trailing = false}) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? p.textDim, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: TextStyle(
                    color: p.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          if (trailing)
            Text(subtitle,
                style: TextStyle(
                    color: p.textMuted, fontSize: 14)),
          if (!trailing)
            Expanded(
              child: Text(subtitle,
                  style: TextStyle(
                      color: p.textMuted, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MATERIAL SETTINGS (Android / desktop Material)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMobileBody() {
    final currentMode = themeProvider.mode;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _sectionHeader('APPEARANCE'),
        _card([
          // Theme picker
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.palette_outlined,
                    color: AppColors.materialLavender, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Theme',
                      style: TextStyle(
                          color: AppColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppThemeMode.values.map((m) {
                  final active = m == currentMode;
                  return ChoiceChip(
                    avatar: Icon(_themeIcon(m),
                        size: 16,
                        color: active
                            ? AppColors.text
                            : AppColors.textMuted),
                    label: Text(m.label),
                    selected: active,
                    selectedColor: AppColors.materialLavenderBg,
                    onSelected: (_) => themeProvider.setMode(m),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, color: AppColors.border),
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
          _imageQualityTile(),
        ]),
        const SizedBox(height: 24),
        _sectionHeader('ACCOUNT'),
        _card([
          ListTile(
            leading:
                const Icon(Icons.logout, color: AppColors.danger, size: 22),
            title: const Text('Logout',
                style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            onTap: _confirmLogout,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ]),
        const SizedBox(height: 24),
        _sectionHeader('ABOUT'),
        _card([
          const ListTile(
            leading: Icon(Icons.pets, color: AppColors.accentLight, size: 22),
            title: Text('FurClient',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            subtitle: Text('A FurAffinity client',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          const ListTile(
            leading:
                Icon(Icons.info_outline, color: AppColors.textDim, size: 22),
            title: Text('Version',
                style: TextStyle(color: AppColors.text, fontSize: 15)),
            trailing: Text('1.0.0',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
          ),
          const Divider(height: 1, indent: 56, color: AppColors.border),
          const ListTile(
            leading:
                Icon(Icons.code, color: AppColors.textDim, size: 22),
            title: Text('Built with Flutter',
                style: TextStyle(color: AppColors.text, fontSize: 15)),
            trailing: Text('3.x',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
          ),
        ]),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDesktopBody() {
    final currentMode = themeProvider.mode;

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
                accent: AppColors.materialLavender,
                children: [
                  // Theme picker
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppThemeMode.values.map((m) {
                          final active = m == currentMode;
                          return ChoiceChip(
                            avatar: Icon(_themeIcon(m),
                                size: 16,
                                color: active
                                    ? AppColors.text
                                    : AppColors.textMuted),
                            label: Text(m.label),
                            selected: active,
                            selectedColor:
                                AppColors.materialLavenderBg,
                            onSelected: (_) => themeProvider.setMode(m),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const Divider(
                      height: 1, indent: 16, color: AppColors.border),
                  _adaptiveSwitchTile(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.materialGreen,
                    value: _sfwMode,
                    onChanged: _onSfwToggle,
                    title: 'SFW Mode',
                    subtitle: 'Blur NSFW content',
                  ),
                  const Divider(
                      height: 1, indent: 16, color: AppColors.border),
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
                  const Divider(
                      height: 1, indent: 16, color: AppColors.border),
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
                  const Divider(
                      height: 1, indent: 16, color: AppColors.border),
                  _imageQualityTile(),
                ],
              ),
              const SizedBox(height: 20),
              _desktopSection(
                title: 'Account',
                icon: Icons.person,
                accent: AppColors.fluentCyan,
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout,
                        color: AppColors.danger, size: 22),
                    title: const Text('Logout',
                        style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    subtitle: const Text('Sign out and clear session',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    onTap: _confirmLogout,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _desktopSection(
                title: 'About',
                icon: Icons.info_outline,
                accent: AppColors.materialLavender,
                children: const [
                  ListTile(
                    leading: Icon(Icons.pets,
                        color: AppColors.accentLight, size: 22),
                    title: Text('FurClient',
                        style: TextStyle(
                            color: AppColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text('A FurAffinity client',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.border),
                  ListTile(
                    leading: Icon(Icons.info_outline,
                        color: AppColors.textDim, size: 22),
                    title: Text('Version',
                        style: TextStyle(color: AppColors.text, fontSize: 15)),
                    trailing: Text('1.0.0',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 14)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Divider(height: 1, indent: 56, color: AppColors.border),
                  ListTile(
                    leading:
                        Icon(Icons.code, color: AppColors.textDim, size: 22),
                    title: Text('Built with Flutter',
                        style: TextStyle(color: AppColors.text, fontSize: 15)),
                    trailing: Text('3.x',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 14)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  IconData _themeIcon(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return Icons.brightness_auto;
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.original:
        return Icons.palette;
    }
  }

  Widget _sectionHeader(String text) {
    final c = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: TextStyle(
          color: c.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    final c = Palette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
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

  Widget _adaptiveSwitchTile({
    required IconData icon,
    required Color iconColor,
    required bool value,
    required ValueChanged<bool> onChanged,
    required String title,
    required String subtitle,
  }) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: const TextStyle(color: AppColors.text, fontSize: 15))),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 32),
        child: Text(subtitle,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _imageQualityTile() {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: const [
          Icon(Icons.high_quality_outlined,
              color: AppColors.materialLavender, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text('Image Quality',
                style: TextStyle(color: AppColors.text, fontSize: 15)),
          ),
        ],
      ),
      subtitle: const Padding(
        padding: EdgeInsets.only(left: 32),
        child: Text('Quality for full-size images',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
    );
  }
}
