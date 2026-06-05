import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/cookie_manager.dart';

/// CDN Content Fetcher with multi-strategy approach
/// 
/// Uses:
/// - Cronet for efficient HTTP requests (Android, ChromeOS)
/// - InAppWebView for WebView rendering and cookie management
/// - Platform-specific fallbacks (WebView2 on Windows)
class CDNContentFetcher {
  static CDNContentFetcher? _instance;
  static CDNContentFetcher get instance => _instance ??= CDNContentFetcher._();
  
  CDNContentFetcher._();
  
  // Controllers and state
  InAppWebViewController? _webViewController;
  final Map<String, String> _cookieCache = {};
  final Map<String, DateTime> _cookieTimestamps = {};
  static const Duration _cookieCacheTimeout = Duration(minutes: 5);
  
  // Cronet client (Android/ChromeOS) - placeholder for future implementation
  http.Client? _cronetClient;
  bool get _isCronetAvailable => false; // Disabled until Cronet package is available
  
  // Fallback browser fetch
  final Map<String, String> _browserHeaders = {};
  
  /// Initialize the CDN fetcher
  Future<void> initialize() async {
    debugPrint('=== CDN Fetcher: Initializing...');
    
    // Initialize cookie cache
    await _loadCookieCache();
    
    // Initialize Cronet client on Android
    if (_isCronetAvailable) {
      await _initializeCronet();
    }
    
    // Initialize browser headers
    await _initializeBrowserHeaders();
    
    debugPrint('=== CDN Fetcher: Initialized with ${_cookieCache.length} cached cookies');
  }
  
