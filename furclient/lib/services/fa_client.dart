import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart' as dio_cookies;
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../utils/cookie_manager.dart';
import '../utils/cookie_store.dart';
import '../utils/cloudflare_bypass/cloudflare_bypass.dart';
import '../utils/cloudflare_bypass/storage.dart';
import 'fa_urls.dart';
import '../main.dart' show webViewEnvironment;

class CloudflareError implements Exception {
  final String message;
  CloudflareError([String? customMessage])
      : message = customMessage ??
            'Cloudflare protection is active. Please re-login to pass the challenge.';

  @override
  String toString() => message;
}

class FAClient {
  UserSession? _session;
  late final Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  bool _cfPassInProgress = false;
  DateTime? _lastCfPass;
  static Duration _cfPassCooldown = const Duration(minutes: 5);

  static const String _userAgent = 'ceylo.FurAffinityApp/1.0';

  static const _cfCookieUrls = [
    'https://www.furaffinity.net',
    'https://furaffinity.net',
    'https://www.furaffinity.net/',
  ];

  FAClient() {
    _dio = Dio(BaseOptions(
      headers: {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Referer': FAUrls.baseUrl,
      },
      validateStatus: (status) => status != null && status < 600,
      followRedirects: true,
      maxRedirects: 5,
    ));
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();
    try {
      final appDocDir = io.Directory.systemTemp.path != ''
          ? await getApplicationSupportDirectory()
          : null;
      final cookiePath = '${appDocDir?.path ?? '/tmp'}/.cookies';
      final cookieDir = io.Directory(cookiePath);
      if (!cookieDir.existsSync()) {
        cookieDir.createSync(recursive: true);
      }
      _cookieJar = PersistCookieJar(storage: FileStorage(cookiePath));
      _dio.interceptors.add(dio_cookies.CookieManager(_cookieJar));
      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> init() async => _ensureInitialized();

  UserSession? get session => _session;

  Future<void> setSession(UserSession? session) async {
    _session = session;
    if (!io.Platform.isWindows) {
      await _restoreCookiesFromSession();
    }
    await passCloudflareChallenge();
  }

  // ── CF Challenge Pass ────────────────────────────────────────────────
  // HeadlessInAppWebView загружает FA homepage.
  // Если CF показывает челлендж — WebView решает его автоматически (JS).
  // После этого cf_clearance появляется в WebView cookie store.
  // Мы извлекаем его и обновляем в CookieJar и сессии.

  Future<bool> passCloudflareChallenge() async {
    if (_cfPassInProgress) return false;
    if (_lastCfPass != null &&
        DateTime.now().difference(_lastCfPass!) < _cfPassCooldown) {
      return true;
    }

    _cfPassInProgress = true;
    try {
      debugPrint('=== CF pass: using cloudflare_bypass...');
      
      // Используем наш новый обходчик
      final result = await cloudflareBypass(
        url: FAUrls.home,
        id: 'cf_clearance_${DateTime.now().millisecondsSinceEpoch}',
        method: 'GET',
      );
      
      if (result == null || result['html'] == null) {
        debugPrint('=== CF pass: bypass failed, no result returned');
        return false;
      }
      
      debugPrint('=== CF pass: bypass completed, HTML length: ${(result['html'] as String?)?.length ?? 0}');
      debugPrint('=== CF pass: cf_clearance found: ${result['cf_clearance_found']}');
      
      // Синхронизируем cookies после обхода
      await _syncCookiesFromWebView();
      
      // Добавляем cf_clearance в сессию
      await addCfClearanceToSession();
      
      _lastCfPass = DateTime.now();
      debugPrint('=== CF pass: completed successfully');
      return true;
    } catch (e) {
      debugPrint('=== CF pass error: $e');
      return false;
    } finally {
      _cfPassInProgress = false;
    }
  }

  /// Принудительный обход Cloudflare challenge с расширенным временем
  Future<bool> forceCloudflarePass() async {
    debugPrint('=== CF force: starting forced bypass...');
    
    // Сбрасываем кулдаун
    _lastCfPass = null;
    _cfPassInProgress = false;
    
    // Временно увеличиваем время ожидания
    final originalCooldown = _cfPassCooldown;
    _cfPassCooldown = const Duration(minutes: 1);
    
    try {
      return await passCloudflareChallenge();
    } finally {
      // Восстанавливаем оригинальный кулдаун
      _cfPassCooldown = originalCooldown;
    }
  }

  /// Проверить наличие cf_clearance cookie
  Future<bool> hasCfClearance() async {
    final cookieMain = CookieMain();
    final cfClearanceData = await cookieMain.getData('cf_clearance_${DateTime.now().millisecondsSinceEpoch}');
    return cfClearanceData != null;
  }

  /// Добавить cf_clearance cookie в сессию
  Future<void> addCfClearanceToSession() async {
    try {
      final cookieMain = CookieMain();
      final cfClearanceData = await cookieMain.getData('cf_clearance_${DateTime.now().millisecondsSinceEpoch}');
      
      if (cfClearanceData != null && _session?.cookies != null) {
        debugPrint('=== Adding cf_clearance to session...');
        
        // Декодируем текущие cookies из сессии
        final List<dynamic> raw = jsonDecode(_session!.cookies!);
        final sessionCookies = <String, Map<String, dynamic>>{};
        
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            final name = item['name']?.toString() ?? '';
            if (name.isNotEmpty) sessionCookies[name] = item;
          }
        }
        
        // Декодируем cf_clearance cookie
        final cfClearanceMap = jsonDecode(cfClearanceData) as Map<String, dynamic>;
        
        // Добавляем в сессию
        sessionCookies['cf_clearance'] = {
          'name': 'cf_clearance',
          'value': cfClearanceMap['value'],
          'domain': cfClearanceMap['domain'] ?? '.furaffinity.net',
          'path': cfClearanceMap['path'] ?? '/',
          'isHttpOnly': cfClearanceMap['isHttpOnly'] ?? false,
          'isSecure': cfClearanceMap['isSecure'] ?? true,
          'expiresDate': cfClearanceMap['expires'],
        };
        
        // Обновляем сессию
        _session = UserSession(
          username: _session!.username,
          avatarUrl: _session!.avatarUrl,
          isLoggedIn: _session!.isLoggedIn,
          cookies: jsonEncode(sessionCookies.values.toList()),
        );
        
        debugPrint('=== Session updated with cf_clearance');
        
        // Сохраняем сессию
        // await _authService.saveSession(_session!); // TODO: Implement this
      }
    } catch (e) {
      debugPrint('=== Error adding cf_clearance to session: $e');
    }
  }

