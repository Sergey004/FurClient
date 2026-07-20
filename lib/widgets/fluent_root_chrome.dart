import 'package:flutter/widgets.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:window_manager/window_manager.dart';
import 'caption_buttons.dart';
import '../theme/app_theme.dart';

/// Specification of what the root window chrome should display.
@immutable
class ChromeSpec {
  final Widget? leading;
  final Widget? title;

  const ChromeSpec({this.leading, this.title});

  static const empty = ChromeSpec();

  @override
  bool operator ==(Object other) =>
      other is ChromeSpec && other.leading == leading && other.title == title;

  @override
  int get hashCode => Object.hash(leading, title);
}

/// Lets nested screens push their own [leading] / [title] into the root chrome.
/// The chrome is owned by the root of the app; screens borrow it while mounted
/// and must call [reset] in their [State.dispose].
class FluentRootChromeController extends ValueNotifier<ChromeSpec> {
  FluentRootChromeController() : super(const ChromeSpec());

  ChromeSpec get spec => value;

  void setChrome({Widget? leading, Widget? title}) {
    value = ChromeSpec(leading: leading, title: title);
  }

  void reset() {
    value = const ChromeSpec();
  }

  /// Returns the nearest controller in the tree, or `null` if the screen is
  /// not under a [FluentRootChrome] (e.g. on non-Windows platforms).
  static FluentRootChromeController? maybeOf(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_RootChromeScope>();
    return scope?.controller;
  }
}

/// Single Fluent-styled root window chrome for the Windows build. Wraps the
/// whole app *above* the root [Navigator], so pushed detail screens cannot
/// overlay it — the window caption buttons therefore stay put in one place.
class FluentRootChrome extends StatefulWidget {
  final Widget child;

  const FluentRootChrome({super.key, required this.child});

  @override
  State<FluentRootChrome> createState() => _FluentRootChromeState();
}

class _FluentRootChromeState extends State<FluentRootChrome> {
  final FluentRootChromeController _controller = FluentRootChromeController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    final topInsets = MediaQuery.paddingOf(context).top;

    return _RootChromeScope(
      controller: _controller,
      child: Column(
        children: [
          SizedBox(
            height: topInsets,
            child: ColoredBox(color: theme.micaBackgroundColor),
          ),
          ValueListenableBuilder<ChromeSpec>(
            valueListenable: _controller,
            builder: (context, spec, _) {
              return _ChromeBar(
                spec: spec,
                brightness: theme.brightness,
              );
            },
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _ChromeBar extends StatelessWidget {
  final ChromeSpec spec;
  final fluent.Brightness brightness;

  const _ChromeBar({required this.spec, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final theme = fluent.FluentTheme.of(context);
    return Container(
      height: 48,
      color: theme.micaBackgroundColor,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => windowManager.startDragging(),
        onDoubleTap: () async {
          final isMax = await windowManager.isMaximized();
          if (isMax) {
            await windowManager.unmaximize();
          } else {
            await windowManager.maximize();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              if (spec.leading != null) spec.leading!,
              const SizedBox(width: 8),
              if (spec.title != null)
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: theme.typography.bodyStrong ??
                        const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: spec.title!,
                  ),
                )
              else
                const Expanded(child: SizedBox.shrink()),
              CaptionButtons(brightness: brightness),
            ],
          ),
        ),
      ),
    );
  }
}

class _RootChromeScope extends InheritedWidget {
  final FluentRootChromeController controller;

  const _RootChromeScope({
    required this.controller,
    required super.child,
  });

  @override
  bool updateShouldNotify(_RootChromeScope oldWidget) =>
      controller != oldWidget.controller;
}