  /// Load cached cookies from storage
  Future<void> _loadCookieCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookieData = prefs.getString('cdn_cookies');
      if (cookieData != null) {
        final cookies = jsonDecode(cookieData) as Map<String, dynamic>;
        _cookieCache.addAll({
          for (final entry in cookies.entries)
            entry.key: entry.value as String
        });
        debugPrint('=== CDN Fetcher: Loaded ${_cookieCache.length} cookies from cache');
      }
    } catch (e) {
      debugPrint('=== CDN Fetcher: Error loading cookie cache: $e');
    }
  }
  
  /// Save cookies to cache
  Future<void> _saveCookieCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cdn_cookies', jsonEncode(_cookieCache));
      debugPrint('=== CDN Fetcher: Saved ${_cookieCache.length} cookies to cache');
    } catch (e) {
      debugPrint('=== CDN Fetcher: Error saving cookie cache: $e');
    }
  }
  
  /// Initialize Cronet client for Android (placeholder)
  Future<void> _initializeCronet() async {
    // Cronet support will be implemented when the package is available
    _cronetClient = null;
    debugPrint('=== CDN Fetcher: Cronet not available (using standard HTTP client)');
  }
  
  /// Initialize browser headers for fallback
  Future<void> _initializeBrowserHeaders() async {
    _browserHeaders.addAll({
      'User-Agent': 'FurClient/1.0',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
    });
    
    debugPrint('=== CDN Fetcher: Browser headers initialized');
  }
  
  /// Set WebView controller for cookie synchronization
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    debugPrint('=== CDN Fetcher: WebView controller set');
  }
  
  /// Fetch CDN content with multiple strategies
  Future<Uint8List?> fetchCDNContent(String url, {Map<String, String>? headers}) async {
    debugPrint('=== CDN Fetcher: Fetching $url');
    
    // Strategy 1: Cronet client (Android/ChromeOS)
    if (_isCronetAvailable && _cronetClient != null) {
      try {
        final result = await _fetchWithCronet(url, headers);
        if (result != null) {
          debugPrint('=== CDN Fetcher: Success with Cronet');
          return result;
        }
      } catch (e) {
        debugPrint('=== CDN Fetcher: Cronet failed: $e');
      }
    }
    
    // Strategy 2: InAppWebView with cookies
    try {
      final result = await _fetchWithWebView(url, headers);
      if (result != null) {
        debugPrint('=== CDN Fetcher: Success with WebView');
        return result;
      }
    } catch (e) {
      debugPrint('=== CDN Fetcher: WebView failed: $e');
    }
    
    // Strategy 3: Browser fetch fallback
    try {
      final result = await _fetchWithBrowser(url, headers);
      if (result != null) {
        debugPrint('=== CDN Fetcher: Success with browser fetch');
        return result;
      }
    } catch (e) {
      debugPrint('=== CDN Fetcher: Browser fetch failed: $e');
    }
    
    debugPrint('=== CDN Fetcher: All strategies failed for $url');
    return null;
  }
  
  /// Fetch using Cronet client
  Future<Uint8List?> _fetchWithCronet(String url, Map<String, String>? headers) async {
    debugPrint('=== CDN Fetcher: Trying Cronet for $url');
    
    final allHeaders = {..._browserHeaders, ...(headers ?? {})};
    allHeaders['Cookie'] = _getCookieHeader(url);
    
    final request = http.Request('GET', Uri.parse(url))
      ..headers.addAll(allHeaders);
    
    final response = await _cronetClient!.send(request).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Cronet request timeout'),
    );
    
    if (response.statusCode == 200) {
      final bytes = await response.stream.toBytes();
      _updateCookiesFromResponse(url, response.headers);
      return bytes;
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }
  
  /// Fetch using InAppWebView
  Future<Uint8List?> _fetchWithWebView(String url, Map<String, String>? headers) async {
    debugPrint('=== CDN Fetcher: Trying WebView for $url');
    
    if (_webViewController == null) {
      throw Exception('WebView controller not set');
    }
    
    // Inject cookies into WebView
    await _injectCookiesToWebView(url);
    
    // Make request via WebView
    final result = await _webViewController!.evaluateJavascript(
      source: '''
        (async () => {
          try {
            const response = await fetch('$url', {
              method: 'GET',
              headers: ${jsonEncode({..._browserHeaders, ...(headers ?? {})})},
              credentials: 'include'
            });
            
            if (response.ok) {
              const arrayBuffer = await response.arrayBuffer();
              return new Uint8Array(arrayBuffer);
            } else {
              throw new Error('HTTP \${response.status}');
            }
          } catch (e) {
            return null;
          }
        })()
      ''',
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('WebView request timeout'),
    );
    
    if (result != null && result is Uint8List) {
      return result;
    }
    
    return null;
  }
  
  /// Fetch using browser fallback
  Future<Uint8List?> _fetchWithBrowser(String url, Map<String, String>? headers) async {
    debugPrint('=== CDN Fetcher: Trying browser fetch for $url');
    
    // On Windows, use system browser
    if (Platform.isWindows) {
      return _fetchWithSystemBrowser(url, headers);
    }
    
    // On other platforms, use http.Client with cookies
    final allHeaders = {..._browserHeaders, ...(headers ?? {})};
    allHeaders['Cookie'] = _getCookieHeader(url);
    
    final response = await http.get(
      Uri.parse(url),
      headers: allHeaders,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Browser fetch timeout'),
    );
    
    if (response.statusCode == 200) {
      _updateCookiesFromResponse(url, response.headers);
      return response.bodyBytes;
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }
  
  /// Fetch using system browser (Windows)
  Future<Uint8List?> _fetchWithSystemBrowser(String url, Map<String, String>? headers) async {
    debugPrint('=== CDN Fetcher: Using system browser for $url');
    
    // Create a temporary HTML file with JavaScript fetch
    final tempDir = await getTemporaryDirectory();
    final htmlFile = File('${tempDir.path}/cdn_fetch.html');
    
    final htmlContent = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <script src="https://cdn.jsdelivr.net/npm/@hpcc-js/wasm/dist/index.min.js"></script>
      </head>
      <body>
        <script>
          async function fetchCDN() {
            try {
              const response = await fetch('$url', {
                method: 'GET',
                headers: ${jsonEncode({..._browserHeaders, ...(headers ?? {})})},
                credentials: 'include'
              });
              
              if (response.ok) {
                const arrayBuffer = await response.arrayBuffer();
                const uint8Array = new Uint8Array(arrayBuffer);
                // Send result back to Flutter
                window.flutter_inappwebview.callHandler('cdnFetchResult', uint8Array);
              } else {
                window.flutter_inappwebview.callHandler('cdnFetchError', 'HTTP ' + response.status);
              }
            } catch (e) {
              window.flutter_inappwebview.callHandler('cdnFetchError', e.message);
            }
          }
          
          fetchCDN();
        </script>
      </body>
      </html>
    ''';
    
    await htmlFile.writeAsString(htmlContent);
    
    // Open in system browser
    if (await canLaunchUrl(Uri.parse(htmlFile.path))) {
      await launchUrl(
        Uri.parse(htmlFile.path),
        mode: LaunchMode.externalApplication,
      );
    }
    
    // For now, return null (we'll need to implement result handling)
    return null;
  }
  
  /// Get cookie header for URL
  String _getCookieHeader(String url) {
    final uri = Uri.parse(url);
    final domain = uri.host;

    final cookies = <String>[];
    
    for (final entry in _cookieCache.entries) {
      final cookie = entry.value;
      // Simple cookie matching logic
      if (cookie.contains(domain) && !cookie.contains('Expires=')) {
        cookies.add(cookie);
      }
    }
    
    return cookies.join('; ');
  }
  
  /// Update cookies from HTTP response
  void _updateCookiesFromResponse(String url, Map<String, String> headers) {
    final setCookie = headers['set-cookie'];
    if (setCookie != null) {
      final uri = Uri.parse(url);
      _parseAndStoreCookies(setCookie, uri.host);
    }
  }
  
  /// Parse and store cookies
  void _parseAndStoreCookies(String setCookieHeader, String domain) {
    final cookies = setCookieHeader.split(';');
    for (final cookie in cookies) {
      final parts = cookie.trim().split('=');
      if (parts.length >= 2) {
        final name = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        
        if (name.isNotEmpty && value.isNotEmpty) {
          final cookieString = '$name=$value; Domain=$domain';
          _cookieCache[name] = cookieString;
          _cookieTimestamps[name] = DateTime.now();
          
          debugPrint('=== CDN Fetcher: Stored cookie: $name');
        }
      }
    }
    
    _saveCookieCache();
  }
  
  /// Inject cookies into WebView
  Future<void> _injectCookiesToWebView(String url) async {
    if (_webViewController == null) return;
    
    final uri = Uri.parse(url);
    final domain = uri.host;
    
    for (final entry in _cookieCache.entries) {
      final cookie = entry.value;
      if (cookie.contains(domain)) {
        try {
          await _webViewController!.evaluateJavascript(
            source: "document.cookie = '$cookie';",
          );
        } catch (e) {
          debugPrint('=== CDN Fetcher: Error injecting cookie: $e');
        }
      }
    }
  }
  
  /// Sync cookies from WebView
  Future<void> syncCookiesFromWebView() async {
    if (_webViewController == null) return;
    
    try {
      final cookies = await FAICookieManager.getCookies('https://www.furaffinity.net');
      for (final cookie in cookies) {
        _cookieCache[cookie.name] = '${cookie.name}=${cookie.value}; Domain=${cookie.domain}';
        _cookieTimestamps[cookie.name] = DateTime.now();
      }
      
      _saveCookieCache();
      debugPrint('=== CDN Fetcher: Synced ${cookies.length} cookies from WebView');
    } catch (e) {
      debugPrint('=== CDN Fetcher: Error syncing cookies: $e');
    }
  }
  
  /// Clear all cached cookies
  Future<void> clearCookies() async {
    _cookieCache.clear();
    _cookieTimestamps.clear();
    await _saveCookieCache();
    debugPrint('=== CDN Fetcher: Cleared all cookies');
  }
  
  /// Clean up expired cookies
  Future<void> cleanExpiredCookies() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cookieTimestamps.entries) {
      final age = now.difference(entry.value);
      if (age > _cookieCacheTimeout) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _cookieCache.remove(key);
      _cookieTimestamps.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      await _saveCookieCache();
      debugPrint('=== CDN Fetcher: Cleaned ${expiredKeys.length} expired cookies');
    }
  }
  
  /// Get cached cookies count
  int get cachedCookiesCount => _cookieCache.length;
  
  /// Check if cookies are valid
  bool get hasValidCookies {
    final now = DateTime.now();
    for (final timestamp in _cookieTimestamps.values) {
      final age = now.difference(timestamp);
      if (age > _cookieCacheTimeout) {
        return false;
      }
    }
    return _cookieCache.isNotEmpty;
  }
}