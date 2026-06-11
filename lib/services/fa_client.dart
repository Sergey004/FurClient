import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart' as dio_cookies;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import '../utils/cookie_manager.dart';
import '../utils/cookie_store.dart';
import 'fa_urls.dart';
import 'fa_enhanced_client.dart';
import '../main.dart' show webViewEnvironment;

class CloudflareError implements Exception {
  final String message;
  CloudflareError()
      : message =
            'FA is currently protected by Cloudflare challenge. Please try again later.';

  @override
  String toString() => 'CloudflareError: $message';
}

class FAClient {
  UserSession? _session;
  late final Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  // Enhanced client for CDN and multi-strategy support
  final FAEnhancedClient _enhancedClient = FAEnhancedClient.instance;

  // Using a realistic browser User-Agent to avoid Cloudflare blocks
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 13; SM-A325F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  // Cloudflare bypass state
  bool _cfPassInProgress = false;
  DateTime? _lastCfPass;
  static const Duration _cfPassCooldown = Duration(minutes: 5);

  static const List<String> _cfCookieUrls = [
    'https://www.furaffinity.net',
    'https://furaffinity.net',
    'https://www.furaffinity.net/',
  ];

  FAClient() {
    _dio = Dio(BaseOptions(
      headers: {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Cache-Control': 'max-age=0',
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
      final appDocDir = await getApplicationSupportDirectory();
      final cookiePath = '${appDocDir.path}/.cookies';
      final cookieDir = io.Directory(cookiePath);
      if (!cookieDir.existsSync()) {
        cookieDir.createSync(recursive: true);
      }
      _cookieJar = PersistCookieJar(
        storage: FileStorage(cookiePath),
      );
      _dio.interceptors.add(dio_cookies.CookieManager(_cookieJar));
      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> init() async {
    await _ensureInitialized();
    await _enhancedClient.initialize();
  }

  UserSession? get session => _session;

  Future<void> setSession(UserSession? session,
      {bool freshLogin = false}) async {
    _session = session;
    await _restoreCookiesFromSession();
    await _enhancedClient.syncCookies();
    // Do NOT run CF pass for fresh logins — the user just authenticated
    // through WebView, cookies are valid. CF pass is only needed when
    // restoring a saved session or when actual CF errors occur.
    if (!freshLogin) {
      await passCloudflareChallenge();
    } else {
      debugPrint('=== setSession: skipping CF pass for fresh login');
    }
  }

  Future<void> _restoreCookiesFromSession() async {
    if (_session?.cookies == null) return;
    await _ensureInitialized();
    try {
      final List<dynamic> cookiePairs = jsonDecode(_session!.cookies!);
      final cookies = <io.Cookie>[];
      for (final item in cookiePairs) {
        String? name;
        String? value;

        if (item is Map<String, dynamic>) {
          name = item['name']?.toString();
          value = item['value']?.toString();
        } else if (item is List && item.length >= 2) {
          name = item[0].toString();
          value = item[1].toString();
        }

        if (name != null &&
            value != null &&
            name.isNotEmpty &&
            value.isNotEmpty) {
          final cookie = io.Cookie(name, value)
            ..domain = '.furaffinity.net'
            ..path = '/';
          cookies.add(cookie);
        }
      }
      if (cookies.isNotEmpty) {
        await _cookieJar.saveFromResponse(
          Uri.parse(FAUrls.baseUrl),
          cookies,
        );

        // Also store in enhanced client
        for (final cookie in cookies) {
          _enhancedClient.setSessionData('cookie_${cookie.name}',
              '${cookie.name}=${cookie.value}; Domain=${cookie.domain}');
        }

        debugPrint('=== Restored ${cookies.length} cookies from session');
      }
    } catch (e) {
      debugPrint('=== Error restoring cookies from session: $e');
    }
  }

  /// Check if response is a genuine Cloudflare challenge page.
  /// CF challenge pages are small (< 30KB). Normal FA pages are 100KB+.
  /// Only throws if CF-specific markers are found in a small response body.
  void _checkCloudflare(Response response) {
    final cfMitigated = response.headers.value('cf-mitigated');
    if (cfMitigated == 'challenge') {
      throw CloudflareError();
    }

    final body = response.data?.toString() ?? '';
    if (response.statusCode != 403 && response.statusCode != 503) return;

    // CF challenge pages are typically small — a real FA page is 100KB+
    if (body.length > 30000) {
      debugPrint(
          '=== HTTP ${response.statusCode} with ${body.length}B body — not a CF challenge (too large)');
      return;
    }

    final lower = body.toLowerCase();
    final hasCfMarkers = lower.contains('just a moment') ||
        lower.contains('checking your browser') ||
        lower.contains('cf-browser-verification') ||
        lower.contains('challenges.cloudflare.com') ||
        lower.contains('cf_chl_page') ||
        (lower.contains('cf-turnstile') && lower.contains('challenge')) ||
        (lower.contains('cloudflare') &&
            lower.contains('verify you are human'));

    if (hasCfMarkers) {
      debugPrint(
          '=== CF challenge detected (HTTP ${response.statusCode}, body ${body.length}B)');
      throw CloudflareError();
    }
    debugPrint('=== HTTP ${response.statusCode} — not a CF challenge');
  }

  Future<String> _getHtml(String url, {bool waitForAjax = false}) async {
    await _ensureInitialized();

    // Use enhanced client for CDN URLs
    if (url.contains('t.furaffinity.net') ||
        url.contains('d.furaffinity.net') ||
        url.contains('a.furaffinity.net')) {
      try {
        final content = await _enhancedClient.fetchContent(url);
        if (content != null) {
          return utf8.decode(content);
        }
      } catch (e) {
        debugPrint('=== Enhanced client failed for $url: $e');
      }
    }

    // Always build explicit Cookie header from session data.
    final cookieHeader = _buildCookieHeader();
    final options = cookieHeader != null
        ? Options(headers: {'Cookie': cookieHeader})
        : null;

    // Strategy 1: Try Dio (fast HTTP client).
    // This works when CF is not active or does not require Turnstile.
    try {
      final response =
          await _dio.get<String>(url, options: options ?? Options());
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
      // Dio cannot pass CF Turnstile — different TLS fingerprint than WebView2.
      // Do NOT retry with Dio. Fall back to HeadlessInAppWebView which shares
      // the same WebViewEnvironment and can solve CF automatically.
      debugPrint('=== Dio blocked by CF, falling back to WebView for $url');
      try {
        return await _fetchHtmlWithWebView(url, waitForAjax: waitForAjax);
      } catch (e) {
        debugPrint('=== WebView fallback failed for $url: $e');
        rethrow;
      }
    } catch (e) {
      debugPrint('=== Dio request failed for $url: $e');
      rethrow;
    }
  }

  /// Fetch HTML using HeadlessInAppWebView.
  /// If [waitForAjax] is true, waits extra time for JS to load comments.
  /// Shares the same WebViewEnvironment as the login WebView, so it has
  /// the same cookies and can pass CF Turnstile (same TLS fingerprint).
  Future<String> _fetchHtmlWithWebView(String url,
      {bool waitForAjax = false}) async {
    final completer = Completer<String>();
    HeadlessInAppWebView? headless;
    int solveAttempts = 0;

    headless = HeadlessInAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
      ),
      onLoadStop: (controller, loadedUrl) async {
        try {
          final html = await controller.getHtml() ?? '';
          debugPrint('=== WebView fetch: ${html.length}B from $loadedUrl');

          // If this is a CF challenge page, wait for it to be solved
          if (_isCloudflarePage(html)) {
            solveAttempts++;
            debugPrint(
                '=== WebView fetch: CF challenge, attempt $solveAttempts');
            if (solveAttempts > 5) {
              if (!completer.isCompleted) {
                completer.completeError(Exception(
                    'CF challenge not solved after $solveAttempts attempts'));
              }
              return;
            }
            await _attemptSolveCloudflareChallenge(controller);
            await Future.delayed(const Duration(seconds: 5));
            final retryHtml = await controller.getHtml() ?? '';
            if (!_isCloudflarePage(retryHtml)) {
              if (!completer.isCompleted) {
                completer.complete(retryHtml);
              }
            }
            // If still CF, onLoadStop will fire again after redirect
            return;
          }

          if (!completer.isCompleted) {
            // For submission pages, wait for JS to load comments via AJAX
            if (waitForAjax) {
              await Future.delayed(const Duration(seconds: 3));
              final ajaxHtml = await controller.getHtml() ?? '';
              debugPrint(
                  '=== WebView fetch (after AJAX wait): ${ajaxHtml.length}B');
              if (ajaxHtml.length > html.length) {
                completer.complete(ajaxHtml);
              } else {
                completer.complete(html);
              }
            } else {
              completer.complete(html);
            }
          }
        } catch (e) {
          debugPrint('=== WebView fetch onLoadStop error: $e');
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      onReceivedHttpError: (controller, request, response) async {
        if (!(request.isForMainFrame ?? false)) return;
        final status = response.statusCode ?? 0;
        debugPrint('=== WebView fetch: HTTP $status');
      },
      onReceivedError: (controller, request, error) async {
        if (!(request.isForMainFrame ?? false)) return;
        debugPrint('=== WebView fetch error: ${error.description}');
      },
      initialUrlRequest: URLRequest(
        url: WebUri(url),
      ),
    );

    await headless.run();

    try {
      final html = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('=== WebView fetch timeout for $url');
          return ''; // Return empty instead of throwing
        },
      );
      await headless.dispose();

      // Sync any new cookies from this request
      await _syncCookiesFromWebView();

      if (html.isEmpty) {
        debugPrint('=== WebView fetch returned empty for $url');
        return '';
      }

      debugPrint('=== WebView fetch success: ${html.length}B from $url');
      return html;
    } catch (e) {
      await headless.dispose();
      debugPrint('=== WebView fetch exception for $url: $e');
      rethrow;
    }
  }

  Future<bool> verifySession() async {
    if (_session?.cookies == null) return false;
    try {
      await _ensureInitialized();

      // Build explicit Cookie header from session data.
      final cookieHeader = _buildCookieHeader();
      debugPrint(
          '=== verifySession: cookie header length: ${cookieHeader?.length ?? 0}');

      final options = cookieHeader != null
          ? Options(headers: {'Cookie': cookieHeader})
          : null;

      final response =
          await _dio.get<String>(FAUrls.home, options: options ?? Options());

      try {
        _checkCloudflare(response);
      } on CloudflareError {
        // Dio can't pass CF — use WebView to check if session is valid
        debugPrint('=== verifySession: CF detected, checking via WebView');
        try {
          final html = await _fetchHtmlWithWebView(FAUrls.home);
          // If we got a real FA page (not empty, not CF page), session is valid
          return html.isNotEmpty && !_isCloudflarePage(html);
        } catch (e) {
          debugPrint('=== verifySession: WebView check failed: $e');
          return false;
        }
      }

      final status = response.statusCode ?? 0;
      debugPrint('=== verifySession status: $status');
      if (status >= 200 && status < 300) return true;
      if (status == 401 || status == 403) {
        debugPrint('=== verifySession: HTTP $status, session may be invalid');
        return false;
      }
      if (status >= 500) return true; // Server error, session itself is ok
      return false;
    } on CloudflareError {
      return false;
    } catch (e) {
      debugPrint('verifySession error: $e');
      return false;
    }
  }

  Future<void> clearCookies() async {
    if (_initialized) {
      await _cookieJar.deleteAll();
    }
    await _enhancedClient.clearData();
  }

  // Enhanced CDN support
  Future<Uint8List?> loadCDNContent(String url) async {
    return await _enhancedClient.fetchContent(url);
  }

  Future<Uint8List?> loadCDNImage(String url) async {
    return await _enhancedClient.loadImage(url);
  }

  Widget getCDNImageWidget(
    String url, {
    Map<String, String>? headers,
    Widget? placeholder,
    Widget? errorWidget,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return _enhancedClient.getImageWidget(
      url,
      headers: headers,
      placeholder: placeholder,
      errorWidget: errorWidget,
      width: width,
      height: height,
      fit: fit,
    );
  }

  // Get enhanced client statistics
  Map<String, dynamic> getEnhancedStats() {
    return _enhancedClient.getSessionStats();
  }

  // Set WebView controller for cookie synchronization
  void setWebViewController(InAppWebViewController controller) {
    _enhancedClient.setWebViewController(controller);
  }

  // Clear all session data
  Future<void> clearSessionData() async {
    await _enhancedClient.clearData();
  }

  Future<List<Submission>> getSubmissions(int page, String category) async {
    final url = FAUrls.browse(filter: category, page: page);
    final html = await _getHtml(url);
    return Submission.parseSubmissionsPage(html);
  }

  Future<List<Submission>> getGallery(String username, {int page = 1}) async {
    final url = '${FAUrls.gallery(username)}?page=$page';
    final html = await _getHtml(url);
    return Submission.parseSubmissionsPage(html);
  }

  /// Fetch submission details + comments in a single HTML fetch.
  /// Avoids loading the same page twice through WebView.
  Future<({Submission? submission, List<FAComment> comments})>
      getSubmissionWithComments(String id) async {
    final url = FAUrls.viewSubmission(id);
    // waitForAjax: comments load via JavaScript, need extra wait
    final html = await _getHtml(url, waitForAjax: true);
    // Debug: dump comment section HTML to see real structure
    final commentStart = html.indexOf('comment');
    if (commentStart > 0) {
      final start = commentStart > 200 ? commentStart - 200 : 0;
      final end =
          commentStart + 2000 < html.length ? commentStart + 2000 : html.length;
      debugPrint('=== HTML comment section (pos $commentStart):');
      debugPrint('=== ${html.substring(start, end)}');
    } else {
      debugPrint('=== HTML: no "comment" string found, length=${html.length}');
    }
    final submission = Submission.parseSubmissionDetails(html, id);
    final comments = FAComment.parseComments(html);
    debugPrint(
        '=== getSubmissionWithComments: ${comments.length} comments parsed');
    // Dump first comment for debug
    if (comments.isNotEmpty) {
      final c = comments.first;
      debugPrint(
          '=== First comment: id=${c.id}, author=${c.author}, text=${c.text.length}chars, time=${c.time}, indent=${c.indentLevel}');
    }
    return (submission: submission, comments: comments);
  }

  Future<Submission?> getSubmission(String id) async {
    final result = await getSubmissionWithComments(id);
    return result.submission;
  }

  Future<List<FAComment>> getComments(String id) async {
    final result = await getSubmissionWithComments(id);
    return result.comments;
  }

  Future<List<Submission>> search(
    String query, {
    int page = 1,
    String sortBy = 'relevancyt',
    String sortDirection = 'desc',
  }) async {
    final url = FAUrls.search(query,
        page: page, sortBy: sortBy, sortDirection: sortDirection);
    final html = await _getHtml(url);
    return Submission.parseSearchResults(html);
  }

  /// Toggle favorite on a submission.
  /// [favoriteUrl] is the action URL parsed from the submission page
  /// (e.g. "/fav/123456/?key=abc" to fave, "/unfav/123456/?key=abc" to unfave).
  /// Returns true if the action succeeded.
  Future<bool> toggleFavorite(String favoriteUrl) async {
    final url = favoriteUrl.startsWith('http')
        ? favoriteUrl
        : '${FAUrls.baseUrl}$favoriteUrl';

    debugPrint('=== toggleFavorite: POST via WebView $url');

    // FA fav/unfav requires POST with cookies — always use WebView to bypass CF.
    final completer = Completer<bool>();
    HeadlessInAppWebView? headless;

    headless = HeadlessInAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
      ),
      onLoadStop: (controller, loadedUrl) async {
        try {
          final html = await controller.getHtml() ?? '';
          debugPrint(
              '=== toggleFavorite WebView: ${html.length}B from $loadedUrl');

          if (_isCloudflarePage(html)) {
            debugPrint('=== toggleFavorite: CF challenge, waiting...');
            await Future.delayed(const Duration(seconds: 3));
            final retryHtml = await controller.getHtml() ?? '';
            if (!_isCloudflarePage(retryHtml)) {
              if (!completer.isCompleted) completer.complete(true);
            }
            return;
          }

          // If we got a real page back (not CF), the action succeeded
          if (!completer.isCompleted) completer.complete(html.isNotEmpty);
        } catch (e) {
          debugPrint('=== toggleFavorite onLoadStop error: $e');
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onReceivedHttpError: (controller, request, response) async {
        if (!(request.isForMainFrame ?? false)) return;
        final status = response.statusCode ?? 0;
        debugPrint('=== toggleFavorite: HTTP $status');
      },
      initialUrlRequest: URLRequest(
        url: WebUri(url),
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': FAUrls.baseUrl,
        },
      ),
    );

    await headless.run();

    try {
      final success = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('=== toggleFavorite: timeout');
          return false;
        },
      );
      await headless.dispose();

      // Sync cookies after action
      await _syncCookiesFromWebView();

      debugPrint('=== toggleFavorite: result=$success');
      return success;
    } catch (e) {
      await headless.dispose();
      debugPrint('=== toggleFavorite error: $e');
      return false;
    }
  }

