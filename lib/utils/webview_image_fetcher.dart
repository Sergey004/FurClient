import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'cookie_store.dart';
import '../main.dart' show webViewEnvironment;

/// Извлекает байты картинок через headless WebView.
///
/// Трюк same-origin: навигация на URL картинки → fetch(window.location.href)
/// → blob → data URL → back через JS-хендлер. Прямой fetch со стороннего
/// origin заблокировал бы CORS, поэтому WebView обязан находиться на самом
/// URL картинки — а значит один WebView = одна картинка за раз.
///
/// Параллелизм достигается пулом воркеров: каждый держит свой WebView.
/// До пула общая очередь была строго последовательной и гриды грузили
/// картинки по одной.
class WebViewImageFetcher {
  static WebViewImageFetcher? _instance;
  static WebViewImageFetcher get instance =>
      _instance ??= WebViewImageFetcher._();
  WebViewImageFetcher._();

  /// Размер пула. 2 = двойная пропускная способность без заметного
  /// расхода памяти (каждый headless WebView — отдельный процесс рендера).
  static const int _workerCount = 2;

  final List<_ImageWorker> _workers = [];
  final _queue = <_ImageRequest>[];

  /// Shared in-memory cache (200 записей, FIFO-вытеснение).
  final _cache = <String, Uint8List>{};
  static const int _maxCacheSize = 200;

  Future<Uint8List?> fetchImage(String url) async {
    // webViewEnvironment нужен только на Windows (WebView2).
    if (io.Platform.isWindows && webViewEnvironment == null) return null;

    final cached = _cache[url];
    if (cached != null) {
      debugPrint('=== WebViewImageFetcher: Cache hit for $url');
      return cached;
    }

    final completer = Completer<Uint8List?>();
    _queue.add(_ImageRequest(url, completer));
    _dispatch();
    return completer.future;
  }

  /// Раздаёт очередь свободным воркерам, при нехватке заводит новых (до N).
  void _dispatch() {
    while (_queue.isNotEmpty) {
      var worker = _idleWorker();
      worker ??= _maybeCreateWorker();
      if (worker == null) break; // все заняты — разберутся по мере freeing
      final request = _queue.removeAt(0);
      _run(worker, request);
    }
  }

  _ImageWorker? _idleWorker() {
    for (final w in _workers) {
      if (!w.busy) return w;
    }
    return null;
  }

  _ImageWorker? _maybeCreateWorker() {
    if (_workers.length >= _workerCount) return null;
    final worker = _ImageWorker(_workers.length);
    _workers.add(worker);
    debugPrint(
        '=== WebViewImageFetcher: worker #${worker.index} created (${_workers.length}/$_workerCount)');
    return worker;
  }

  Future<void> _run(_ImageWorker worker, _ImageRequest request) async {
    worker.busy = true;
    try {
      final data = await worker.fetch(request.url, _cache, _maxCacheSize);
      if (!request.completer.isCompleted) request.completer.complete(data);
    } catch (e) {
      debugPrint('=== WebViewImageFetcher: worker #${worker.index} error: $e');
      if (!request.completer.isCompleted) request.completer.complete(null);
    } finally {
      worker.busy = false;
      // Воркер освободился — раздать следующий кусок очереди.
      _dispatch();
    }
  }

  /// Clear the image cache.
  void clearCache() {
    _cache.clear();
  }

  /// Quick reset — глушит всех воркеров; следующие fetch пересоздадут пул.
  Future<void> reset() async {
    for (final request in _queue) {
      if (!request.completer.isCompleted) request.completer.complete(null);
    }
    _queue.clear();
    _cache.clear();
    for (final worker in _workers) {
      await worker.dispose();
    }
    _workers.clear();
    debugPrint('=== WebViewImageFetcher: Reset (pool re-created on next fetch)');
  }

  /// Full dispose пула.
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

/// Один WebView-воркер пула.
class _ImageWorker {
  final int index;
  bool busy = false;

  HeadlessInAppWebView? _headless;
  InAppWebViewController? _controller;
  bool _ready = false;
  bool _initializing = false;

