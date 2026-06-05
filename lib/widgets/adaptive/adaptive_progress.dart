import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';
import '../../theme/app_theme.dart';

class AdaptiveProgress extends StatelessWidget {
  final Color? color;
  final double? strokeWidth;

  const AdaptiveProgress({super.key, this.color, this.strokeWidth});

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return fluent.ProgressRing(
        activeColor: color ?? AppColors.fluentCyan,
      );
    }
    return CircularProgressIndicator(
      color: color ?? AppColors.fluentCyan,
      strokeWidth: strokeWidth ?? 4,
    );
  }
}