  /// Toggle SFW mode on FurAffinity website.
  /// Posts to /sfw/toggle/ which sets/removes the sfw_toggle cookie.
  /// Returns true if the toggle succeeded.
  Future<bool> toggleSiteSfwMode() async {
    final url = '${FAUrls.baseUrl}/sfw/toggle/';
    debugPrint('=== toggleSiteSfwMode: POST via WebView $url');

    final completer = Completer<bool>();
    HeadlessInAppWebView? headless;

    headless = HeadlessInAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
      ),
      onLoadStop: (controller, loadedUrl) async {
        try {
          final html = await controller.getHtml() ?? '';
          debugPrint(
              '=== toggleSiteSfwMode WebView: ${html.length}B from $loadedUrl');

          if (_isCloudflarePage(html)) {
            debugPrint('=== toggleSiteSfwMode: CF challenge, waiting...');
            await Future.delayed(const Duration(seconds: 3));
            final retryHtml = await controller.getHtml() ?? '';
            if (!_isCloudflarePage(retryHtml)) {
              if (!completer.isCompleted) completer.complete(true);
            }
            return;
          }

          if (!completer.isCompleted) completer.complete(html.isNotEmpty);
        } catch (e) {
          debugPrint('=== toggleSiteSfwMode onLoadStop error: $e');
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onReceivedHttpError: (controller, request, response) async {
        if (!(request.isForMainFrame ?? false)) return;
        final status = response.statusCode ?? 0;
        debugPrint('=== toggleSiteSfwMode: HTTP $status');
      },
      initialUrlRequest: URLRequest(
        url: WebUri(url),
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Referer': FAUrls.baseUrl,
        },
      ),
    );

