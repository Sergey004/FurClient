import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:material_ui/material_ui.dart';
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

      // Шапка страницы: заголовок + действия AppBar + FAB как кнопка.
      // Раньше AppBar и FAB на Windows выбрасывались целиком — вместе
      // с ними становились недостижимы действия (кнопка Notes в
      // уведомлениях) и композ нотеса.
      Widget? header;
      final appBar = this.appBar;
      if (appBar is AppBar) {
        final actions = <Widget>[...?appBar.actions];
        final fab = floatingActionButton;
        if (fab is FloatingActionButton && fab.onPressed != null) {
          actions.add(
            fluent.FilledButton(
              onPressed: fab.onPressed,
              child: fab.child ?? const Icon(fluent.FluentIcons.add, size: 14),
            ),
          );
        }
        if (appBar.title != null || actions.isNotEmpty) {
          header = fluent.PageHeader(
            title: appBar.title,
            // commandBar принимает любой виджет (обычно CommandBar) —
            // отдаём действия AppBar как есть.
            commandBar: actions.isEmpty
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions),
          );
        }
      }

      return fluent.FluentTheme(
        data: fluentTheme,
        child: fluent.ScaffoldPage(
          header: header,
          content: ColoredBox(
            color: backgroundColor ?? colorScheme.surface,
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
