import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import '../../utils/platform_utils.dart';

/// Adaptive scaffold: Material Scaffold on Android, Fluent ScaffoldPage on Windows.
///
/// On Windows the Material AppBar is **not rendered** (fluent NavigationView
/// provides its own drag-titlebar). Instead the AppBar title is extracted and
/// placed into a static [fluent.ScaffoldPage.header] that never scrolls with
/// the page content.
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
      final header = _buildWindowsHeader(context);
      return fluent.ScaffoldPage(
        header: header,
        content: body,
      );
    }
    return Scaffold(
      appBar: appBar,
      body: body,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
    );
  }

  /// Build a static Fluent UI header from the Material AppBar.
  ///
  /// Extracts the title string (or any Widget) from the Material AppBar and
  /// renders it as a non-scrolling header with Fluent typography + bottom
  /// border decoration. This header stays fixed above the scrollable content.
  Widget? _buildWindowsHeader(BuildContext context) {
    if (appBar == null) return null;

    // Extract the title widget from AppBar
    final titleWidget = (appBar is AppBar) ? (appBar as AppBar).title : null;
    if (titleWidget == null) return null;

    // If the title is a simple Text, extract string and apply Fluent style
    String? titleText;
    if (titleWidget is Text) {
      titleText = titleWidget.data;
    }

    final theme = fluent.FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.resources.cardStrokeColorDefault
                .withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        children: [
          if (titleText != null)
            Text(
              titleText,
              style: theme.typography.subtitle?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            )
          else
            titleWidget,
        ],
      ),
    );
  }
}
