import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../main.dart' show webViewEnvironment;
import 'cookie_store.dart';

/// Fetches images via a SINGLE persistent HeadlessInAppWebView.
///
/// Problem: dart:io HttpClient and Dio have non-browser TLS fingerprints.
/// Cloudflare detects this and returns 403 for ALL requests to FA domains
/// (including CDN t.furaffinity.net).
///
/// Solution: ONE HeadlessInAppWebView shares the same webViewEnvironment as
/// the login WebView. It stays alive and navigates to each image URL
/// sequentially via controller.loadUrl(). No create/dispose per image.
///
/// Strategy (per image):
/// 1. controller.loadUrl(imageUrl)  — WebView renders the image natively.
/// 2. onLoadStop fires  — extract via <canvas> + toDataURL().
///    (Image is already rendered, no network re-fetch needed.)
/// 3. addJavaScriptHandler passes base64 data URL back to Dart.
///
/// Why canvas and not XHR/fetch?
/// WebView2 renders raw image URLs as "resource documents". XHR/fetch don't
/// work in that context. But <canvas> captures the already-rendered image
/// via document.images[0]. Same-origin (no CORS issues since the page origin
/// IS the image URL).
class WebViewImageFetcher {
  static WebViewImageFetcher? _instance;
  static WebViewImageFetcher get instance =>
      _instance ??= WebViewImageFetcher._();
  WebViewImageFetcher._();

  /// Single persistent HeadlessInAppWebView.
  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  bool _ready = false;
  bool _initializing = false;

  /// Sequential queue: one image at a time.
  final _queue = <_ImageRequest>[];
  bool _processing = false;

  /// In-memory cache.
  final _cache = <String, Uint8List>{};
  static const int _maxCacheSize = 200;

  /// Completer for the CURRENT image being extracted.
  /// Set before loadUrl(), completed by the JS handler or error callbacks.
  Completer<String?>? _currentImageCompleter;

  /// Consecutive failure counter — if >= 3, auto-reset the WebView.
  int _consecutiveFailures = 0;

  Future<Uint8List?> fetchImage(String url) async {
    // webViewEnvironment is only needed on Windows (WebView2).
    // On Android, HeadlessInAppWebView works without it.
    if (io.Platform.isWindows && webViewEnvironment == null) return null;

    final cached = _cache[url];
    if (cached != null) {
      debugPrint('=== WebViewImageFetcher: Cache hit for $url');
      return cached;
    }

    final completer = Completer<Uint8List?>();
    _queue.add(_ImageRequest(url, completer));
    _processQueue();
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_processing) return;
    _processing = true;

    while (_queue.isNotEmpty) {
      final request = _queue.removeAt(0);
      try {
        await _ensureReady();
        if (_controller == null || !_ready) {
          debugPrint('=== WebViewImageFetcher: WebView not ready, skipping');
          if (!request.completer.isCompleted) request.completer.complete(null);
          _consecutiveFailures++;
          _maybeAutoReset();
          continue;
        }
        final data = await _fetchSingleImage(request.url);
        if (!request.completer.isCompleted) request.completer.complete(data);
      } catch (e) {
        debugPrint('=== WebViewImageFetcher: Queue error: $e');
        if (!request.completer.isCompleted) request.completer.complete(null);
        _consecutiveFailures++;
        _maybeAutoReset();
      }
    }

