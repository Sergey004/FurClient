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

  // ── Cookie storage ───────────────────────────────────────────────
  static final Map<String, CookieEntry> _cookies = {};
  static const List<String> _essentialCookies = ['a', 'b', 'cf_clearance'];

  static CookieManager get instance {
    if (io.Platform.isWindows) {
      if (webViewEnvironment == null) {
        debugPrint(
            '=== FAICookieManager WARNING: webViewEnvironment is null on Windows!');
      }
      final cm = CookieManager.instance(webViewEnvironment: webViewEnvironment);
      debugPrint(
          '=== FAICookieManager: Created CookieManager for Windows with webViewEnvironment: ${webViewEnvironment != null}');
      return cm;
    }
    debugPrint(
        '=== FAICookieManager: Created CookieManager for non-Windows platform');
    return CookieManager.instance();
  }

  // ── CDNLoader compatibility methods ──────────────────────────────

  /// Load cookies from persistent storage (for CDNLoader)
  static Future<void> loadCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookieData = prefs.getString('unified_cookies');
      if (cookieData != null) {
        final decoded = jsonDecode(cookieData) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          final data = entry.value as Map<String, dynamic>;
          _cookies[entry.key] = CookieEntry(
            name: data['name'] as String,
            value: data['value'] as String,
            domain: data['domain'] as String? ?? '.furaffinity.net',
            path: data['path'] as String? ?? '/',
            expiresDate: data['expiresDate'] as int?,
            isHttpOnly: data['isHttpOnly'] as bool? ?? false,
            isSecure: data['isSecure'] as bool? ?? true,
          );
        }
        debugPrint(
            '=== FAICookieManager: Loaded ${_cookies.length} cookies from storage');
      }
    } catch (e) {
      debugPrint('=== FAICookieManager: Error loading cookies: $e');
    }
  }

  /// Save cookies to persistent storage
  static Future<void> _saveCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        for (final entry in _cookies.entries)
          entry.key: {
            'name': entry.value.name,
            'value': entry.value.value,
            'domain': entry.value.domain,
            'path': entry.value.path,
            'expiresDate': entry.value.expiresDate,
            'isHttpOnly': entry.value.isHttpOnly,
            'isSecure': entry.value.isSecure,
          }
      };
      await prefs.setString('unified_cookies', jsonEncode(data));
    } catch (e) {
      debugPrint('=== FAICookieManager: Error saving cookies: $e');
    }
  }

  /// Get cookies for URL (for CDNLoader)
  static Future<List<CookieEntry>> getCookiesForUrl(String url) async {
    final uri = Uri.parse(url);
    final domain = uri.host;

    return _cookies.values.where((cookie) {
      final cookieDomain = cookie.domain;

      if (domain == cookieDomain ||
          domain.endsWith(cookieDomain.replaceFirst('.', ''))) {
        if (cookie.expiresDate != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (cookie.expiresDate! < now) return false;
        }
        return true;
      }

      return false;
    }).toList();
  }

  /// Parse Set-Cookie header and store cookies (for CDNLoader)
  static void parseAndStoreCookies(String setCookieHeader, String domain) {
    final cookieStrings = setCookieHeader.split(',');
    for (final cookieStr in cookieStrings) {
      final parts = cookieStr.trim().split(';');
      if (parts.isEmpty) continue;

      final nameValue = parts[0].trim().split('=');
      if (nameValue.length < 2) continue;

      final name = nameValue[0].trim();
      final value = nameValue.sublist(1).join('=').trim();

      if (name.isEmpty || value.isEmpty) continue;

      String cookieDomain = domain;
      String path = '/';
      int? expiresDate;
      bool isHttpOnly = false;
      bool isSecure = false;

      for (int i = 1; i < parts.length; i++) {
        final attr = parts[i].trim().toLowerCase();
        if (attr.startsWith('domain=')) {
          cookieDomain = attr.substring(7).trim();
        } else if (attr.startsWith('path=')) {
          path = attr.substring(5).trim();
        } else if (attr.startsWith('expires=')) {
          try {
            final date = io.HttpDate.parse(attr.substring(8).trim());
            expiresDate = date.millisecondsSinceEpoch;
          } catch (_) {}
        } else if (attr == 'httponly') {
          isHttpOnly = true;
        } else if (attr == 'secure') {
          isSecure = true;
        }
      }

      _cookies[name] = CookieEntry(
        name: name,
        value: value,
        domain: cookieDomain,
        path: path,
        expiresDate: expiresDate,
        isHttpOnly: isHttpOnly,
        isSecure: isSecure,
      );

      debugPrint('=== FAICookieManager: Stored cookie: $name');
    }

    _saveCookies();
  }

  /// Sync cookies from WebView (for CDNLoader)
  static Future<void> syncFromWebView(InAppWebViewController controller) async {
    try {
      final webViewManager = instance;
      debugPrint('=== FAICookieManager: Starting WebView sync');

      final cookies = await webViewManager.getCookies(
        url: WebUri('https://www.furaffinity.net'),
      );

      debugPrint(
          '=== FAICookieManager: Got ${cookies.length} cookies from WebViewManager');
      for (final cookie in cookies) {
        debugPrint(
            '=== FAICookieManager:   - ${cookie.name} (domain: ${cookie.domain}, path: ${cookie.path}, httpOnly: ${cookie.isHttpOnly}, secure: ${cookie.isSecure}, expires: ${cookie.expiresDate})');

        // expiresDate from flutter_inappwebview is int?
        final expiresDate = cookie.expiresDate;

        _cookies[cookie.name] = CookieEntry(
          name: cookie.name,
          value: cookie.value ?? '',
          domain: cookie.domain ?? '.furaffinity.net',
          path: cookie.path ?? '/',
          expiresDate: expiresDate,
          isHttpOnly: cookie.isHttpOnly ?? false,
          isSecure: cookie.isSecure ?? true,
        );
      }

      _saveCookies();
      debugPrint(
          '=== FAICookieManager: Synced ${cookies.length} cookies to internal storage, total ${_cookies.length} cookies');
    } catch (e) {
      debugPrint('=== FAICookieManager: WebView sync failed: $e');
    }
  }

  /// Sync cookies to WebView (for CDNLoader)
  static Future<void> syncToWebView(
      InAppWebViewController controller, String url) async {
    try {
      final webViewManager = instance;
      final cookies = await getCookiesForUrl(url);

      for (final cookie in cookies) {
        await webViewManager.setCookie(
          url: WebUri(url),
          name: cookie.name,
          value: cookie.value,
          domain: cookie.domain,
          path: cookie.path,
          isHttpOnly: cookie.isHttpOnly,
          isSecure: cookie.isSecure,
          expiresDate: cookie.expiresDate,
        );
      }

      debugPrint(
          '=== FAICookieManager: Synced ${cookies.length} cookies to WebView');
    } catch (e) {
      debugPrint('=== FAICookieManager: Sync to WebView failed: $e');
    }
  }

  /// Validate cookies (for CDNLoader)
  static CookieValidationResult validate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expiredEssential = <String>[];
    final expiredOptional = <String>[];

    for (final cookie in _cookies.values) {
      if (cookie.expiresDate != null && cookie.expiresDate! < now) {
        if (_essentialCookies.contains(cookie.name)) {
          expiredEssential.add(cookie.name);
        } else {
          expiredOptional.add(cookie.name);
        }
      }
    }

    return CookieValidationResult(
      isValid: expiredEssential.isEmpty,
      expiredEssential: expiredEssential,
      expiredOptional: expiredOptional,
      totalCookies: _cookies.length,
    );
  }

  /// Remove expired optional cookies (for CDNLoader)
  static void cleanExpiredOptionalCookies() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final toRemove = <String>[];

    for (final entry in _cookies.entries) {
      if (entry.value.expiresDate != null &&
          entry.value.expiresDate! < now &&
          !_essentialCookies.contains(entry.key)) {
        toRemove.add(entry.key);
      }
    }

    for (final key in toRemove) {
      _cookies.remove(key);
      debugPrint('=== FAICookieManager: Removed expired optional cookie: $key');
    }

    if (toRemove.isNotEmpty) {
      _saveCookies();
    }
  }

  /// Get cookie count
  static int get cookieCount => _cookies.length;

  /// Get all cookie names
  static List<String> get cookieNames => _cookies.keys.toList();

  /// Получить все cookies для URL с учётом платформы.
  static Future<List<Cookie>> getCookies(String url) async {
    return instance.getCookies(url: WebUri(url));
  }

  /// Получить все cookies из WebView для известных FA URL.
  static Future<List<Cookie>> getAllCookies() async {
    final urls = [
      'https://www.furaffinity.net',
      'https://furaffinity.net',
      'https://www.furaffinity.net/login',
      'https://www.furaffinity.net/',
    ];

    final cookiesByName = <String, Cookie>{};
    for (final url in urls) {
      try {
        final cookies = await getCookies(url);
        for (final cookie in cookies) {
          cookiesByName[cookie.name] = cookie;
        }
      } catch (e) {
        debugPrint('=== FAICookieManager: Error fetching cookies for $url: $e');
      }
    }

    final allCookies = cookiesByName.values.toList();
    debugPrint(
        '=== FAICookieManager: Collected ${allCookies.length} cookies from WebView: ${allCookies.map((c) => c.name).join(", ")}');
    return allCookies;
  }

  /// Получить конкретный cookie по имени.
  static Future<Cookie?> getCookie(String url, String name) async {
    debugPrint('=== FAICookieManager: Getting cookie $name from $url');
    final cookie = await instance.getCookie(url: WebUri(url), name: name);
    if (cookie != null) {
      final valueLength = cookie.value?.length ?? 0;
      final previewLength = valueLength < 10 ? valueLength : 10;
      debugPrint(
          '=== FAICookieManager: Got cookie: $name | httpOnly=${cookie.isHttpOnly} | value=${cookie.value?.substring(0, previewLength)}...');
    } else {
      debugPrint('=== FAICookieManager: Cookie $name not found');
    }
    return cookie;
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
    debugPrint('=== FAICookieManager: Getting all cookies from WebViewManager');
    debugPrint(
        '=== FAICookieManager: Current time: ${DateTime.now().toIso8601String()}');

    final cookies = await getAllCookies();
    debugPrint(
        '=== FAICookieManager: Got ${cookies.length} cookies total: ${cookies.map((c) => c.name).join(", ")}');
    for (final cookie in cookies) {
      debugPrint(
          '=== FAICookieManager:   - ${cookie.name} (domain: ${cookie.domain}, path: ${cookie.path}, httpOnly: ${cookie.isHttpOnly}, secure: ${cookie.isSecure}, expires: ${cookie.expiresDate})');
    }
    return {for (final c in cookies) c.name: c};
  }

  /// Синхронизация cookies с Enhanced Client
  static Future<void> syncWithEnhancedClient() async {
    try {
      final enhancedClient = FAEnhancedClient.instance;
      if (enhancedClient.isInitialized) {
        await enhancedClient.syncCookies();
        debugPrint(
            '=== FAICookieManager: Successfully synced with Enhanced Client');
      }
    } catch (e) {
      debugPrint(
          '=== FAICookieManager: Error syncing with Enhanced Client: $e');
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
        for (final cookie in cookies.entries) cookie.key: cookie.value.value
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
          for (final entry in decoded.entries) entry.key: entry.value as String
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
        'last_sync': (await SharedPreferences.getInstance())
                .getInt('last_cookie_sync') ??
            0,
      };
    } catch (e) {
      debugPrint('=== FAICookieManager: Error getting cookie stats: $e');
      return {'error': e.toString()};
    }
  }
}

/// Cookie entry for internal storage
class CookieEntry {
  final String name;
  final String value;
  final String domain;
  final String path;
  final int? expiresDate;
  final bool isHttpOnly;
  final bool isSecure;

  CookieEntry({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    this.expiresDate,
    required this.isHttpOnly,
    required this.isSecure,
  });
}

/// Cookie validation result
class CookieValidationResult {
  final bool isValid;
  final List<String> expiredEssential;
  final List<String> expiredOptional;
  final int totalCookies;

  CookieValidationResult({
    required this.isValid,
    required this.expiredEssential,
    required this.expiredOptional,
    required this.totalCookies,
  });

  @override
  String toString() {
    return 'CookieValidationResult(isValid=$isValid, '
        'expiredEssential=$expiredEssential, '
        'expiredOptional=$expiredOptional, '
        'totalCookies=$totalCookies)';
  }
}