  Future<void> _syncCookiesFromWebView() async {
    final seen = <String>{};
    final allCookies = <Cookie>[];

    for (final url in _cfCookieUrls) {
      try {
        final cookies = await FAICookieManager.getCookies(url);
        for (final c in cookies) {
          if (seen.add(c.name)) {
            allCookies.add(c);
          }
        }
      } catch (e) {
        debugPrint('=== CF sync: error reading cookies from $url: $e');
      }
    }

    debugPrint(
      '=== CF sync: found ${allCookies.length} cookies (${allCookies.map((c) => c.name).join(", ")})',
    );

    final hasCfClearance = allCookies.any((c) => c.name == 'cf_clearance');
    if (hasCfClearance) {
      debugPrint('=== CF sync: cf_clearance found!');
    }

    await _saveWebViewCookiesToSession(allCookies);
    await _saveWebViewCookiesToCookieJar(allCookies);

    final ioCookies = allCookies
        .where((c) => (c.value as String? ?? '').isNotEmpty)
        .map((c) {
          final cookie = io.Cookie(c.name, c.value as String? ?? '');
          cookie.domain = c.domain ?? '.furaffinity.net';
          cookie.path = c.path ?? '/';
          cookie.secure = c.isSecure ?? true;
          return cookie;
        })
        .toList();
      if (ioCookies.isNotEmpty) {
        debugPrint('=== Syncing ${ioCookies.length} cookies to CookieStore from WebView');
        for (final cookie in ioCookies) {
          debugPrint('  - ${cookie.name}: ${cookie.value} (domain: ${cookie.domain})');
        }
        CookieStore.instance.setCookies(ioCookies);
        debugPrint('=== CookieStore now has: ${CookieStore.instance.cookieHeader}');
      } else {
        debugPrint('=== No cookies synced from WebView');
      }
  }

  Future<void> _saveWebViewCookiesToSession(List<Cookie> webViewCookies) async {
    if (_session?.cookies == null) return;
    try {
      final List<dynamic> raw = jsonDecode(_session!.cookies!);
      final sessionCookies = <String, Map<String, dynamic>>{};
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final name = item['name']?.toString() ?? '';
          if (name.isNotEmpty) sessionCookies[name] = item;
        }
      }

