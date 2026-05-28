import 'dart:io' as io;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../main.dart' show webViewEnvironment;

/// Платформо-адаптивная обёртка над CookieManager.
///
/// Проблема: CookieManager.instance() без webViewEnvironment на Windows
/// читает системный WebView2 профиль, а не наш webview2_data — и возвращает
/// мусорные cookies вместо FA сессии.
///
/// Решение: передаём webViewEnvironment только на Windows.
/// На Android/iOS/macOS — стандартное поведение.
class FAICookieManager {
  FAICookieManager._();

  static CookieManager get instance {
    if (io.Platform.isWindows) {
      return CookieManager.instance(webViewEnvironment: webViewEnvironment);
    }
    return CookieManager.instance();
  }

  /// Получить все cookies для URL с учётом платформы.
  static Future<List<Cookie>> getCookies(String url) async {
    return instance.getCookies(url: WebUri(url));
  }

  /// Получить конкретный cookie по имени.
  static Future<Cookie?> getCookie(String url, String name) async {
    return instance.getCookie(url: WebUri(url), name: name);
  }

  /// Установить cookie.
  static Future<void> setCookie({
    required String url,
    required String name,
    required String value,
    String domain = '.furaffinity.net',
    String path = '/',
    bool isHttpOnly = false,
    bool isSecure = true,
    int? expiresDate,
  }) async {
    await instance.setCookie(
      url: WebUri(url),
      name: name,
      value: value,
      domain: domain,
      path: path,
      isHttpOnly: isHttpOnly,
      isSecure: isSecure,
      expiresDate: expiresDate,
    );
  }

  /// Удалить все cookies.
  static Future<void> deleteAll() async {
    await instance.deleteAllCookies();
  }

  /// Удалить cookies для конкретного домена.
  static Future<void> deleteCookies(String url) async {
    await instance.deleteCookies(
      url: WebUri(url),
      domain: '.furaffinity.net',
    );
  }

  /// Проверить наличие FA сессионного cookie 'a'.
  static Future<bool> hasSession() async {
    final cookie = await getCookie('https://www.furaffinity.net', 'a');
    return cookie != null && cookie.value.isNotEmpty;
  }

  /// Получить все FA cookies (включая cf_clearance, a, b).
  static Future<Map<String, Cookie>> getFACookies() async {
    final cookies = await getCookies('https://www.furaffinity.net');
    return {for (final c in cookies) c.name: c};
  }
}