  /// Completer ТЕКУЩЕЙ извлекаемой картинки (у каждого воркера свой —
  /// хендлер и колбеки замыкаются на него).
  Completer<String?>? _currentImageCompleter;

  /// Подряд идущие неудачи — >= 3, WebView считается мёртвым, пересоздаём.
  int _consecutiveFailures = 0;

  _ImageWorker(this.index);

  /// Navigate this worker's WebView to the image URL,
  /// wait for onLoadStop → canvas/fetch extraction → handler callback.
  Future<Uint8List?> fetch(
      String url, Map<String, Uint8List> cache, int maxCacheSize) async {
    await _ensureReady();
    if (!_ready || _controller == null) {
      debugPrint(
          '=== WebViewImageFetcher#$index: WebView not ready, skipping $url');
      _consecutiveFailures++;
      _maybeAutoReset();
      return null;
    }
    // Completer ставится ДО loadUrl, чтобы колбеки могли его завершить.
    _currentImageCompleter = Completer<String?>();

    try {
      // On Android, HeadlessInAppWebView has its own cookie jar.
      // The login WebView's cookies are in CookieStore but NOT shared with
      // this HeadlessInAppWebView. Inject them via CookieManager.
      if (!io.Platform.isWindows) {
        await _injectCookies(url);
      }

      debugPrint('=== WebViewImageFetcher#$index: Loading URL: $url');
      await _controller!.loadUrl(
        urlRequest: URLRequest(url: WebUri(url)),
      );

      // Wait for: onLoadStop → fetch/canvas JS → handler callback.
      // Longer timeout for large files (video can be 100+ MB).
      final dataUrl = await _currentImageCompleter!.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('=== WebViewImageFetcher#$index: Timeout for $url');
          return null;
        },
      );

      if (dataUrl == null || dataUrl.isEmpty) {
        _consecutiveFailures++;
        debugPrint(
            '=== WebViewImageFetcher#$index: No data for $url (failures: $_consecutiveFailures)');
        _maybeAutoReset();
        return null;
      }

      final b64 = dataUrl.substring(dataUrl.indexOf(',') + 1);
      final data = base64Decode(b64);

      _consecutiveFailures = 0; // Reset on success
      if (cache.length >= maxCacheSize) cache.remove(cache.keys.first);
      cache[url] = data;

