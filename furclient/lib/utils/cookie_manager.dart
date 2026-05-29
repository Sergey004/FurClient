import 'dart:io' as io;
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show webViewEnvironment;
import '../services/fa_enhanced_client.dart';

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

  /// Синхронизация cookies с Enhanced Client
  static Future<void> syncWithEnhancedClient() async {
    try {
      final enhancedClient = FAEnhancedClient.instance;
      if (enhancedClient.isInitialized) {
        await enhancedClient.syncCookies();
        debugPrint('=== FAICookieManager: Successfully synced with Enhanced Client');
      }
    } catch (e) {
      debugPrint('=== FAICookieManager: Error syncing with Enhanced Client: $e');
    }
  }

  /// Получить cookies для CDN запросов
  static Future<String> getCdnCookieHeader(String url) async {
    final uri = Uri.parse(url);
    final domain = uri.host;
    
    // Используем Enhanced Client для получения cookies
    if (FAEnhancedClient.instance.isInitialized) {
      final sessionData = FAEnhancedClient.instance.sessionData;
      final cookies = <String>[];
      
      for (final entry in sessionData.entries) {
        if (entry.key.startsWith('cookie_')) {
          final cookie = entry.value as String;
          if (cookie.contains(domain)) {
            cookies.add(cookie);
          }
        }
      }
      
      return cookies.join('; ');
    }
    
    // Fallback to standard cookie manager
    final faCookies = await getFACookies();
    return faCookies.values.map((c) => '${c.name}=${c.value}').join('; ');
  }

  /// Кэширование cookies для производительности
  static Future<void> cacheCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookies = await getFACookies();
      final cookieData = {
        for (final cookie in cookies.entries)
          cookie.key: cookie.value.value
      };
      
      await prefs.setString('cached_cookies', jsonEncode(cookieData));
      debugPrint('=== FAICookieManager: Cached ${cookies.length} cookies');
    } catch (e) {
      debugPrint('=== FAICookieManager: Error caching cookies: $e');
    }
  }

  /// Загрузка кэшированных cookies
  static Future<Map<String, String>> loadCachedCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookieData = prefs.getString('cached_cookies');
      if (cookieData != null) {
        final decoded = jsonDecode(cookieData) as Map<String, dynamic>;
        return {
          for (final entry in decoded.entries)
            entry.key: entry.value as String
        };
      }
    } catch (e) {
      debugPrint('=== FAICookieManager: Error loading cached cookies: $e');
    }
    return {};
  }

  /// Очистка кэша cookies
  static Future<void> clearCookieCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_cookies');
      debugPrint('=== FAICookieManager: Cookie cache cleared');
    } catch (e) {
      debugPrint('=== FAICookieManager: Error clearing cookie cache: $e');
    }
  }

  /// Проверка валидности cookies
  static Future<bool> areCookiesValid() async {
    try {
      final sessionValid = await hasSession();
      if (!sessionValid) return false;
      
      // Проверка времени последней синхронизации
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt('last_cookie_sync') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Синхронизировать если старше 5 минут
      if (now - lastSync > 5 * 60 * 1000) {
        await syncWithEnhancedClient();
        await prefs.setInt('last_cookie_sync', now);
      }
      
      return true;
    } catch (e) {
      debugPrint('=== FAICookieManager: Error checking cookie validity: $e');
      return false;
    }
  }

  /// Получение статистики cookies
  static Future<Map<String, dynamic>> getCookieStats() async {
    try {
      final faCookies = await getFACookies();
      final cachedCookies = await loadCachedCookies();
      
      return {
        'active_cookies': faCookies.length,
        'cached_cookies': cachedCookies.length,
        'has_session': await hasSession(),
        'last_sync': (await SharedPreferences.getInstance()).getInt('last_cookie_sync') ?? 0,
      };
    } catch (e) {
      debugPrint('=== FAICookieManager: Error getting cookie stats: $e');
      return {'error': e.toString()};
    }
  }
}
