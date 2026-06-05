import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cronet_http/cronet_http.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../utils/cookie_manager.dart';

/// Unified CDN Loader with multi-strategy approach
///
/// Features:
/// - Platform-specific strategies (Cronet, Proxy, HTTP Client)
/// - In-memory cache with 50 element limit
/// - Automatic fallback between strategies
/// - Cookie synchronization
/// - Request deduplication
///
/// Strategy order by platform:
/// - Android: Cronet → HTTP Client
/// - Windows: Proxy → HTTP Client
/// - iOS/macOS/Linux: HTTP Client
class CDNLoader {
  static CDNLoader? _instance;
  static CDNLoader get instance => _instance ??= CDNLoader._();

  CDNLoader._();

  // ── Cache ────────────────────────────────────────────────────────
  final Map<String, Uint8List> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const int _maxCacheSize = 50;
  static const Duration _cacheTimeout = Duration(minutes: 30);

  // ── State ────────────────────────────────────────────────────────
  InAppWebViewController? _webViewController;
  bool _isInitialized = false;
  final Map<String, Completer<Uint8List?>> _pendingRequests = {};

  // ── Cronet client (Android) ──────────────────────────────────────
  http.Client? _cronetClient;
  bool get _isCronetAvailable => _isAndroid && _cronetClient != null;

  // ── Platform detection ───────────────────────────────────────────
  bool get _isWindows => !kIsWeb && Platform.isWindows;
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  // ── Initialization ───────────────────────────────────────────────

  /// Initialize the CDN loader
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('=== CDNLoader: Initializing...');

    // Load cookies from persistent storage
    await FAICookieManager.loadCookies();

    // Initialize Cronet on Android
    if (_isAndroid) {
      await _initializeCronet();
    }

    // Start proxy on Windows
    if (_isWindows) {
      debugPrint('=== CDNLoader: Platform=Windows, using proxy strategy');
    } else if (_isAndroid) {
      debugPrint('=== CDNLoader: Platform=Android, using Cronet strategy');
    } else {
      debugPrint('=== CDNLoader: Platform=${Platform.operatingSystem}, using HTTP strategy');
    }

