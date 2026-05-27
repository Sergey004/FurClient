import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';
import '../../theme/app_theme.dart';

class AdaptiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return fluent.Card(
        padding: padding ?? const EdgeInsets.all(12),
        backgroundColor: color ?? AppColors.bgCard,
        child: child,
      );
    }
    return Card(
      color: color ?? AppColors.bgCard,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}