      for (final c in webViewCookies) {
        final value = c.value as String? ?? '';
        if (value.isEmpty) continue;
        final expiresDate = c.expiresDate is int ? c.expiresDate as int : 0;
        sessionCookies[c.name] = {
          'name': c.name,
          'value': value,
          'domain': c.domain ?? '.furaffinity.net',
          'path': c.path ?? '/',
          'isHttpOnly': c.isHttpOnly ?? false,
          'isSecure': c.isSecure ?? true,
          'expiresDate': expiresDate,
        };
      }

      _session = UserSession(
        username: _session!.username,
        avatarUrl: _session!.avatarUrl,
        isLoggedIn: _session!.isLoggedIn,
        cookies: jsonEncode(sessionCookies.values.toList()),
      );
      debugPrint('=== Session updated with ${sessionCookies.length} cookies');
    } catch (e) {
      debugPrint('=== Error saving WebView cookies to session: $e');
    }
  }

  Future<void> _saveWebViewCookiesToCookieJar(List<Cookie> webViewCookies) async {
    if (!io.Platform.isWindows) {
      await _ensureInitialized();
    }
    final cookies = <io.Cookie>[];
    for (final c in webViewCookies) {
      final value = c.value as String? ?? '';
      if (value.isEmpty) continue;
      final cookie = io.Cookie(c.name, value);
      cookie.domain = c.domain ?? '.furaffinity.net';
      cookie.path = c.path ?? '/';
      cookie.secure = c.isSecure ?? true;
      cookies.add(cookie);
    }
    if (cookies.isNotEmpty && !io.Platform.isWindows) {
      await _cookieJar.saveFromResponse(Uri.parse(FAUrls.baseUrl), cookies);
      debugPrint('=== CookieJar updated with ${cookies.length} cookies');
    }
  }

  // ── Cookie Header Builders ────────────────────────────────────────────

  Future<String?> _buildCookieHeaderFromWebView() async {
    try {
      final seen = <String>{};
      final parts = <String>[];
      for (final url in _cfCookieUrls) {
        final cookies = await FAICookieManager.getCookies(url);
        for (final c in cookies) {
          if (seen.add(c.name)) {
            parts.add('${c.name}=${c.value}');
          }
        }
      }
      if (parts.isEmpty) return null;
      debugPrint('=== Live cookies for request: ${seen.join(", ")}');
      return parts.join('; ');
    } catch (e) {
      debugPrint('=== Error reading live cookies: $e');
      return null;
    }
  }

  String? _buildCookieHeader() {
    if (_session?.cookies == null) return null;
    try {
      final List<dynamic> raw = jsonDecode(_session!.cookies!);
      final parts = <String>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final name = item['name']?.toString() ?? '';
          final value = item['value']?.toString() ?? '';
          if (name.isNotEmpty && value.isNotEmpty) parts.add('$name=$value');
        } else if (item is List && item.length >= 2) {
          final name = item[0].toString();
          final value = item[1].toString();
          if (name.isNotEmpty && value.isNotEmpty) parts.add('$name=$value');
        }
      }
      return parts.isEmpty ? null : parts.join('; ');
    } catch (e) {
      debugPrint('=== Error building cookie header: $e');
      return null;
    }
  }

  Future<void> _restoreCookiesFromSession() async {
    if (_session?.cookies == null) return;
    await _ensureInitialized();
    try {
      final List<dynamic> raw = jsonDecode(_session!.cookies!);
      final cookies = <io.Cookie>[];
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final name = item['name']?.toString() ?? '';
          final value = item['value']?.toString() ?? '';
          final domain = item['domain']?.toString() ?? '.furaffinity.net';
          final path = item['path']?.toString() ?? '/';
          final isSecure = item['isSecure'] as bool? ?? true;
          if (name.isNotEmpty && value.isNotEmpty) {
            final c = io.Cookie(name, value);
            c.domain = domain;
            c.path = path;
            c.secure = isSecure;
            cookies.add(c);
          }
        } else if (item is List && item.length >= 2) {
          final name = item[0].toString();
          final value = item[1].toString();
          if (name.isNotEmpty && value.isNotEmpty) {
            final c = io.Cookie(name, value);
            c.domain = '.furaffinity.net';
            c.path = '/';
            c.secure = true;
            cookies.add(c);
          }
        }
      }
      if (cookies.isNotEmpty) {
        await _cookieJar.saveFromResponse(Uri.parse(FAUrls.baseUrl), cookies);
        debugPrint('=== Restoring ${cookies.length} cookies from session to CookieStore');
        for (final cookie in cookies) {
          debugPrint('  - ${cookie.name}: ${cookie.value}');
        }
        CookieStore.instance.setCookies(cookies);
        debugPrint('=== CookieStore after restore: ${CookieStore.instance.cookieHeader}');
        debugPrint('=== Restored ${cookies.length} cookies from session');
      }
    } catch (e) {
      debugPrint('=== Error restoring cookies from session: $e');
    }
  }

  // ── CF Detection ─────────────────────────────────────────────────────

  void _checkCloudflare(Response response) {
    final cfMitigated = response.headers.value('cf-mitigated');
    if (cfMitigated == 'challenge') throw CloudflareError();
    final status = response.statusCode ?? 0;
    if (status == 403 || status == 503) {
      final body = response.data?.toString() ?? '';
      if (_isCloudflarePage(body)) throw CloudflareError();
    }
  }

  static bool _isCloudflarePage(String body) {
    return body.contains('DDoS protection by') ||
        body.contains('/cdn-cgi/styles/challenges.css') ||
        body.contains('/cdn-cgi/challenge-platform') ||
        body.contains('cf-browser-verification') ||
        body.contains('cf_chl_opt') ||
        body.contains('cf-challenge-running') ||
        body.contains('Just a moment...');
  }

  // ── HTML Fetching ─────────────────────────────────────────────────────
  // 1. Пытаемся Dio с cookies (быстро, нативно)
  // 2. Если CF-ошибка — пробуем пройти CF через HeadlessWebView
  // 3. Если после CF pass Dio всё равно не работает — фоллбэк на HeadlessWebView

  Future<String> _getHtml(String url) async {
    await _ensureInitialized();

    final cookieHeader = io.Platform.isWindows
        ? (await _buildCookieHeaderFromWebView() ?? _buildCookieHeader())
        : _buildCookieHeader();

    final options = cookieHeader != null
        ? Options(headers: {'Cookie': cookieHeader})
        : null;

    try {
      final response = await _dio.get<String>(url, options: options);
      _checkCloudflare(response);
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'HTTP ${response.statusCode}',
        );
      }
      return response.data ?? '';
    } on CloudflareError {
      debugPrint('=== CF detected on Dio request, attempting CF pass...');
      final passed = await passCloudflareChallenge();
      if (passed) {
        try {
          final retryHeader = io.Platform.isWindows
              ? (await _buildCookieHeaderFromWebView() ?? _buildCookieHeader())
              : _buildCookieHeader();
          final retryOptions = retryHeader != null
              ? Options(headers: {'Cookie': retryHeader})
              : null;
          final retryResponse =
              await _dio.get<String>(url, options: retryOptions);
          _checkCloudflare(retryResponse);
          if (retryResponse.statusCode != null &&
              retryResponse.statusCode! >= 200 &&
              retryResponse.statusCode! < 300) {
            return retryResponse.data ?? '';
          }
        } catch (e) {
          debugPrint('=== Dio retry after CF pass failed: $e');
        }
      }

      debugPrint('=== Falling back to HeadlessWebView for: $url');
      return _getHtmlViaWebView(url);
    }
  }

  Future<String> _getHtmlViaWebView(String url) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headless;

    headless = HeadlessInAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        thirdPartyCookiesEnabled: true,
      ),
      onLoadStop: (controller, loadedUrl) async {
        try {
          final html = await controller.getHtml() ?? '';
          if (_isCloudflarePage(html)) {
            debugPrint('=== WebView: CF challenge page, waiting...');
            return;
          }
          if (!completer.isCompleted) completer.complete(html);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        } finally {
          await headless?.dispose();
        }
      },
      onReceivedError: (controller, request, error) async {
        if (!(request.isForMainFrame ?? false)) return;
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('WebView error: ${error.description}'),
          );
        }
        await headless?.dispose();
      },
      onReceivedHttpError: (controller, request, response) async {
        if (!(request.isForMainFrame ?? false)) return;
        final status = response.statusCode ?? 0;
        if (status == 403 || status == 503) {
          debugPrint('=== WebView: HTTP $status — CF challenge in progress');
        }
      },
    );

    await headless.run();
    await headless.webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );

    return completer.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        headless?.dispose();
        throw Exception('Request timeout: $url');
      },
    );
  }

  // ── Session Verification ─────────────────────────────────────────────

  Future<bool> verifySession() async {
    if (_session?.cookies == null) return false;
    try {
      if (io.Platform.isWindows) {
        final List<dynamic> raw = jsonDecode(_session!.cookies!);
        final hasCookieA = raw.any((item) {
          if (item is Map<String, dynamic>) return item['name'] == 'a';
          if (item is List && item.length >= 2) return item[0] == 'a';
          return false;
        });
        return hasCookieA;
      }
      await _ensureInitialized();
      final cookieHeader = _buildCookieHeader();
      final options = cookieHeader != null
          ? Options(headers: {'Cookie': cookieHeader})
          : null;
      final response =
          await _dio.get<String>(FAUrls.home, options: options);
      try {
        _checkCloudflare(response);
      } on CloudflareError {
        return false;
      }
      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) return false;
      return status >= 200 && status < 300;
    } catch (e) {
      debugPrint('verifySession error: $e');
      return false;
    }
  }

  Future<void> clearCookies() async {
    if (_initialized) await _cookieJar.deleteAll();
  }

  Future<void> handleCloudflareBreach() async {
    debugPrint('=== Cloudflare breach detected — clearing all cookies');
    await _clearAllCookies();
  }

  Future<void> _clearAllCookies() async {
    if (_initialized) {
      try {
        await _cookieJar.deleteAll();
        debugPrint('=== Cleared all cookies from CookieJar');
      } catch (e) {
        debugPrint('=== Error clearing cookies: $e');
      }
    }
    try {
      if (!io.Platform.isWindows) {
        await CookieManager.instance().deleteAllCookies();
        debugPrint('=== Cleared all WebView cookies');
      }
    } catch (e) {
      debugPrint('=== Error clearing WebView cookies: $e');
    }
  }

  // ── Image Headers ────────────────────────────────────────────────────

  Map<String, String> getImageHeaders() {
    final cookie = _buildCookieHeader();
    return {
      if (cookie != null) 'Cookie': cookie,
      'User-Agent': _userAgent,
      'Referer': FAUrls.baseUrl,
    };
  }

  // ── Data Access Methods ──────────────────────────────────────────────

  Future<List<Submission>> getSubmissions(int page, String category) async {
    final html = await _getHtml(FAUrls.browse(filter: category, page: page));
    return Submission.parseSubmissionsPage(html);
  }

  Future<List<Submission>> getGallery(String username, {int page = 1}) async {
    final html =
        await _getHtml('${FAUrls.gallery(username)}?page=$page');
    return Submission.parseSubmissionsPage(html);
  }

  Future<Submission?> getSubmission(String id) async {
    final html = await _getHtml(FAUrls.viewSubmission(id));
    return Submission.parseSubmissionDetails(html, id);
  }

  Future<List<FAComment>> getComments(String id) async {
    final html = await _getHtml(FAUrls.viewSubmission(id));
    return FAComment.parseComments(html);
  }

  Future<List<Submission>> search(String query, {int page = 1}) async {
    final html = await _getHtml(FAUrls.search(query, page: page));
    return Submission.parseSearchResults(html);
  }

  Future<List<FANotification>> getNotifications() async {
    final html = await _getHtml(FAUrls.notifications);
    return FANotification.parseNotifications(html);
  }

  Future<FAUser?> getUser(String username) async {
    final html = await _getHtml(FAUrls.user(username));
    return FAUser.parseUserPage(html, username);
  }

  Future<FAUser?> getUserProfile(String username) async {
    if (username == 'me') {
      if (_session?.username != null && _session!.username != 'user') {
        return getUser(_session!.username);
      }
      return null;
    }
    return getUser(username);
  }

  Future<bool> toggleWatch(String username, bool currentlyWatching) async {
    final action = currentlyWatching ? 'unwatch' : 'watch';
    final url = '${FAUrls.baseUrl}/$action/$username/';
    await _ensureInitialized();
    final cookieHeader = io.Platform.isWindows
        ? (await _buildCookieHeaderFromWebView() ?? _buildCookieHeader())
        : _buildCookieHeader();
    final options = cookieHeader != null
        ? Options(headers: {'Cookie': cookieHeader})
        : null;
    await _dio.post<String>(url, options: options);
    return !currentlyWatching;
  }
}