      debugPrint('=== WebViewImageFetcher#$index: ${data.length}B from $url');
      return data;
    } catch (e) {
      debugPrint('=== WebViewImageFetcher#$index: Error for $url: $e');
      _consecutiveFailures++;
      _maybeAutoReset();
      return null;
    } finally {
      _currentImageCompleter = null;
    }
  }

  /// Auto-reset if too many consecutive failures (dead WebView).
  void _maybeAutoReset() {
    if (_consecutiveFailures >= 3) {
      debugPrint(
          '=== WebViewImageFetcher#$index: $_consecutiveFailures consecutive failures, auto-resetting');
      _consecutiveFailures = 0;
      Future.microtask(() => dispose());
    }
  }

  /// Create the persistent HeadlessInAppWebView (once).
  /// Starts on about:blank. The JS handler is registered in onWebViewCreated.
  Future<void> _ensureReady() async {
    if (_ready && _headless != null && _controller != null) return;
    if (_initializing) {
      while (_initializing) {
        await Future.delayed(const Duration(milliseconds: 50));
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
          debugPrint(
              '=== WebViewImageFetcher#$index: Persistent WebView created');

          // Register handler ONCE. It will be used for all images.
          controller.addJavaScriptHandler(
            handlerName: '_imgB64',
            callback: (args) {
              final completer = _currentImageCompleter;
              if (completer == null || completer.isCompleted) return;
              try {
                if (args.isNotEmpty && args[0] is String) {
                  final val = args[0] as String;
                  // Accept any data URL (image, video, audio, text, etc.)
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
            // Small delay to ensure content is loaded.
            await Future.delayed(const Duration(milliseconds: 100));

            // Strategy 1: fetch() raw bytes — works for ALL file types
            // (images, video, audio, text). Preserves original format.
            await controller.evaluateJavascript(
              source: r'''
                (async function() {
                  // Try fetch first — gets raw bytes for any file type
                  try {
                    var resp = await fetch(window.location.href);
                    if (resp && resp.ok) {
                      var blob = await resp.blob();
                      var reader = new FileReader();
                      reader.onloadend = function() {
                        window.flutter_inappwebview.callHandler('_imgB64',
                          reader.result);
                      };
                      reader.onerror = function() {
                        window.flutter_inappwebview.callHandler('_imgB64', '');
                      };
                      reader.readAsDataURL(blob);
                      return;
                    }
                  } catch(e) {}

                  // Fallback: canvas extraction (images only)
                  try {
                    var img = document.images[0];
                    if (img && img.naturalWidth > 0) {
                      var c = document.createElement('canvas');
                      c.width = img.naturalWidth;
                      c.height = img.naturalHeight;
                      c.getContext('2d').drawImage(img, 0, 0);
                      var url = window.location.href || '';
                      var mime = 'image/png';
                      var qual = undefined;
                      if (/\.jpe?g$/i.test(url)) { mime = 'image/jpeg'; qual = 1.0; }
                      else if (/\.webp$/i.test(url)) { mime = 'image/webp'; qual = 1.0; }
                      window.flutter_inappwebview.callHandler('_imgB64',
                        c.toDataURL(mime, qual));
                      return;
                    }
                  } catch(e) {}

                  window.flutter_inappwebview.callHandler('_imgB64', '');
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
          debugPrint(
              '=== WebViewImageFetcher#$index: HTTP error $status for ${request.url}');
          if (status == 403 || status == 503) {
            final completer = _currentImageCompleter;
            if (completer != null && !completer.isCompleted) {
              completer.complete(null);
            }
          }
        },
        onReceivedError: (controller, request, error) {
          if (!(request.isForMainFrame ?? false)) return;
          debugPrint(
              '=== WebViewImageFetcher#$index: WebView error: ${error.description}');
          final completer = _currentImageCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete(null);
          }
        },
        initialUrlRequest: URLRequest(url: WebUri('about:blank')),
      );

      await _headless!.run();

      // Wait for about:blank to load (onLoadStop fires).
      try {
        await initCompleter.future.timeout(const Duration(seconds: 5));
        _ready = true;
        debugPrint('=== WebViewImageFetcher#$index: Persistent WebView ready');
      } on TimeoutException {
        _ready = false;
        debugPrint(
            '=== WebViewImageFetcher#$index: Init timeout — WebView may be dead');
      }
    } catch (e) {
      debugPrint('=== WebViewImageFetcher#$index: Init error: $e');
      _ready = false;
    } finally {
      _initializing = false;
    }
  }

  /// Inject cookies from CookieStore into this WebView's cookie jar.
  /// Required on Android where each WebView instance has its own cookie store.
  /// On Windows, cookies are shared via webViewEnvironment.
  Future<void> _injectCookies(String url) async {
    final cookieHeader = CookieStore.instance.cookieHeader;
    if (cookieHeader == null || cookieHeader.isEmpty) {
      debugPrint('=== WebViewImageFetcher#$index: No cookies in CookieStore');
      return;
    }

    final cm = CookieManager.instance();
    final uri = Uri.parse(url);
    final cookies = cookieHeader.split('; ');

    // Inject cookies for the target domain AND the base domain
    // (.furaffinity.net) to cover cf_clearance which is set on the apex.
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
          debugPrint('=== WebViewImageFetcher#$index: Cookie inject error: $e');
        }
      }
    }
    debugPrint(
        '=== WebViewImageFetcher#$index: Injected ${cookies.length} cookies for $domains');
  }

  Future<void> dispose() async {
    _currentImageCompleter?.complete(null);
    _currentImageCompleter = null;
    _ready = false;
    _initializing = false;
    _consecutiveFailures = 0;
    await _headless?.dispose();
    _headless = null;
    _controller = null;
  }
}
