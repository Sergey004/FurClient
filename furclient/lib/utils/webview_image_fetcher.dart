import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../main.dart' show webViewEnvironment;

/// Fetches images via HeadlessInAppWebView (one per fetch).
///
/// Problem: dart:io HttpClient and Dio have non-browser TLS fingerprints.
/// Cloudflare detects this and returns 403 for ALL requests to FA domains
/// (including CDN t.furaffinity.net).
///
/// Solution: HeadlessInAppWebView shares the same webViewEnvironment as the
/// login WebView, so it has the correct TLS fingerprint and cookies.
/// We navigate to each image URL directly, then use same-origin fetch() to
/// extract the binary data. No CORS issues because the fetch is same-origin.
///
/// Each image fetch creates a short-lived HeadlessInAppWebView (same pattern
/// as fa_client.dart _fetchHtmlWithWebView), processes sequentially via a
/// queue, and disposes after extraction.
class WebViewImageFetcher {
  static WebViewImageFetcher? _instance;
  static WebViewImageFetcher get instance =>
      _instance ??= WebViewImageFetcher._();
  WebViewImageFetcher._();

  // Sequential queue: one image at a time to avoid race conditions.
  final _queue = <_ImageRequest>[];
  bool _processing = false;

  // Simple in-memory cache (keyed by URL) to avoid re-fetching.
  final _cache = <String, Uint8List>{};
  static const int _maxCacheSize = 100;

  /// Fetch an image using a HeadlessInAppWebView.
  ///
  /// On non-Windows platforms or if webViewEnvironment is unavailable,
  /// returns null so the caller can fall back to HTTP.
  Future<Uint8List?> fetchImage(String url) async {
    if (!io.Platform.isWindows || webViewEnvironment == null) {
      return null;
    }

    // Check cache first
    final cached = _cache[url];
    if (cached != null) {
      debugPrint('=== WebViewImageFetcher: Cache hit for $url');
      return cached;
    }

    // Enqueue the request (sequential processing)
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
        final bytes = await _fetchSingleImage(request.url);
        if (!request.completer.isCompleted) request.completer.complete(bytes);
      } catch (e) {
        debugPrint('=== WebViewImageFetcher: Queue processing error: $e');
        if (!request.completer.isCompleted) request.completer.complete(null);
      }
    }

    _processing = false;
  }

  /// Create a HeadlessInAppWebView, navigate to the image URL,
  /// wait for onLoadStop, then extract bytes via evaluateJavascript.
  ///
  /// This matches the pattern used in fa_client.dart _fetchHtmlWithWebView:
  /// all callbacks are set in the constructor (v6 API).
  Future<Uint8List?> _fetchSingleImage(String url) async {
    final resultCompleter = Completer<Uint8List?>();
    HeadlessInAppWebView? headless;

    try {
      headless = HeadlessInAppWebView(
        webViewEnvironment: webViewEnvironment,
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
        ),
        onLoadStop: (controller, loadedUrl) async {
          try {
            // Check for CF challenge page
            final html = await controller.getHtml() ?? '';
            if (_isCloudflarePage(html) && html.length < 30000) {
              debugPrint(
                  '=== WebViewImageFetcher: CF challenge on image, waiting...');
              await Future.delayed(const Duration(seconds: 3));
              final retryHtml = await controller.getHtml() ?? '';
              if (_isCloudflarePage(retryHtml) &&
                  retryHtml.length < 30000) {
                if (!resultCompleter.isCompleted) {
                  resultCompleter.complete(null);
                }
                return;
              }
            }

            // Extract image bytes using synchronous XHR + base64.
            //
            // evaluateJavascript does NOT await Promises, so async fetch()
            // returns the Promise object itself (serialized as _Map).
            // Instead, use a synchronous XMLHttpRequest which returns
            // a plain string (base64) that the JS bridge can serialize safely.
            final result = await controller.evaluateJavascript(
              source: r'''
                (function() {
                  try {
                    var xhr = new XMLHttpRequest();
                    xhr.open('GET', location.href, false);
                    xhr.responseType = 'arraybuffer';
                    xhr.send();
                    if (xhr.status !== 200) return null;
                    var bytes = new Uint8Array(xhr.response);
                    var binary = '';
                    var chunk = 0x8000;
                    for (var i = 0; i < bytes.length; i += chunk) {
                      var slice = bytes.subarray(i, Math.min(i + chunk, bytes.length));
                      binary += String.fromCharCode.apply(null, slice);
                    }
                    return btoa(binary);
                  } catch(e) {
                    return null;
                  }
                })()
              ''',
            ).timeout(const Duration(seconds: 10));

            if (result == null || result is! String || result.isEmpty) {
              debugPrint(
                  '=== WebViewImageFetcher: XHR returned null for $url');
              if (!resultCompleter.isCompleted) resultCompleter.complete(null);
              return;
            }

            final data = base64Decode(result);

            debugPrint(
                '=== WebViewImageFetcher: Fetched ${data.length}B from $url');

            if (!resultCompleter.isCompleted) {
              resultCompleter.complete(data);
            }
          } catch (e) {
            debugPrint(
                '=== WebViewImageFetcher: onLoadStop processing error: $e');
            if (!resultCompleter.isCompleted) {
              resultCompleter.complete(null);
            }
          }
        },
        onReceivedHttpError: (controller, request, response) {
          if (!(request.isForMainFrame ?? false)) return;
          final status = response.statusCode ?? 0;
          if (status == 403 || status == 503) {
            debugPrint(
                '=== WebViewImageFetcher: HTTP $status loading $url');
            if (!resultCompleter.isCompleted) {
              resultCompleter.complete(null);
            }
          }
        },
        onReceivedError: (controller, request, error) {
          if (!(request.isForMainFrame ?? false)) return;
          debugPrint(
              '=== WebViewImageFetcher: Error loading $url: ${error.description}');
          if (!resultCompleter.isCompleted) {
            resultCompleter.complete(null);
          }
        },
        initialUrlRequest: URLRequest(
          url: WebUri(url),
        ),
      );

      await headless.run();

      final data = await resultCompleter.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint('=== WebViewImageFetcher: Timeout fetching $url');
          return null;
        },
      );

      // Cache the result
      if (data != null) {
        if (_cache.length >= _maxCacheSize) {
          _cache.remove(_cache.keys.first);
        }
        _cache[url] = data;
      }

      return data;
    } catch (e) {
      debugPrint('=== WebViewImageFetcher: Fetch error for $url: $e');
      return null;
    } finally {
      await headless?.dispose();
    }
  }

  bool _isCloudflarePage(String html) {
    final lower = html.toLowerCase();
    return lower.contains('just a moment') ||
        lower.contains('checking your browser') ||
        lower.contains('challenges.cloudflare.com') ||
        lower.contains('cf_chl_page') ||
        lower.contains('cf-turnstile') ||
        (lower.contains('cloudflare') &&
            (lower.contains('challenge') ||
                lower.contains('verify you are human')));
  }

  /// Clear the image cache.
  void clearCache() {
    _cache.clear();
    debugPrint('=== WebViewImageFetcher: Cache cleared');
  }

  /// Dispose the fetcher (clears queue and cache).
  Future<void> dispose() async {
    _queue.clear();
    _cache.clear();
    _processing = false;
    debugPrint('=== WebViewImageFetcher: Disposed');
  }
}

class _ImageRequest {
  final String url;
  final Completer<Uint8List?> completer;
  _ImageRequest(this.url, this.completer);
}
