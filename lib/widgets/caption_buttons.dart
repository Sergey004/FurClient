import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:window_manager/window_manager.dart';

/// Custom caption buttons (minimize / maximize / close) replacing the
/// non-existent `WindowCaption` from fluent_ui 4.15.1.
class CaptionButtons extends StatelessWidget {
  final fluent.Brightness brightness;
  final fluent.Color? backgroundColor;

  const CaptionButtons({
    super.key,
    this.brightness = fluent.Brightness.dark,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = brightness == fluent.Brightness.light;
    final inactive = isLight
        ? const fluent.Color(0xFF8A8A8A)
        : const fluent.Color(0xFF999999);
    final hoverBg = isLight
        ? const fluent.Color(0xFFD4D4D4)
        : const fluent.Color(0xFF333333);

    return SizedBox(
      width: 138,
      height: 48,
      child: Row(
        children: [
          _btn(
            fluent.FluentIcons.chrome_minimize,
            () => windowManager.minimize(),
            inactive,
            hoverBg: hoverBg,
          ),
          _btn(
            fluent.FluentIcons.stop,
            () async {
              final isMax = await windowManager.isMaximized();
              if (isMax) {
                windowManager.unmaximize();
              } else {
                windowManager.maximize();
              }
            },
            inactive,
            hoverBg: hoverBg,
          ),
          _btn(
            fluent.FluentIcons.chrome_close,
            () => windowManager.close(),
            inactive,
            hoverBg: hoverBg,
            isClose: true,
          ),
        ],
      ),
    );
  }

  Widget _btn(
    IconData icon,
    VoidCallback onPressed,
    Color inactive, {
    Color hoverBg = const fluent.Color(0xFF333333),
    bool isClose = false,
  }) {
    return _CaptionButton(
      icon: icon,
      onPressed: onPressed,
      inactiveColor: inactive,
      hoverBg: hoverBg,
      closeHoverBg: isClose ? const fluent.Color(0xFFC42B1C) : null,
    );
  }
}

class _CaptionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color inactiveColor;
  final Color hoverBg;
  final Color? closeHoverBg;

  const _CaptionButton({
    required this.icon,
    required this.onPressed,
    required this.inactiveColor,
    required this.hoverBg,
    this.closeHoverBg,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = _hovered
        ? (widget.closeHoverBg ?? widget.hoverBg)
        : const fluent.Color(0x00000000);
    final fg = _hovered ? const fluent.Color(0xFFFFFFFF) : widget.inactiveColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 32,
          color: bg,
          alignment: Alignment.center,
          child: Icon(widget.icon, size: 10, color: fg),
        ),
      ),
    );
  }
}
