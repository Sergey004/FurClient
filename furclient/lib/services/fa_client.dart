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

  // UA согласован с FA staff — как в iOS оригинале (ceylo.FurAffinityApp).
  // Non-browser UA не триггерит CF TLS-fingerprint mismatch.
  static const String _userAgent = 'ceylo.FurAffinityApp/1.0';

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
  }

  // ── Windows: запросы через HeadlessInAppWebView ─────────────────────────
  // WebView2 автоматически шлёт ВСЕ cookies (включая HttpOnly cf_clearance)
  // т.к. использует тот же webview2_data профиль что и login WebView.
  // Аналог iOS setCookies(cookies, for: url) — только WebView2 делает это сам.

  Future<String> _getHtmlViaWebView(String url) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headless;

    headless = HeadlessInAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        userAgent: _userAgent,
      ),
      onLoadStop: (controller, loadedUrl) async {
        try {
          final html = await controller.getHtml() ?? '';
          if (_isCloudflarePage(html)) {
            if (!completer.isCompleted) completer.completeError(CloudflareError());
          } else if (!completer.isCompleted) {
            completer.complete(html);
          }
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
              if (!completer.isCompleted) {
                completer.completeError(CloudflareError());
              }
              await headless?.dispose();
            }
      },
    );

    await headless.run();
    await headless.webViewController?.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
          'Referer': FAUrls.baseUrl,
        },
      ),
    );

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        headless?.dispose();
        throw Exception('Request timeout: $url');
      },
    );
  }

  // ── Android/iOS/macOS: Dio + явный Cookie заголовок ────────────────────

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
        debugPrint('=== Restored ${cookies.length} cookies from session');
      }
    } catch (e) {
      debugPrint('=== Error restoring cookies from session: $e');
    }
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
        body.contains('Just a moment...') ||
        body.contains('challenge-platform') ||
        body.contains('Cloudflare');
  }

  Future<String> _getHtml(String url) async {
    if (io.Platform.isWindows) {
      return _getHtmlViaWebView(url);
    }
    await _ensureInitialized();
    final cookieHeader = _buildCookieHeader();
    final options = cookieHeader != null
        ? Options(headers: {'Cookie': cookieHeader})
        : null;
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
  }

  Future<bool> verifySession() async {
    if (_session?.cookies == null) return false;
    try {
      // На Windows делаем лёгкую проверку через cookies —
      // HeadlessWebView слишком тяжёлый для startup
      if (io.Platform.isWindows) {
        final List<dynamic> raw = jsonDecode(_session!.cookies!);
        final hasCookieA = raw.any((item) {
          if (item is Map<String, dynamic>) return item['name'] == 'a';
          if (item is List && item.length >= 2) return item[0] == 'a';
          return false;
        });
        return hasCookieA;
      }
      // Android/iOS/macOS — проверяем через Dio
      await _ensureInitialized();
      final cookieHeader = _buildCookieHeader();
      final options = cookieHeader != null
          ? Options(headers: {'Cookie': cookieHeader})
          : null;
      final response = await _dio.get<String>(FAUrls.home, options: options);
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

  Future<List<Submission>> getSubmissions(int page, String category) async {
    final html = await _getHtml(FAUrls.browse(filter: category, page: page));
    return Submission.parseSubmissionsPage(html);
  }

  Future<List<Submission>> getGallery(String username, {int page = 1}) async {
    final html = await _getHtml('${FAUrls.gallery(username)}?page=$page');
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
    if (io.Platform.isWindows) {
      await _getHtmlViaWebView(url);
      return !currentlyWatching;
    }
    await _ensureInitialized();
    final cookieHeader = _buildCookieHeader();
    final options = cookieHeader != null
        ? Options(headers: {'Cookie': cookieHeader})
        : null;
    await _dio.post<String>(url, options: options);
    return !currentlyWatching;
  }
}
