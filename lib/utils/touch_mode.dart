import 'dart:ffi' as ffi;

import 'package:flutter/foundation.dart';

import 'platform_utils.dart';

bool? _touchCache;

/// Доступен ли сенсорный ввод («планшетный режим»).
///
/// Windows: `GetSystemMetrics(SM_MAXIMUMTOUCHES)` через user32 (FFI, без
/// новых зависимостей) — > 0, если у устройства есть сенсорный экран.
/// Android/iOS — палец основной ввод; прочие десктопы — мышь.
///
/// От этого флага зависит, показывать ли тач-жесты (pull-to-refresh) —
/// на мышином десктопе они недостижимы, а на планшете это основной
/// способ обновить список (см. AdaptiveRefresh).
///
/// Тест-оверрайд: `--dart-define=FA_FORCE_TOUCH=0|1` принудительно
/// задаёт режим (проверка обоих веток UI на одной машине).
bool get isTouchInput {
  const forceTouch = String.fromEnvironment('FA_FORCE_TOUCH');
  if (forceTouch == '0') return false;
  if (forceTouch == '1') return true;
  if (_touchCache != null) return _touchCache!;
  bool result;
  if (kIsWeb) {
    result = false;
  } else if (isWindows) {
    try {
      final user32 = ffi.DynamicLibrary.open('user32.dll');
      final getSystemMetrics = user32
          .lookupFunction<ffi.Int32 Function(ffi.Int32), int Function(int)>(
              'GetSystemMetrics');
      // SM_MAXIMUMTOUCHES = 68: максимум одновременных касаний;
      // 0 — сенсорного экрана нет.
      result = getSystemMetrics(68) > 0;
    } catch (_) {
      result = false;
    }
  } else if (isDesktop) {
    result = false;
  } else {
    result = true;
  }
  return _touchCache = result;
}
