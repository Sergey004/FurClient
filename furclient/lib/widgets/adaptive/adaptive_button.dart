import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

class AdaptiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? child;
  final bool filled;

  const AdaptiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.child,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      if (filled) {
        return fluent.FilledButton(
          onPressed: onPressed,
          child: child ?? Text(label),
        );
      }
      return fluent.Button(
        onPressed: onPressed,
        child: child ?? Text(label),
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      child: child ?? Text(label),
    );
  }
}
