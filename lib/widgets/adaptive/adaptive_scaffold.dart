import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';
import '../../theme/app_theme.dart';

class AdaptiveScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;

  const AdaptiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      final colorScheme = Theme.of(context).colorScheme;
      final fluentTheme = colorScheme.brightness == Brightness.dark
          ? AppTheme.fluentFromSystemAccent(colorScheme.primary)
          : AppTheme.fluentLightTheme(accent: colorScheme.primary);

      return fluent.FluentTheme(
        data: fluentTheme,
        child: fluent.ScaffoldPage(
          content: ColoredBox(
            color: backgroundColor ?? AppColors.bg,
            child: body,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: body,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
    );
  }
}
