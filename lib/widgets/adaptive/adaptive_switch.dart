import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_utils.dart';

/// Adaptive switch — Fluent ToggleSwitch on Windows, Material Switch on others.
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return fluent.ToggleSwitch(
        checked: value,
        onChanged: onChanged,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: const Color(0xFF00B7C3),
      activeThumbColor: const Color(0xFF008B97),
    );
  }
}

/// Adaptive switch row — icon + title + subtitle + switch.
/// Replaces SwitchListTile to avoid Material look on Windows.
class AdaptiveSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  const AdaptiveSwitchTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          AdaptiveSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
