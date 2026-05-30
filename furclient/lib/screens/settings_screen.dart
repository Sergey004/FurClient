import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive/adaptive.dart';

class SettingsScreen extends StatefulWidget {
  final bool sfwMode;
  final ValueChanged<bool> onSfwModeChanged;
  final VoidCallback onLogout;

  const SettingsScreen({
    super.key,
    this.sfwMode = false,
    required this.onSfwModeChanged,
    required this.onLogout,
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

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _sfwMode = widget.sfwMode;
    _loadSettings();
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

  void _confirmLogout() {
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
        _sectionHeader('CONTENT'),
        _card([
          _adaptiveSwitchTile(
            icon: Icons.shield_outlined,
            iconColor: AppColors.materialGreen,
            value: _sfwMode,
            onChanged: (v) {
              setState(() => _sfwMode = v);
              widget.onSfwModeChanged(v);
            },
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
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Row(
              children: [
                const Icon(Icons.high_quality_outlined, color: AppColors.materialLavender, size: 20),
                const SizedBox(width: 12),
                const Expanded(
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
          ),
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
            leading: Icon(Icons.code, color: AppColors.textDim, size: 22),
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
                title: 'Content',
                icon: Icons.tune,
                accent: AppColors.materialGreen,
                children: [
                  _adaptiveSwitchTile(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.materialGreen,
                    value: _sfwMode,
                    onChanged: (v) {
                      setState(() => _sfwMode = v);
                      widget.onSfwModeChanged(v);
                    },
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
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Row(
                      children: [
                        const Icon(Icons.high_quality_outlined, color: AppColors.materialLavender, size: 20),
                        const SizedBox(width: 12),
                        const Expanded(
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
                  ),
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
      activeThumbColor: AppColors.fluentCyanDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
