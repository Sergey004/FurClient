import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Обёртка над haptic_feedback.
///
/// На Android/iOS используются нативные haptic-примитивы.
/// На остальных платформах — no-op.
///
/// Учитывает пользовательскую настройку [enabled] (ключ
/// `haptics_enabled`, default ON): некоторым людям вибро не нравится
/// или противопоказано.
class FHaptics {
  FHaptics._();

  static const String _prefKey = 'haptics_enabled';

  /// Живое состояние — читается из prefs на старте ([load]),
  /// переключается из Settings ([setEnabled]).
  static bool enabled = true;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_prefKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  /// Тап по вкладке — лёгкий клик.
  static void selection() {
    if (!enabled) return;
    _mobile(() => Haptics.vibrate(HapticsType.selection));
  }

  /// Срабатывание pull-to-refresh — едва заметный тик.
  static void light() {
    if (!enabled) return;
    _mobile(() => Haptics.vibrate(HapticsType.light));
  }

  /// Успешное действие (fave подтверждён сервером) — заметный «щелчок».
  static void success() {
    if (!enabled) return;
    _mobile(() => Haptics.vibrate(HapticsType.success));
  }

  /// Тяжёлый отклик (зарезервировано: удаление и пр.).
  static void heavy() {
    if (!enabled) return;
    _mobile(() => Haptics.vibrate(HapticsType.heavy));
  }

  static void _mobile(Future<void> Function() fn) {
    if (kIsWeb) return;

    if (io.Platform.isAndroid || io.Platform.isIOS) {
      fn();
    }
  }
}
