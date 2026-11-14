import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:material_ui/material_ui.dart';

import '../../utils/platform_utils.dart';

/// Адаптивная «всплывающая панель».
///
/// Windows — Fluent-паттерн: ContentDialog по центру окна (bottom sheet —
/// подпись Material). Остальные платформы — showModalBottomSheet как раньше,
/// со всеми sheet-параметрами.
///
/// Контент должен сам предоставлять свои кнопки действий (Dialog без
/// actions — легитимный Fluent-вид, как в системных настройках).
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = true,
  bool scrollable = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  String? title,
}) {
  if (isWindows) {
    // Короткий контент кладём в ContentDialog напрямую: обёртка в
    // SingleChildScrollView ломает лейаут контента с Row(Flexible/Expanded)
    // (RenderBox was not laid out — Flexible в min-колонке скролла).
    return showDialog<T>(
      context: context,
      builder: (dialogContext) {
        final Widget content = scrollable
            ? ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(dialogContext).size.height * 0.72,
                ),
                child: SingleChildScrollView(child: builder(dialogContext)),
              )
            : builder(dialogContext);
        return fluent.ContentDialog(
          title: title != null ? Text(title) : null,
          content: content,
        );
      },
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    shape: shape,
    builder: builder,
  );
}
