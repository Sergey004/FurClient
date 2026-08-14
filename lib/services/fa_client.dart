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

import 'package:fa_kit/fa_kit.dart' as fa;

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

  // Persistent headless WebView for watch feed — reused across requests to
  // maintain CF clearance cookies. Without this, each HeadlessInAppWebView
  // creates a fresh WebView2 context that CF challenges anew, and the 'a'
  // auth cookie is dropped after the challenge on Windows.
  HeadlessInAppWebView? _feedWebView;
  InAppWebViewController? _feedController;
  final Completer<void> _feedReady = Completer<void>();
  int _feedCfAttempts = 0;

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
    if (freshLogin) {
      debugPrint('=== setSession: skipping proactive CF pass for fresh login');
    } else {
      debugPrint(
          '=== setSession: restored session cookies; CF challenge will be handled only after a real request failure');
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

  @visibleForTesting
  static List<Map<String, dynamic>> mergeCookiesForSession(
    List<Map<String, dynamic>> existingCookies,
    List<Map<String, dynamic>> incomingCookies,
  ) {
    final merged = <String, Map<String, dynamic>>{};

    for (final cookie in existingCookies) {
      final name = cookie['name']?.toString();
      if (name == null || name.isEmpty) continue;
      merged[name] = Map<String, dynamic>.from(cookie);
    }

    for (final cookie in incomingCookies) {
      final name = cookie['name']?.toString();
      if (name == null || name.isEmpty) continue;
      merged[name] = Map<String, dynamic>.from(cookie);
    }

    return merged.values.toList();
  }

  Future<String> _getHtml(String url, {bool waitForAjax = false}) async {
    await _ensureInitialized();

    // Use enhanced client for CDN URLs.
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

    try {
      final html = await _fetchHtmlWithWebView(url, waitForAjax: waitForAjax);
      if (html.isEmpty) {
        debugPrint('=== WebView fetch returned empty HTML for $url');
        throw CloudflareError();
      }
      if (_isCloudflarePage(html)) {
        debugPrint('=== WebView fetched a Cloudflare challenge page for $url');
        throw CloudflareError();
      }
      return html;
    } catch (e) {
      debugPrint('=== WebView HTML fetch failed for $url: $e');
      rethrow;
    }
  }

  /// Inject session cookies into the platform CookieManager so the
  /// headless WebView sends them with its request.  Without this the
  /// HeadlessInAppWebView only has whatever cookies the environment
  /// accumulated from *previous* WebView pages in the same session;
  /// if the app was cold-started the auth cookie ('a') is missing.
  Future<void> _injectSessionCookies(String url) async {
    if (_session?.cookies == null) return;
    try {
      final List<dynamic> raw = jsonDecode(_session!.cookies!);
      final cookieManager = FAICookieManager.instance;
      final uri = Uri.parse(url);
      final origin = '${uri.scheme}://${uri.host}';
      for (final item in raw) {
        String? name;
        String? value;
        String? domain;
        String? path;
        bool? secure;
        int? expiresMs;

        if (item is Map<String, dynamic>) {
          name = item['name']?.toString();
          value = item['value']?.toString();
          domain = item['domain']?.toString();
          path = item['path']?.toString() ?? '/';
          secure = item['isSecure'] as bool?;
          expiresMs = item['expiresDate'] as int?;
        } else if (item is List && item.length >= 2) {
          name = item[0].toString();
          value = item[1].toString();
          path = '/';
        }

        if (name == null || value == null || name.isEmpty || value.isEmpty) {
          continue;
        }

        final cookieDomain = domain ?? '.furaffinity.net';
        final cookiePath = path ?? '/';
        final isSecure = secure ?? true;

        // Expiry far in the future so the cookie doesn't expire during
        // the session.  FA's 'a' cookie has a very long TTL anyway.
        final expiry = expiresMs != null && expiresMs > 0
            ? DateTime.fromMillisecondsSinceEpoch(expiresMs)
            : DateTime.now().add(const Duration(days: 365));

        // NOTE: WebView2's SetCookie silently drops cookies flagged as
        // HttpOnly.  We intentionally pass false here — the HttpOnly flag
        // only controls JavaScript access (document.cookie); WebView2 will
        // still include the cookie in HTTP requests regardless.
        await cookieManager.setCookie(
          url: WebUri(origin),
          name: name,
          value: value,
          domain: cookieDomain,
          path: cookiePath,
          expiresDate: expiry.millisecondsSinceEpoch,
          isSecure: isSecure,
          isHttpOnly: false,
        );
      }
      final names = raw
          .whereType<Map<String, dynamic>>()
          .map((m) => m['name']?.toString() ?? '?')
          .toList();
      debugPrint(
          '=== Injected session cookies into CookieManager for $origin: $names');
    } catch (e) {
      debugPrint('=== Cookie injection error: $e');
    }
  }

  /// Build a raw `Cookie:` header value from the session cookies.
  /// Used to inject auth cookies into URLRequest headers when
  /// CookieManager.setCookie() fails to persist them (e.g. the 'a' cookie).
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
      return parts.isEmpty ? null : parts.join('; ');
    } catch (e) {
      debugPrint('=== Error building cookie header: $e');
      return null;
    }
  }

  /// Create a persistent headless WebView for authenticated feed pages.
  /// This WebView stays alive so it maintains CF clearance and auth cookies
  /// across requests, avoiding the per-request CF challenge on Windows.
  Future<InAppWebViewController> _ensureFeedWebView() async {
    if (_feedController != null) return _feedController!;

    // Build cookie header once for the initial request
    final cookieHeader = _buildCookieHeader();

    _feedWebView = HeadlessInAppWebView(
      webViewEnvironment: webViewEnvironment,
      initialSettings: InAppWebViewSettings(javaScriptEnabled: true),
      onLoadStop: (controller, loadedUrl) async {
        final html = await controller.getHtml() ?? '';

        if (_isCloudflarePage(html)) {
          _feedCfAttempts++;
          debugPrint('=== FeedWebView: CF challenge #$_feedCfAttempts');
          if (_feedCfAttempts > 5) {
            if (!_feedReady.isCompleted) {
              _feedReady.completeError(Exception(
                  'CF challenge not solved after $_feedCfAttempts attempts'));
            }
            return;
          }
          await _attemptSolveCloudflareChallenge(controller);
          await Future.delayed(const Duration(seconds: 5));
          return; // onLoadStop will fire again after redirect
        }

        _feedController = controller;
        debugPrint(
            '=== FeedWebView: ready (${html.length}B, title=${await _extractTitle(html)})');
        if (!_feedReady.isCompleted) _feedReady.complete();
      },
      onReceivedError: (controller, request, error) {
        debugPrint('=== FeedWebView error: ${error.description}');
      },
      initialUrlRequest: URLRequest(
        url: WebUri('https://www.furaffinity.net/'),
        headers: {
          if (cookieHeader != null) 'Cookie': cookieHeader,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        },
      ),
    );

    await _feedWebView!.run();

    // Wait for CF challenge to resolve and initial page to load
    try {
      await _feedReady.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          debugPrint('=== FeedWebView: init timeout');
        },
      );
    } catch (_) {
      // If CF challenge failed, try without it
    }

    // Sync cookies acquired during CF challenge/initial load
    await _syncCookiesFromWebView();
    await _restoreCookiesFromSession();

    return _feedController!;
  }

  String? _extractTitle(String html) {
    final m = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    return m?.group(1)?.trim();
  }

  /// Navigate the persistent feed WebView to a new URL and return its HTML.
  Future<String> _navigateFeedWebView(String url) async {
    final controller = await _ensureFeedWebView();

    // Set a one-shot load listener by polling
    debugPrint('=== FeedWebView: navigating to $url');
    final navCookieHeader = _buildCookieHeader();
    final navHeaders = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    };
    if (navCookieHeader != null) navHeaders['Cookie'] = navCookieHeader;
    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri(url),
        headers: navHeaders,
      ),
    );

    // Wait for page load via polling
    await Future.delayed(const Duration(seconds: 3));
    var html = await controller.getHtml() ?? '';
    int waitRounds = 0;

    while (_isCloudflarePage(html) && waitRounds < 5) {
      _feedCfAttempts++;
      debugPrint('=== FeedWebView: CF challenge on navigate #$_feedCfAttempts');
      await _attemptSolveCloudflareChallenge(controller);
      await Future.delayed(const Duration(seconds: 8));
      html = await controller.getHtml() ?? '';
      waitRounds++;
    }

    // Wait for AJAX to load
    await Future.delayed(const Duration(seconds: 3));
    final finalHtml = await controller.getHtml() ?? '';
    final result = finalHtml.length > html.length ? finalHtml : html;

    await _syncCookiesFromWebView();
    await _restoreCookiesFromSession();

    return result;
  }

  /// Dispose the persistent feed WebView.
  void _disposeFeedWebView() {
    _feedController = null;
    _feedCfAttempts = 0;
    final wv = _feedWebView;
    _feedWebView = null;
    if (wv != null) wv.dispose();
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

    // Inject session cookies via CookieManager as a best-effort attempt.
    await _injectSessionCookies(url);

    // Also build a raw Cookie header so we can attach it directly to the
    // URLRequest — this bypasses CookieManager entirely and ensures auth
    // cookies (especially 'a') are sent even if setCookie() dropped them.
    final cookieHeader = _buildCookieHeader();
    debugPrint(
        '=== Cookie header for URLRequest: ${cookieHeader?.substring(0, cookieHeader.length > 200 ? 200 : cookieHeader.length)}...');

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
        headers: {
          if (cookieHeader != null) 'Cookie': cookieHeader,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        },
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

      // Sync any new cookies from this request, then restore the existing
      // session cookies so essential values such as 'a' remain available.
      await _syncCookiesFromWebView();
      await _restoreCookiesFromSession();

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
      debugPrint('=== verifySession: checking session via WebView');

      final html = await _fetchHtmlWithWebView(FAUrls.home);
      if (html.isEmpty) {
        debugPrint('=== verifySession: WebView returned empty HTML');
        return false;
      }

      final isValid = !_isCloudflarePage(html);
      debugPrint(
          '=== verifySession: WebView result is ${isValid ? 'valid' : 'blocked by CF'}');
      return isValid;
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

  /// Fetch the watch feed (`/msg/submissions/`).
  ///
  /// Mirrors FurAffinityApp's `OnlineFASession.fetchSubmissionsPage(...)` /
  /// `FAURLs.submissionsUrl(from:)`: page 1 is the latest 72 submissions;
  /// subsequent pages are reached via `new~<sid>@72` (everything *older* than
  /// `<sid>`). Returns the parsed list plus the cursor sid to use for the
  /// next page (the smallest sid in the returned batch, or `null` once the
  /// oldest page is reached and there is no "Next" link).
  Future<({List<Submission> submissions, int? nextSid})> getWatchSubmissions(
      {int? fromSid}) async {
    final url = fromSid == null
        ? FAUrls.latest72SubmissionsUrl.toString()
        : FAUrls.submissionsFrom(fromSid);

    // On Windows, use the persistent feed WebView so CF clearance cookies
    // are preserved across calls. On other platforms, use standard fetch.
    final html = io.Platform.isWindows
        ? await _navigateFeedWebView(url)
        : await _getHtml(url, waitForAjax: true);

    debugPrint('=== WatchFeed: fetched ${html.length} chars from $url');
    // Print the page <title> so we can see if we got a redirect
    final titleMatch =
        RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
            .firstMatch(html);
    final pageTitle = titleMatch?.group(1)?.trim() ?? '(none)';
    debugPrint('=== WatchFeed: page title = $pageTitle');
    // Show around the submissions section if present
    final idx = html.indexOf('messagecenter-submissions');
    if (idx >= 0) {
      final start = idx > 100 ? idx - 100 : 0;
      debugPrint('=== WatchFeed: found messagecenter-submissions at $idx');
      debugPrint(html.substring(start, (start + 1500).clamp(0, html.length)));
    } else {
      debugPrint('=== WatchFeed: NO messagecenter-submissions found');
      // Skip the <head> and dump the <body> content so we can see
      // what structure FA actually returns.
      final bodyIdx = html.indexOf('<body');
      final dumpFrom = bodyIdx >= 0 ? bodyIdx : 0;
      debugPrint('=== WatchFeed: body HTML (from $dumpFrom):');
      debugPrint(
          html.substring(dumpFrom, (dumpFrom + 5000).clamp(0, html.length)));
    }
    final page = fa.FASubmissionsPage.parse(
        html, Uri.parse('https://www.furaffinity.net'));
    debugPrint(
        '=== WatchFeed: parsed ${page.submissions.length} submissions, nextPageUrl=${page.nextPageUrl}');
    final subs = page.submissions
        .whereType<fa.FASubmissionsPageItem>()
        .map(Submission.fromFASubmissionsPageItem)
        .toList();

    // Next cursor: pull sid out of the "Next" link (`new~<sid>@72`).
    // No Next link ⇒ oldest page reached.
    int? nextSid;
    final nextHref = page.nextPageUrl?.path ?? '';
    final m = RegExp(r'new~(\d+)@72').firstMatch(nextHref);
    if (m != null) nextSid = int.tryParse(m.group(1)!);

    return (submissions: subs, nextSid: nextSid);
  }

  Future<List<Submission>> getGallery(String username, {int page = 1}) async {
    final url = FAUrls.gallery(username, page: page);
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
    try {
      final page = fa.FASubmissionPage.parse(
          html, Uri.parse('https://www.furaffinity.net/view/$id/'));
      final submission = Submission.fromFASubmissionPage(page, id);
      final comments = fa
          .buildCommentsTree(page.comments)
          .map((c) => FAComment.fromFAComment(c))
          .toList();
      debugPrint(
          '=== getSubmissionWithComments: ${comments.length} comments parsed');
      return (submission: submission, comments: comments);
    } catch (e) {
      debugPrint('=== getSubmissionWithComments parse failed: $e');
      return (submission: null, comments: <FAComment>[]);
    }
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
    String sortBy = 'relevancy',
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
  /// [submissionId] is needed to re-parse the response as a submission page.
  ///
  /// Mirrors FurAffinityApp's OnlineFASession.toggleFavorite(for:): the
  /// fav/unfav link is a plain GET (it's an `<a href>` on the page, not a
  /// form) and the *response* is re-parsed to get the fresh state —
  /// including the new favoriteUrl with its updated `?key=`. Guessing the
  /// next favoriteUrl client-side (swapping /fav/ <-> /unfav/) drops that
  /// key and breaks a second toggle within the same session.
  ///
  /// Returns the updated [Submission] on success, or null on failure.
  Future<Submission?> toggleFavorite(
      String favoriteUrl, String submissionId) async {
    final url = favoriteUrl.startsWith('http')
        ? favoriteUrl
        : '${FAUrls.baseUrl}$favoriteUrl';

    debugPrint('=== toggleFavorite: GET via WebView $url');

    final completer = Completer<String?>();
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
              if (!completer.isCompleted) completer.complete(retryHtml);
            }
            return;
          }

          if (!completer.isCompleted) {
            completer.complete(html.isNotEmpty ? html : null);
          }
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
        // GET — /fav/ и /unfav/ на FA обычные <a href> ссылки, не форма.
        headers: {
          'Referer': FAUrls.baseUrl,
        },
      ),
    );

    await headless.run();

    try {
      final html = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('=== toggleFavorite: timeout');
          return null;
        },
      );
      await headless.dispose();

      // Sync cookies after action
      await _syncCookiesFromWebView();

      if (html == null || html.isEmpty) {
        debugPrint('=== toggleFavorite: empty response');
        return null;
      }

      // Парсим ответ как submission page — получаем актуальный favoriteUrl
      // (с новым key) и isFavorite/faves из ответа сервера, а не из догадки.
      final page = fa.FASubmissionPage.parse(
        html,
        Uri.parse('https://www.furaffinity.net/view/$submissionId/'),
      );
      final submission = Submission.fromFASubmissionPage(page, submissionId);
      debugPrint(
          '=== toggleFavorite: result isFavorite=${submission.isFavorite}, faves=${submission.faves}');
      return submission;
    } catch (e) {
      await headless.dispose();
      debugPrint('=== toggleFavorite error: $e');
      return null;
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
    final url = FAUrls.favorites(username, page: page);
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
      final sessionCookieMaps = raw.whereType<Map<String, dynamic>>().toList();
      final webViewCookieMaps = webViewCookies
          .where((c) => c.value.isNotEmpty)
          .map((c) => {
                'name': c.name,
                'value': c.value,
                'domain': c.domain ?? '.furaffinity.net',
                'path': c.path ?? '/',
                'isHttpOnly': c.isHttpOnly,
                'isSecure': c.isSecure,
                'expiresDate': c.expiresDate ?? 0,
              })
          .toList();

      final mergedCookies = mergeCookiesForSession(
        sessionCookieMaps,
        webViewCookieMaps,
      );

      _session = UserSession(
        username: _session!.username,
        avatarUrl: _session!.avatarUrl,
        isLoggedIn: _session!.isLoggedIn,
        cookies: jsonEncode(mergedCookies),
      );

      debugPrint('=== Session updated with ${mergedCookies.length} cookies');
    } catch (e) {
      debugPrint('=== CF sync: error saving to session: $e');
    }
  }

  Future<void> _saveWebViewCookiesToCookieJar(
      List<Cookie> webViewCookies) async {
    await _ensureInitialized();

    final sessionCookieMaps = <Map<String, dynamic>>[];
    if (_session?.cookies != null) {
      try {
        final raw = jsonDecode(_session!.cookies!);
        sessionCookieMaps.addAll(
          raw.whereType<Map<String, dynamic>>().toList(),
        );
      } catch (e) {
        debugPrint('=== CF sync: error reading session cookies for jar: $e');
      }
    }

    final webViewCookieMaps = webViewCookies
        .where((c) => c.value.isNotEmpty)
        .map((c) => {
              'name': c.name,
              'value': c.value,
              'domain': c.domain ?? '.furaffinity.net',
              'path': c.path ?? '/',
              'isHttpOnly': c.isHttpOnly,
              'isSecure': c.isSecure,
              'expiresDate': c.expiresDate ?? 0,
            })
        .toList();

    final mergedCookies = mergeCookiesForSession(
      sessionCookieMaps,
      webViewCookieMaps,
    );

    final cookies = <io.Cookie>[];
    for (final entry in mergedCookies) {
      final name = entry['name']?.toString();
      final value = entry['value']?.toString();
      if (name == null || name.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      final cookie = io.Cookie(name, value);
      cookie.domain = entry['domain']?.toString() ?? '.furaffinity.net';
      cookie.path = entry['path']?.toString() ?? '/';
      cookie.secure = entry['isSecure'] as bool? ?? false;
      cookie.httpOnly = entry['isHttpOnly'] as bool? ?? false;
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
}
