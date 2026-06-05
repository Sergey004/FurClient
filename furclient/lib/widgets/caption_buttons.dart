import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';

/// Custom window caption buttons (minimize / maximize / close).
/// Replaces the non-existent fluent_ui WindowCaption.
class CaptionButtons extends StatelessWidget {
  final Brightness brightness;

  const CaptionButtons({
    super.key,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final iconColor = isDark ? const Color(0xFFcccccc) : const Color(0xFF333333);
    final closeHoverColor = const Color(0xFFc42b1c);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptionButton(
          icon: Icons.minimize,
          iconColor: iconColor,
          onTap: () => windowManager.minimize(),
        ),
        _CaptionButton(
          icon: Icons.crop_square,
          iconColor: iconColor,
          onTap: () async {
            final isMax = await windowManager.isMaximized();
            if (isMax) {
              windowManager.restore();
            } else {
              windowManager.maximize();
            }
          },
        ),
        _CaptionButton(
          icon: Icons.close,
          iconColor: iconColor,
          hoverColor: closeHoverColor,
          hoverIconColor: Colors.white,
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _CaptionButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color? hoverColor;
  final Color? hoverIconColor;
  final VoidCallback onTap;

  const _CaptionButton({
    required this.icon,
    required this.iconColor,
    this.hoverColor,
    this.hoverIconColor,
    required this.onTap,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _isHovered ? (widget.hoverColor ?? AppColors.bgCardHover) : Colors.transparent;
    final icon = _isHovered ? (widget.hoverIconColor ?? widget.iconColor) : widget.iconColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 46,
          height: 32,
          color: color,
          child: Icon(widget.icon, size: 16, color: icon),
        ),
      ),
    );
  }
}