    await headless.run();

    try {
      final success = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('=== toggleSiteSfwMode: timeout');
          return false;
        },
      );
      await headless.dispose();

      // Sync cookies after toggle
      await _syncCookiesFromWebView();

      debugPrint('=== toggleSiteSfwMode: result=$success');
      return success;
    } catch (e) {
      await headless.dispose();
      debugPrint('=== toggleSiteSfwMode error: $e');
      return false;
    }
  }

  Future<List<FANotification>> getNotifications() async {
    final html = await _getHtml(FAUrls.notifications);
    return FANotification.parseNotifications(html);
  }

  Future<FAUser?> getUser(String username) async {
    final url = FAUrls.user(username);
    final html = await _getHtml(url);
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
    final cookieHeader = _buildCookieHeader();
    final options = cookieHeader != null
        ? Options(headers: {'Cookie': cookieHeader})
        : null;
    await _dio.post<String>(url, options: options ?? Options());
    return !currentlyWatching;
  }

  // ── Journal methods ──────────────────────────────────────────────────

  /// Fetch a single journal entry by ID.
  Future<FAJournal?> getJournal(String id) async {
    final url = FAUrls.journal(id);
    final html = await _getHtml(url);
    return FAJournal.parseJournalDetail(html, id);
  }

  /// Fetch a user's journals list.
  Future<List<FAJournalPreview>> getUserJournals(String username) async {
    final url = FAUrls.journals(username);
    final html = await _getHtml(url);
    return FAJournalPreview.parseJournalList(html);
  }

  /// Fetch a user's favorites page.
  Future<List<Submission>> getUserFavorites(String username,
      {int page = 1}) async {
    final url = '${FAUrls.favorites(username)}?page=$page';
    final html = await _getHtml(url);
    return Submission.parseSubmissionsPage(html);
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
      debugPrint('=== CF pass: opening HeadlessWebView for ${FAUrls.baseUrl}');
      final completer = Completer<bool>();
      HeadlessInAppWebView? headless;
      int solveAttempts = 0;

      headless = HeadlessInAppWebView(
        webViewEnvironment: webViewEnvironment,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
        ),
        onLoadStop: (controller, url) async {
          try {
            final html = await controller.getHtml() ?? '';
            debugPrint('=== CF pass: HTML length: ${html.length}');

            if (_isCloudflarePage(html)) {
              solveAttempts++;
              debugPrint(
                  '=== CF pass: challenge detected, attempt $solveAttempts');
              await _attemptSolveCloudflareChallenge(controller);
              await Future.delayed(const Duration(seconds: 5));
              final retryHtml = await controller.getHtml() ?? '';
              debugPrint('=== CF pass: retry HTML length: ${retryHtml.length}');

              if (_isCloudflarePage(retryHtml)) {
                debugPrint(
                    '=== CF pass: challenge still present after attempt $solveAttempts');
                if (solveAttempts >= 4) {
                  debugPrint('=== CF pass: maximum challenge attempts reached');
                  return;
                }
                return;
              }
            }

            debugPrint(
                '=== CF pass: page loaded successfully, syncing cookies...');
            await _syncCookiesFromWebView();
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            debugPrint('=== CF pass onLoadStop error: $e');
          }
        },
        onReceivedHttpError: (controller, request, response) async {
          if (!(request.isForMainFrame ?? false)) return;
          final status = response.statusCode ?? 0;
          if (status == 403 || status == 503) {
            debugPrint('=== CF pass: HTTP $status — challenge in progress');
          }
        },
        onReceivedError: (controller, request, error) async {
          if (!(request.isForMainFrame ?? false)) return;
          debugPrint('=== CF pass: error — ${error.description}');
        },
        initialUrlRequest: URLRequest(
          url: WebUri(FAUrls.baseUrl),
        ),
      );

      await headless.run();

      final success = await completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('=== CF pass: timeout, syncing cookies anyway');
          return false;
        },
      );

      await headless.dispose();

      if (!success) {
        await _syncCookiesFromWebView();
      }

      // Restore all session cookies to ensure essential cookies (a, cf_clearance) are in cookieJar
      await _restoreCookiesFromSession();

      _lastCfPass = DateTime.now();
      debugPrint('=== CF pass: completed');
      return true;
    } catch (e) {
      debugPrint('=== CF pass error: $e');
      return false;
    } finally {
      _cfPassInProgress = false;
    }
  }

  Future<void> _attemptSolveCloudflareChallenge(
    InAppWebViewController controller,
  ) async {
    try {
      await controller.evaluateJavascript(source: '''
        (async () => {
          const selectors = [
            'iframe[src*="turnstile"]',
            '.cf-turnstile',
            '#cf-turnstile',
            '.cf-browser-verification',
            '.cf-challenge',
            '#challenge-form',
            'button[type="submit"]',
            'input[type="submit"]',
          ];

          for (const selector of selectors) {
            const element = document.querySelector(selector);
            if (element) {
              element.scrollIntoView({behavior: 'smooth', block: 'center'});
              if (typeof element.click === 'function') {
                element.click();
              }
              console.log('CF attempt click', selector);
              break;
            }
          }

          return true;
        })();
      ''');
    } catch (e) {
      debugPrint('=== CF pass: solver JS error: $e');
    }
  }

  /// Check if the HTML is a CF challenge INTERSTITIAL page.
  /// Key insight: CF challenge pages are tiny (< 30 KB).
  /// Real FA pages are 80 KB+ and may contain Turnstile/Cloudflare
  /// references in <script> tags — those are NOT challenge pages.
  bool _isCloudflarePage(String html) {
    // Real FA pages are always > 30 KB. CF interstitials are small.
    if (html.length > 30000) return false;

    final lower = html.toLowerCase();
    // Title-based check — CF interstitial always has this exact title
    if (!lower.contains('just a moment') &&
        !lower.contains('checking your browser')) {
      return false;
    }
    // Confirm with additional challenge-only markers
    return lower.contains('cf_chl_page') ||
        lower.contains('challenges.cloudflare.com') ||
        lower.contains('cf-turnstile') ||
        lower.contains('verify you are human');
  }

  Future<void> _syncCookiesFromWebView() async {
    final seen = <String>{};
    final allCookies = <Cookie>[];

    for (final url in _cfCookieUrls) {
      try {
        final cookies = await FAICookieManager.getCookies(url);
        for (final c in cookies) {
          if (seen.add(c.name)) {
            // Конвертируем flutter_inappwebview.Cookie в dart:io.Cookie
            final ioCookie = io.Cookie(c.name, c.value);
            ioCookie.domain = c.domain ?? '.furaffinity.net';
            ioCookie.path = c.path ?? '/';
            ioCookie.secure = c.isSecure ?? true;
            ioCookie.httpOnly = c.isHttpOnly ?? false;
            if (c.expiresDate != null) {
              ioCookie.expires =
                  DateTime.fromMillisecondsSinceEpoch(c.expiresDate!);
            }
            // Преобразуем io.Cookie в flutter_inappwebview.Cookie
            allCookies.add(Cookie(
              name: ioCookie.name,
              value: ioCookie.value,
              domain: ioCookie.domain,
              path: ioCookie.path,
              isHttpOnly: ioCookie.httpOnly,
              isSecure: ioCookie.secure,
              expiresDate: ioCookie.expires?.millisecondsSinceEpoch,
            ));
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
    // Преобразуем flutter_inappwebview.Cookie в io.Cookie
    final ioCookies = allCookies
        .map((c) => io.Cookie(c.name, c.value)
          ..domain = c.domain ?? '.furaffinity.net'
          ..path = c.path ?? '/'
          ..secure = c.isSecure ?? false)
        .toList();
    // Преобразуем io.Cookie в flutter_inappwebview.Cookie
    final flutterCookies = ioCookies
        .map((c) => Cookie(
              name: c.name,
              value: c.value,
              domain: c.domain,
              path: c.path,
              isHttpOnly: c.httpOnly,
              isSecure: c.secure,
              expiresDate: c.expires?.millisecondsSinceEpoch,
            ))
        .toList();
    await _saveWebViewCookiesToCookieJar(flutterCookies);
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
        final value = c.value;
        if (value.isEmpty) continue;
        final expiresDate = c.expiresDate ?? 0;
        sessionCookies[c.name] = {
          'name': c.name,
          'value': value,
          'domain': c.domain ?? '.furaffinity.net',
          'path': c.path ?? '/',
          'isHttpOnly': c.isHttpOnly,
          'isSecure': c.isSecure,
          'expiresDate': expiresDate,
        };
      }

      _session = UserSession(
        username: _session!.username,
        avatarUrl: _session!.avatarUrl,
        isLoggedIn: _session!.isLoggedIn,
        cookies: jsonEncode(sessionCookies.values.toList()),
      );

      debugPrint('=== Session updated with ${webViewCookies.length} cookies');
    } catch (e) {
      debugPrint('=== CF sync: error saving to session: $e');
    }
  }

  Future<void> _saveWebViewCookiesToCookieJar(
      List<Cookie> webViewCookies) async {
    await _ensureInitialized();
    final cookies = <io.Cookie>[];
    for (final c in webViewCookies) {
      final value = c.value;
      if (value.isEmpty) continue;
      final cookie = io.Cookie(c.name, value);
      cookie.domain = c.domain ?? '.furaffinity.net';
      cookie.path = c.path ?? '/';
      cookie.secure = c.isSecure ?? false;
      cookies.add(cookie);
    }
    if (cookies.isNotEmpty) {
      await _cookieJar.saveFromResponse(Uri.parse(FAUrls.baseUrl), cookies);
      debugPrint('=== CookieJar updated with ${cookies.length} cookies');

      // Обновляем CookieStore для использования в FAImage
      CookieStore.instance.setCookies(cookies);
      debugPrint('=== CookieStore updated with ${cookies.length} cookies');
    }
  }

  /// Check if SFW mode is enabled on the FA website by reading the sfw_toggle cookie.
  /// Returns true if SFW is on (sfw_toggle cookie is present and non-empty).
  bool checkSiteSfwMode() {
    if (_session?.cookies == null) return false;
    try {
      final List<dynamic> raw = jsonDecode(_session!.cookies!);
      for (final item in raw) {
        if (item is Map<String, dynamic>) {
          final name = item['name']?.toString() ?? '';
          if (name == 'sfw_toggle') {
            final value = item['value']?.toString() ?? '';
            return value.isNotEmpty && value != '0';
          }
        }
      }
    } catch (e) {
      debugPrint('=== Error checking SFW cookie: $e');
    }
    return false;
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
          if (name.isNotEmpty && value.isNotEmpty) {
            parts.add('$name=$value');
          }
        }
      }
      return parts.join('; ');
    } catch (e) {
      debugPrint('=== Error building cookie header: $e');
      return null;
    }
  }
}
