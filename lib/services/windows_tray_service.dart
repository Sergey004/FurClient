import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart' as wm;

/// Tray-backed background mode for Windows. Closing the window hides it while
/// the existing notification timer keeps running; Exit closes the app window.
class WindowsTrayService {
  WindowsTrayService._();
  static final WindowsTrayService instance = WindowsTrayService._();

  static const preferenceKey = 'windows_background_enabled';

  TrayIcon? _trayIcon;
  Menu? _menu;
  MenuItem? _openItem;
  MenuItem? _exitItem;
  ListenerId? _trayListener;
  ListenerId? _openListener;
  ListenerId? _exitListener;
  wm.Window? _window;
  wm.ListenerId? _windowListener;
  bool _enabled = false;
  bool _exiting = false;

  Future<void> load() async {
    if (!Platform.isWindows) return;
    final prefs = await SharedPreferences.getInstance();
    await setEnabled(prefs.getBool(preferenceKey) ?? true);
  }

  Future<void> setEnabled(bool value) async {
    if (!Platform.isWindows) return;
    if (_enabled == value) return;
    _enabled = value;
    if (value) {
      await _createTray();
    } else {
      final window = _window;
      final listener = _windowListener;
      if (window != null && listener != null) {
        window.removeListener(listener);
      }
      _windowListener = null;
      await _destroyTray();
    }
  }

  Future<void> _createTray() async {
    if (_trayIcon != null || !TrayManager.instance.isSupported()) return;
    final window = wm.WindowManager.instance.getCurrent();
    if (window == null) {
      throw StateError('Windows app window is unavailable.');
    }
    final tray = TrayIcon.createWithIdentifier('furclient');
    if (tray == null) {
      debugPrint('=== Tray: could not create tray icon');
      _enabled = false;
      return;
    }
    _trayIcon = tray;
    tray.icon = ImageAsset.fromAsset('assets/tray_icon.png');
    tray.setTooltip('FurClient — background notifications');
    tray.setContextMenuTrigger(ContextMenuTrigger.rightClicked);
    _trayListener = tray.addListener((event) {
      if (event is TrayIconClickedEvent ||
          event is TrayIconDoubleClickedEvent) {
        unawaited(showWindow());
      }
    });

    final menu = Menu.create();
    final open = MenuItem.createWithLabelAndType(
      'Open FurClient',
      MenuItemType.normal,
    );
    final exit = MenuItem.createWithLabelAndType(
      'Exit',
      MenuItemType.normal,
    );
    if (menu == null || open == null || exit == null) {
      debugPrint('=== Tray: could not create context menu');
      await _destroyTray();
      _enabled = false;
      return;
    }
    _menu = menu;
    _openItem = open;
    _exitItem = exit;
    _openListener = open.addListener((event) {
      if (event is MenuItemClickedEvent) unawaited(showWindow());
    });
    _exitListener = exit.addListener((event) {
      if (event is MenuItemClickedEvent) unawaited(exitApp());
    });
    menu.addItem(open);
    menu.addSeparator();
    menu.addItem(exit);
    tray.setContextMenu(menu);
    if (!tray.setVisible(true)) {
      debugPrint('=== Tray: could not show tray icon');
      await _destroyTray();
      _enabled = false;
      return;
    }

    _window = window;
    _windowListener = window.addListener((event) {
      if (event is wm.WindowCloseRequestedEvent && _enabled && !_exiting) {
        event.request.cancel();
        window.hide();
      }
    });
    debugPrint('=== Tray: background mode enabled');
  }

  Future<void> showWindow() async {
    if (!Platform.isWindows) return;
    final window = _window ?? wm.WindowManager.instance.getCurrent();
    if (window == null) {
      throw StateError('Windows app window is unavailable.');
    }
    window.show();
    window.focus();
  }

  Future<void> closeWindow() async {
    final window = _window ?? wm.WindowManager.instance.getCurrent();
    if (window == null) {
      throw StateError('Windows app window is unavailable.');
    }
    if (_enabled) {
      window.hide();
    } else {
      if (!window.close()) {
        debugPrint('=== Tray: could not close the app window');
      }
    }
  }

  Future<void> exitApp() async {
    if (_exiting) return;
    final window = _window ?? wm.WindowManager.instance.getCurrent();
    if (window == null) {
      throw StateError('Windows app window is unavailable.');
    }
    _exiting = true;
    final listener = _windowListener;
    if (listener != null) {
      window.removeListener(listener);
    }
    _windowListener = null;
    await _destroyTray();
    if (!window.close()) {
      debugPrint('=== Tray: could not close the app window on exit');
    }
  }

  Future<void> _destroyTray() async {
    final tray = _trayIcon;
    if (tray != null) {
      if (_trayListener != null) tray.removeListener(_trayListener!);
      await tray.setVisible(false);
    }
    if (_openItem != null && _openListener != null) {
      _openItem!.removeListener(_openListener!);
    }
    if (_exitItem != null && _exitListener != null) {
      _exitItem!.removeListener(_exitListener!);
    }
    _openItem?.dispose();
    _exitItem?.dispose();
    _menu?.dispose();
    tray?.dispose();
    _trayIcon = null;
    _menu = null;
    _openItem = null;
    _exitItem = null;
    _trayListener = null;
    _openListener = null;
    _exitListener = null;
  }
}
