import 'package:flutter/foundation.dart';

/// Шина «скролл наверх»: повторный тап по активной вкладке нижней панели
/// publishes (tabIndex) — экраны, подписанные на свой индекс, скроллят
/// свой список к началу с анимацией.
class ScrollToTopBus {
  ScrollToTopBus._();

  static final ValueNotifier<int> _bus = ValueNotifier<int>(-1);
  static int _tab = -1;

  /// Отправить сигнал «наверх» для вкладки [tab]. Вызывается шеллом.
  static void fire(int tab) {
    _tab = tab;
    _bus.value = _bus.value + 1;
  }

  /// Подписать экран вкладки [tab] на сигнал. Возвращает функцию отписки —
  /// вызвать в dispose экрана.
  static VoidCallback subscribe(int tab, VoidCallback onScrollToTop) {
    void listener() {
      if (_tab == tab) onScrollToTop();
    }

    _bus.addListener(listener);
    return () => _bus.removeListener(listener);
  }
}