    _isInitialized = true;
    debugPrint('=== CDNLoader: Initialized (cache: ${_cache.length} items)');
  }

  /// Initialize Cronet client for Android with optimizations
  Future<void> _initializeCronet() async {
    try {
      // Create Cronet engine with optimizations
      final cronetEngine = CronetEngine.build(
        userAgent: 'FurClient/1.0',
        enableHttp2: true,
        enableQuic: true,
        enableBrotli: true,
      );

      _cronetClient = CronetClient.fromCronetEngine(cronetEngine);
      debugPrint('=== CDNLoader: Cronet initialized with HTTP/2, QUIC, Brotli');
    } catch (e) {
      debugPrint('=== CDNLoader: Cronet initialization failed: $e');
      _cronetClient = null;
    }
  }

  /// Set WebView controller for cookie synchronization
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    debugPrint('=== CDNLoader: WebView controller set');
  }

  // ── Main load method ─────────────────────────────────────────────

  /// Load content from CDN with automatic strategy selection
  ///
  /// Returns [Uint8List] if successful, null if all strategies fail.
  /// Request deduplication: concurrent requests for the same URL share the result.
  Future<Uint8List?> load(
    String url, {
    Map<String, String>? headers,
    bool useCache = true,
  }) async {
    debugPrint('=== CDNLoader: Loading $url');

    // 1. Check cache
    if (useCache) {
      final cached = _getFromCache(url);
      if (cached != null) {
        debugPrint('=== CDNLoader: Cache hit ($url)');
        return cached;
      }
    }

    // 2. Deduplicate concurrent requests
    if (_pendingRequests.containsKey(url)) {
      debugPrint('=== CDNLoader: Deduplicating request for $url');
      return await _pendingRequests[url]!.future;
    }

    final completer = Completer<Uint8List?>();
    _pendingRequests[url] = completer;

    try {
      final result = await _loadWithStrategies(url, headers ?? {});

      // Cache successful result
      if (result != null && useCache) {
        _addToCache(url, result);
      }

      completer.complete(result);
      return result;
    } catch (e) {
      debugPrint('=== CDNLoader: All strategies failed for $url: $e');
      completer.complete(null);
      return null;
    } finally {
      _pendingRequests.remove(url);
    }
  }

  // ── Strategy selection ───────────────────────────────────────────

  /// Try loading with platform-specific strategies in order
  Future<Uint8List?> _loadWithStrategies(String url, Map<String, String> headers) async {
    final allHeaders = _buildHeaders(headers);

    // Strategy 1: Platform-specific optimized client
    if (_isAndroid && _isCronetAvailable) {
      // On Android, use Cronet for optimized HTTP/2, QUIC, Brotli
      final result = await _loadWithCronet(url, allHeaders);
      if (result != null) return result;
    } else if (_isWindows) {
      // On Windows, try proxy first, then HTTP client
      final result = await _loadWithProxy(url);
      if (result != null) return result;
    } else {
      // On iOS/macOS/Linux, use HTTP client
      final result = await _loadWithHttpClient(url, allHeaders);
      if (result != null) return result;
    }

    // Strategy 2: WebView fallback
    final webViewResult = await _loadWithWebView(url, allHeaders);
    if (webViewResult != null) return webViewResult;

    // Strategy 3: Standard HTTP client as final fallback
    if (_isWindows || _isAndroid) {
      final httpResult = await _loadWithHttpClient(url, allHeaders);
      if (httpResult != null) return httpResult;
    }

    return null;
  }

  // ── Strategy: HTTP Client ────────────────────────────────────────

  /// Load using dart:http client
  Future<Uint8List?> _loadWithHttpClient(String url, Map<String, String> headers) async {
    try {
      final cookieHeader = await _getCookieHeader(url);
      if (cookieHeader != null) {
        headers['Cookie'] = cookieHeader;
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('HTTP client timeout'),
      );

      if (response.statusCode == 200) {
        _updateCookiesFromResponse(url, response.headers);
        debugPrint('=== CDNLoader: HTTP client success ($url)');
        return response.bodyBytes;
      }

      debugPrint('=== CDNLoader: HTTP client returned ${response.statusCode} for $url');
      return null;
    } catch (e) {
      debugPrint('=== CDNLoader: HTTP client failed for $url: $e');
      return null;
    }
  }

  // ── Strategy: Cronet (Android) ───────────────────────────────────

  /// Load using Cronet client (Android only)
  Future<Uint8List?> _loadWithCronet(String url, Map<String, String> headers) async {
    try {
      final cookieHeader = await _getCookieHeader(url);
      if (cookieHeader != null) {
        headers['Cookie'] = cookieHeader;
      }

      final request = http.Request('GET', Uri.parse(url))
        ..headers.addAll(headers);

      final response = await _cronetClient!.send(request).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Cronet timeout'),
      );

      if (response.statusCode == 200) {
        final bytes = await response.stream.toBytes();
        _updateCookiesFromResponse(url, response.headers);
        debugPrint('=== CDNLoader: Cronet success ($url)');
        return bytes;
      }

      debugPrint('=== CDNLoader: Cronet returned ${response.statusCode} for $url');
      return null;
    } catch (e) {
      debugPrint('=== CDNLoader: Cronet failed for $url: $e');
      return null;
    }
  }

  // ── Strategy: WebView ────────────────────────────────────────────

  /// Load using InAppWebView (for Cloudflare-protected content)
  Future<Uint8List?> _loadWithWebView(String url, Map<String, String> headers) async {
    if (_webViewController == null) {
      debugPrint('=== CDNLoader: WebView not available');
      return null;
    }

    try {
      // Sync cookies to WebView first
      await _syncCookiesToWebView(url);

      final result = await _webViewController!.evaluateJavascript(
        source: '''
          (async () => {
            try {
              const response = await fetch('$url', {
                method: 'GET',
                credentials: 'include'
              });

              if (!response.ok) return null;

              const buffer = await response.arrayBuffer();
              const array = new Uint8Array(buffer);
              return Array.from(array);
            } catch (e) {
              return null;
            }
          })()
        ''',
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('WebView timeout'),
      );

      if (result != null && result is List) {
        final bytes = Uint8List.fromList(result.cast<int>());
        if (bytes.isNotEmpty) {
          debugPrint('=== CDNLoader: WebView success ($url)');
          _updateCookiesFromWebView();
          return bytes;
        }
      }

      return null;
    } catch (e) {
      debugPrint('=== CDNLoader: WebView failed for $url: $e');
      return null;
    }
  }

  // ── Strategy: Local Proxy (Windows) ──────────────────────────────

  /// Load using local HTTP proxy (Windows-specific)
  Future<Uint8List?> _loadWithProxy(String url) async {
    try {
      final proxyUrl = 'http://127.0.0.1:47652/fa-proxy?url=${Uri.encodeComponent(url)}';

      final response = await http.get(
        Uri.parse(proxyUrl),
        headers: {
          'User-Agent': 'FurClient/1.0',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Proxy timeout'),
      );

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        debugPrint('=== CDNLoader: Proxy success ($url)');
        return response.bodyBytes;
      }

      return null;
    } catch (e) {
      debugPrint('=== CDNLoader: Proxy failed for $url: $e');
      return null;
    }
  }

  // ── Cache management ─────────────────────────────────────────────

  /// Get item from cache if not expired
  Uint8List? _getFromCache(String url) {
    if (!_cache.containsKey(url)) return null;

    final timestamp = _cacheTimestamps[url];
    if (timestamp == null) {
      _cache.remove(url);
      return null;
    }

    if (DateTime.now().difference(timestamp) > _cacheTimeout) {
      _cache.remove(url);
      _cacheTimestamps.remove(url);
      return null;
    }

    return _cache[url];
  }

  /// Add item to cache with LRU eviction
  void _addToCache(String url, Uint8List data) {
    // Evict oldest if at capacity
    if (_cache.length >= _maxCacheSize) {
      _evictOldest();
    }

    _cache[url] = data;
    _cacheTimestamps[url] = DateTime.now();
  }

  /// Evict oldest cache entry (LRU)
  void _evictOldest() {
    if (_cacheTimestamps.isEmpty) return;

    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in _cacheTimestamps.entries) {
      if (oldestTime == null || entry.value.isBefore(oldestTime)) {
        oldestTime = entry.value;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
      debugPrint('=== CDNLoader: Evicted cache entry: $oldestKey');
    }
  }

  /// Clear entire cache
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    debugPrint('=== CDNLoader: Cache cleared');
  }

  /// Clean expired cache entries
  void cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) > _cacheTimeout) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _cache.remove(key);
      _cacheTimestamps.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint('=== CDNLoader: Cleaned ${expiredKeys.length} expired cache entries');
    }
  }

  // ── Cookie helpers ───────────────────────────────────────────────

  /// Build request headers
  Map<String, String> _buildHeaders(Map<String, String> extra) {
    return {
      'User-Agent': 'FurClient/1.0',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      ...extra,
    };
  }

  /// Get cookie header string for URL
  Future<String?> _getCookieHeader(String url) async {
    try {
      final cookies = await FAICookieManager.getCookiesForUrl(url);
      if (cookies.isEmpty) return null;
      return cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (e) {
      return null;
    }
  }

  /// Update cookies from HTTP response
  void _updateCookiesFromResponse(String url, Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie != null) {
      final uri = Uri.parse(url);
      FAICookieManager.parseAndStoreCookies(setCookie, uri.host);
    }
  }

  /// Sync cookies from WebView to CookieManager
  Future<void> _updateCookiesFromWebView() async {
    if (_webViewController == null) return;

    try {
      await FAICookieManager.syncFromWebView(_webViewController!);
    } catch (e) {
      debugPrint('=== CDNLoader: WebView cookie sync failed: $e');
    }
  }

  /// Sync cookies from CookieManager to WebView
  Future<void> _syncCookiesToWebView(String url) async {
    if (_webViewController == null) return;

    try {
      await FAICookieManager.syncToWebView(_webViewController!, url);
    } catch (e) {
      debugPrint('=== CDNLoader: Cookie sync to WebView failed: $e');
    }
  }

  // ── Public getters ───────────────────────────────────────────────

  /// Current cache size
  int get cacheSize => _cache.length;

  /// Maximum cache size
  int get maxCacheSize => _maxCacheSize;

  /// Check if URL is a CDN URL
  static bool isCDNUrl(String url) {
    return url.contains('t.furaffinity.net') ||
        url.contains('d.furaffinity.net') ||
        url.contains('a.furaffinity.net');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int valid = 0;
    int expired = 0;

    for (final timestamp in _cacheTimestamps.values) {
      if (now.difference(timestamp) > _cacheTimeout) {
        expired++;
      } else {
        valid++;
      }
    }

    return {
      'total': _cache.length,
      'valid': valid,
      'expired': expired,
      'maxSize': _maxCacheSize,
      'timeoutMinutes': _cacheTimeout.inMinutes,
    };
  }

  // ── Cleanup ──────────────────────────────────────────────────────

  /// Dispose resources
  void dispose() {
    _cronetClient?.close();
    _cronetClient = null;
    _cache.clear();
    _cacheTimestamps.clear();
    _pendingRequests.clear();
    debugPrint('=== CDNLoader: Disposed');
  }
}

/// Extension for CDN URL helpers
extension CDNUrlExtension on String {
  /// Check if this URL is a CDN URL
  bool get isCDNUrl => CDNLoader.isCDNUrl(this);

  /// Convert to full CDN URL if needed
  String toFullCDNUrl() {
    if (startsWith('http://') || startsWith('https://')) return this;
    return 'https://t.furaffinity.net/$this';
  }
}