    _processing = false;
  }

  /// Auto-reset if too many consecutive failures (dead WebView).
  void _maybeAutoReset() {
    if (_consecutiveFailures >= 3) {
      debugPrint('=== WebViewImageFetcher: $_consecutiveFailures consecutive failures, auto-resetting');
      _consecutiveFailures = 0;
      // Schedule async reset (don't block current queue processing)
      Future.microtask(() async {
        await reset();
      });
    }
  }

  /// Create the persistent HeadlessInAppWebView (once).
  /// Starts on about:blank. The JS handler is registered in onWebViewCreated.
  Future<void> _ensureReady() async {
    if (_ready && _headless != null && _controller != null) return;
    if (_initializing) {
      while (_initializing) {
        await Future.delayed(Duration(milliseconds: 50));
      }
      return;
    }

    _initializing = true;
    try {
      await _headless?.dispose();
      _headless = null;
      _controller = null;
      _ready = false;

      final initCompleter = Completer<void>();

      _headless = HeadlessInAppWebView(
        webViewEnvironment: webViewEnvironment,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
        ),
        onWebViewCreated: (controller) {
          _controller = controller;
          debugPrint('=== WebViewImageFetcher: Persistent WebView created');

          // Register handler ONCE. It will be used for all images.
          controller.addJavaScriptHandler(
            handlerName: '_imgB64',
            callback: (args) {
              final completer = _currentImageCompleter;
              if (completer == null || completer.isCompleted) return;
              try {
                if (args.isNotEmpty && args[0] is String) {
                  final val = args[0] as String;
                  if (val.startsWith('data:') && val.contains(',')) {
                    completer.complete(val);
                    return;
                  }
                }
              } catch (e) {
                debugPrint('=== WebViewImageFetcher: Handler error: $e');
              }
              completer.complete(null);
            },
          );
        },
        onLoadStop: (controller, loadedUrl) async {
          final completer = _currentImageCompleter;

          // If no image is being awaited, just mark init as done.
          if (completer == null || completer.isCompleted) {
            if (!initCompleter.isCompleted) initCompleter.complete();
            return;
          }

          try {
            // Small delay to ensure the image is fully painted.
            await Future.delayed(Duration(milliseconds: 100));

            // Extract via canvas. The image is already rendered by WebView2.
            await controller.evaluateJavascript(
              source: r'''
                (function() {
                  try {
                    var img = document.images[0];
                    if (img && img.naturalWidth > 0) {
                      var c = document.createElement('canvas');
                      c.width = img.naturalWidth;
                      c.height = img.naturalHeight;
                      c.getContext('2d').drawImage(img, 0, 0);
                      window.flutter_inappwebview.callHandler('_imgB64',
                        c.toDataURL('image/png'));
                      return;
                    }
                    window.flutter_inappwebview.callHandler('_imgB64', '');
                  } catch(e) {
                    window.flutter_inappwebview.callHandler('_imgB64', '');
                  }
                })()
              ''',
            );
          } catch (e) {
            debugPrint('=== WebViewImageFetcher: JS eval error: $e');
            if (!completer.isCompleted) completer.complete(null);
          }
        },
        onReceivedHttpError: (controller, request, response) {
          if (!(request.isForMainFrame ?? false)) return;
          final status = response.statusCode ?? 0;
          debugPrint('=== WebViewImageFetcher: HTTP error $status for ${request.url}');
          if (status == 403 || status == 503) {
            final completer = _currentImageCompleter;
            if (completer != null && !completer.isCompleted) {
              completer.complete(null);
            }
          }
        },
        onReceivedError: (controller, request, error) {
          if (!(request.isForMainFrame ?? false)) return;
          debugPrint('=== WebViewImageFetcher: WebView error: ${error.description}');
          final completer = _currentImageCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete(null);
          }
        },
        initialUrlRequest: URLRequest(url: WebUri('about:blank')),
      );

      await _headless!.run();

      // Wait for about:blank to load (onLoadStop fires).
      final initResult = await initCompleter.future.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          debugPrint('=== WebViewImageFetcher: Init timeout — WebView may be dead');
          return false;
        },
      );

      if (initResult == false) {
        // about:blank never loaded — WebView is broken
        _ready = false;
        debugPrint('=== WebViewImageFetcher: Init failed (timeout), marking as not ready');
      } else {
        _ready = true;
        debugPrint('=== WebViewImageFetcher: Persistent WebView ready');
      }
    } catch (e) {
      debugPrint('=== WebViewImageFetcher: Init error: $e');
      _ready = false;
    } finally {
      _initializing = false;
    }
  }

  /// Navigate the persistent WebView to the image URL,
  /// wait for onLoadStop → canvas extraction → handler callback.
  Future<Uint8List?> _fetchSingleImage(String url) async {
    // Set completer BEFORE loadUrl so callbacks can complete it.
    _currentImageCompleter = Completer<String?>();

    try {
      // On Android, HeadlessInAppWebView has its own cookie jar.
      // The login WebView's cookies are in CookieStore but NOT shared with
      // this HeadlessInAppWebView. Inject them via CookieManager.
      if (!io.Platform.isWindows) {
        await _injectCookies(url);
      }

      debugPrint('=== WebViewImageFetcher: Loading URL: $url');
      await _controller!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );

      // Wait for: onLoadStop → canvas JS → handler callback.
      final dataUrl = await _currentImageCompleter!.future.timeout(
        Duration(seconds: 15),
        onTimeout: () {
          debugPrint('=== WebViewImageFetcher: Timeout for $url');
          return null;
        },
      );

      if (dataUrl == null || dataUrl.isEmpty) {
        _consecutiveFailures++;
        debugPrint('=== WebViewImageFetcher: No data for $url (failures: $_consecutiveFailures)');
        _maybeAutoReset();
        return null;
      }

      final b64 = dataUrl.substring(dataUrl.indexOf(',') + 1);
      final data = base64Decode(b64);

      // Cache
      _consecutiveFailures = 0; // Reset on success
      if (_cache.length >= _maxCacheSize) _cache.remove(_cache.keys.first);
      _cache[url] = data;

      debugPrint('=== WebViewImageFetcher: ${data.length}B from $url');
      return data;
    } catch (e) {
      debugPrint('=== WebViewImageFetcher: Error for $url: $e');
      _consecutiveFailures++;
      _maybeAutoReset();
      return null;
    } finally {
      _currentImageCompleter = null;
    }
  }

  /// Inject cookies from CookieStore into the HeadlessInAppWebView's cookie jar.
  /// Required on Android where each WebView instance has its own cookie store.
  /// On Windows, cookies are shared via webViewEnvironment.
  Future<void> _injectCookies(String url) async {
    final cookieHeader = CookieStore.instance.cookieHeader;
    if (cookieHeader == null || cookieHeader.isEmpty) {
      debugPrint('=== WebViewImageFetcher: No cookies in CookieStore');
      return;
    }

    final cm = CookieManager.instance();
    final uri = Uri.parse(url);
    final cookies = cookieHeader.split('; ');

    // Inject cookies for the target domain AND the base domain (.furaffinity.net)
    // to cover cf_clearance which is set on .furaffinity.net.
    final domains = <String>{uri.host};
    if (uri.host.contains('.furaffinity.net')) {
      domains.add('.furaffinity.net');
    }

    for (final domain in domains) {
      for (final cookie in cookies) {
        final eqIdx = cookie.indexOf('=');
        if (eqIdx < 0) continue;
        final name = cookie.substring(0, eqIdx).trim();
        final value = cookie.substring(eqIdx + 1).trim();
        try {
          await cm.setCookie(
            url: WebUri('${uri.scheme}://$domain'),
            name: name,
            value: value,
            domain: domain,
            path: '/',
          );
        } catch (e) {
          debugPrint('=== WebViewImageFetcher: Cookie inject error: $e');
        }
      }
    }
    debugPrint('=== WebViewImageFetcher: Injected ${cookies.length} cookies for $domains');
  }

  /// Clear the image cache.
  void clearCache() {
    _cache.clear();
  }

  /// Quick reset — disposes the dead WebView so next fetchImage() reinitializes.
  Future<void> reset() async {
    _queue.clear();
    _cache.clear();
    _currentImageCompleter?.complete(null);
    _currentImageCompleter = null;
    _processing = false;
    _ready = false;
    _initializing = false;
    _consecutiveFailures = 0;
    await _headless?.dispose();
    _headless = null;
    _controller = null;
    debugPrint('=== WebViewImageFetcher: Reset (WebView will be re-created on next fetch)');
  }

  /// Full dispose the persistent WebView and clear everything.
  Future<void> dispose() async {
    await reset();
    debugPrint('=== WebViewImageFetcher: Disposed');
  }
}

class _ImageRequest {
  final String url;
  final Completer<Uint8List?> completer;
  _ImageRequest(this.url, this.completer);
}
