import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:material_ui/material_ui.dart';
import '../../theme/app_theme.dart';
import '../../utils/platform_utils.dart';

/// Material 3 styled list tile inspired by Google Messages.
class AppListTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const AppListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tiles = Theme.of(context).extension<AppTileTheme>() ??
        AppTileTheme.from(colors);
    // Windows — Fluent-поведение: hover/press через HoverButton вместо
    // Material-ripple.
    if (isWindows) {
      return fluent.HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          final theme = fluent.FluentTheme.of(context);
          final overlay = states.isPressed
              ? theme.resources.subtleFillColorTertiary
              : states.isHovered
                  ? theme.resources.subtleFillColorSecondary
                  : theme.resources.subtleFillColorTransparent;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: BoxDecoration(
              color: tiles.primaryBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            foregroundDecoration: BoxDecoration(
              color: overlay,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: padding,
              child: _buildRow(context, colors),
            ),
          );
        },
      );
    }
    return Material(
      color: tiles.primaryBackground,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: _buildRow(context, colors),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          trailing!,
        ],
      ],
    );
  }
}
