import 'package:material_ui/material_ui.dart';

import '../../utils/touch_mode.dart';

/// Pull-to-refresh — тач-жест.
///
/// Показывается только на устройствах с сенсорным вводом (мобилки и
/// Windows-планшеты). На мышином десктопе жест недостижим — отдаём
/// ребёнка как есть; вместо жеста там в шапках страниц появляются
/// кнопки обновления (см. AdaptiveScaffold).
class AdaptiveRefresh extends StatelessWidget {
  final RefreshCallback onRefresh;
  final Widget child;

  const AdaptiveRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isTouchInput) return child;
    return RefreshIndicator(onRefresh: onRefresh, child: child);
  }
}
