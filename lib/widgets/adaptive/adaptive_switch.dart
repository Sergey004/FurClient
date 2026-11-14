import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:material_ui/material_ui.dart';
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
    return Switch(value: value, onChanged: onChanged);
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
    // Вся строка — зона нажатия: тап по заголовку/подзаголовку тоже
    // переключает. GestureDetector (не InkWell) — чтобы не зависеть
    // от Material-предка во Fluent-дереве Windows.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
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
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AdaptiveSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
