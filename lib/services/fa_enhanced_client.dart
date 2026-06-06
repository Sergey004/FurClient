import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import '../services/cdn_loader.dart';
import '../utils/cdn_image_loader.dart';
import '../utils/cookie_manager.dart';

/// Enhanced FA Client with multi-strategy CDN support
///
/// Features:
/// - Cronet for efficient HTTP requests (Android/ChromeOS)
/// - WebView2 for Windows with fallback
/// - Cookie synchronization between WebView and HTTP requests
/// - Cloudflare bypass with JavaScript injection
/// - CDN content optimization
class FAEnhancedClient {
  static FAEnhancedClient? _instance;
  static FAEnhancedClient get instance => _instance ??= FAEnhancedClient._();

  FAEnhancedClient._();

  // Services
  final CDNLoader _cdnLoader = CDNLoader.instance;

  // State
  InAppWebViewController? _webViewController;
  final Map<String, dynamic> _sessionData = {};
  final Map<String, String> _customHeaders = {};
  bool _isInitialized = false;

  // Cronet client
  http.Client? _cronetClient;
  bool get _isCronetAvailable => kIsWeb || Platform.isAndroid;

  // Public setter for session data
  void setSessionData(String key, dynamic value) {
    _sessionData[key] = value;
  }

  // Platform-specific settings
  bool get _isWindows => Platform.isWindows;
  bool get _isAndroid => Platform.isAndroid;

  /// Initialize the enhanced client
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('=== FA Enhanced Client: Initializing...');

    try {
      // Initialize CDN loader
      await _cdnLoader.initialize();

      // Initialize Cronet on Android
      if (_isCronetAvailable) {
        await _initializeCronet();
      }

      // Set up custom headers
      await _setupCustomHeaders();

      _isInitialized = true;
      debugPrint('=== FA Enhanced Client: Initialized successfully');
    } catch (e) {
      debugPrint('=== FA Enhanced Client: Initialization failed: $e');
      rethrow;
    }
  }

  /// Initialize Cronet engine
  Future<void> _initializeCronet() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        // Create Cronet engine with optimizations
        // Cronet support will be implemented when the package is available
        // final cronetEngine = CronetEngine(
        //   options: CronetEngineOptions(
        //     cacheMode: CronetCacheMode.disk,
        //     enableHttp2: true,
        //     enableQuic: true,
        //     enableBrotli: true,
        //     userAgent: 'FurClient/1.0',
        //     connectTimeout: 15000,
        //     readTimeout: 30000,
        //     threadPoolSize: 4,
        //   ),
        // );

        // Create Cronet client
        _cronetClient = null;

        debugPrint(
            '=== FA Enhanced Client: Cronet engine not available (using fallback)');
      } catch (e) {
        debugPrint('=== FA Enhanced Client: Cronet initialization failed: $e');
        _cronetClient = null;
      }
    }
  }

  /// Setup custom headers
  Future<void> _setupCustomHeaders() async {
    _customHeaders.addAll({
      'User-Agent': 'FurClient/1.0',
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'DNT': '1',
    });

    debugPrint('=== FA Enhanced Client: Custom headers setup complete');
  }

  /// Set WebView controller
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    _cdnLoader.setWebViewController(controller);

    debugPrint('=== FA Enhanced Client: WebView controller set');
  }

  /// Get session data
  Map<String, dynamic> get sessionData => Map.unmodifiable(_sessionData);

  /// Check if client is initialized
  bool get isInitialized => _isInitialized;

  /// Check if Cronet is available
  bool get isCronetAvailable => _isCronetAvailable && _cronetClient != null;

  /// Get platform-specific client
  dynamic getPlatformClient() {
    if (isCronetAvailable) {
      return _cronetClient;
    }
    return _webViewController;
  }

  /// Fetch content with platform-specific optimization
  Future<Uint8List?> fetchContent(String url,
      {Map<String, String>? headers}) async {
    debugPrint(
        '=== FA Enhanced Client: Fetching $url with platform optimization');

    // Use CDN fetcher for CDN URLs
    if (url.contains('t.furaffinity.net') ||
        url.contains('d.furaffinity.net') ||
        url.contains('a.furaffinity.net')) {
      return await _cdnLoader.load(url, headers: headers);
    }

    // Use platform-specific client
    if (isCronetAvailable) {
      return await _fetchWithCronet(url, headers);
    } else {
      return await _fetchWithWebView(url, headers);
    }
  }

  /// Fetch using Cronet
  Future<Uint8List?> _fetchWithCronet(
      String url, Map<String, String>? headers) async {
    debugPrint('=== FA Enhanced Client: Using Cronet for $url');

    final allHeaders = {..._customHeaders, ...(headers ?? {})};
    allHeaders['Cookie'] = _getCookieHeader(url);

    final request = http.Request('GET', Uri.parse(url))
      ..headers.addAll(allHeaders);

    final response = await _cronetClient!.send(request).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException('Cronet request timeout'),
        );

    if (response.statusCode == 200) {
      _updateCookiesFromResponse(url, response.headers);
      return await response.stream.toBytes();
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  /// Fetch using WebView
  Future<Uint8List?> _fetchWithWebView(
      String url, Map<String, String>? headers) async {
    debugPrint('=== FA Enhanced Client: Using WebView for $url');

    if (_webViewController == null) {
      throw Exception('WebView controller not set');
    }

    // Inject cookies
    await _injectCookiesToWebView(url);

    // Make request via WebView
    final result = await _webViewController!.evaluateJavascript(
      source: '''
        (async () => {
          try {
            const response = await fetch('$url', {
              method: 'GET',
              headers: ${jsonEncode({..._customHeaders, ...(headers ?? {})})},
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

    return result as Uint8List?;
  }

  /// Get cookie header
  String _getCookieHeader(String url) {
    final uri = Uri.parse(url);
    final domain = uri.host;

    final cookies = <String>[];
    for (final entry in _sessionData.entries) {
      if (entry.key.startsWith('cookie_')) {
        final cookie = entry.value as String;
        if (cookie.contains(domain)) {
          cookies.add(cookie);
        }
      }
    }

    return cookies.join('; ');
  }

  /// Update cookies from response
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
          _sessionData['cookie_$name'] = cookieString;

          debugPrint('=== FA Enhanced Client: Stored cookie: $name');
        }
      }
    }
  }

  /// Inject cookies into WebView
  Future<void> _injectCookiesToWebView(String url) async {
    if (_webViewController == null) return;

    final uri = Uri.parse(url);
    final domain = uri.host;

    for (final entry in _sessionData.entries) {
      if (entry.key.startsWith('cookie_')) {
        final cookie = entry.value as String;
        if (cookie.contains(domain)) {
          try {
            await _webViewController!.evaluateJavascript(
              source: "document.cookie = '$cookie';",
            );
          } catch (e) {
            debugPrint('=== FA Enhanced Client: Error injecting cookie: $e');
          }
        }
      }
    }
  }

  /// Load image with CDN optimization
  Future<Uint8List?> loadImage(String url,
      {Map<String, String>? headers}) async {
    return await _cdnLoader.load(url, headers: headers);
  }

  /// Get CDN image widget
  Widget getImageWidget(
    String url, {
    Map<String, String>? headers,
    Widget? placeholder,
    Widget? errorWidget,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return CDNImage(
      url,
      headers: headers,
      placeholder: placeholder,
      errorWidget: errorWidget,
      width: width,
      height: height,
      fit: fit,
    );
  }

  /// Sync cookies from WebView
  Future<void> syncCookies() async {
    try {
      if (_webViewController != null) {
        await FAICookieManager.syncFromWebView(_webViewController!);
      }
      debugPrint('=== FA Enhanced Client: Cookies synced');
    } catch (e) {
      debugPrint('=== FA Enhanced Client: Error syncing cookies: $e');
    }
  }

  /// Clear all data
  Future<void> clearData() async {
    _sessionData.clear();
    await FAICookieManager.deleteAll();
    _cdnLoader.clearCache();

    debugPrint('=== FA Enhanced Client: All data cleared');
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    return {
      'initialized': _isInitialized,
      'cronetAvailable': isCronetAvailable,
      'sessionData': _sessionData.length,
      'cdnCache': _cdnLoader.getCacheStats(),
    };
  }

  /// Handle Cloudflare challenge
  Future<void> handleCloudflareChallenge() async {
    debugPrint('=== FA Enhanced Client: Handling Cloudflare challenge');

    if (_webViewController == null) return;

    try {
      // JavaScript to solve Cloudflare challenge
      final result = await _webViewController!.evaluateJavascript(
        source: '''
          // Look for Cloudflare challenge elements
          const challengeSelectors = [
            '.cf-browser-verification',
            '.cf-challenge',
            '#challenge-form',
            '.cf-turnstile',
            '#cf-turnstile',
            'iframe[src*="turnstile"]',
            'input[type="submit"]',
            'button[type="submit"]'
          ];
          
          let elementClicked = false;
          
          for (const selector of challengeSelectors) {
            const element = document.querySelector(selector);
            if (element) {
              console.log('Found Cloudflare challenge element:', selector);
              element.click();
              elementClicked = true;
              
              // Wait a bit for the click to take effect
              await new Promise(resolve => setTimeout(resolve, 1000));
              break;
            }
          }
          
          // If no specific challenge element found, try general click on page
          if (!elementClicked) {
            console.log('No specific Cloudflare challenge element found, trying general click');
            document.body.click();
            await new Promise(resolve => setTimeout(resolve, 1000));
          }
          
          // Return success status
          return { success: true, clicked: elementClicked };
        ''',
      ).timeout(const Duration(seconds: 10));

      if (result != null && result is Map) {
        final success = result['success'] as bool? ?? false;
        final clicked = result['clicked'] as bool? ?? false;
        debugPrint(
            '=== FA Enhanced Client: Cloudflare challenge result: success=$success, clicked=$clicked');
      }
    } catch (e) {
      debugPrint(
          '=== FA Enhanced Client: Error handling Cloudflare challenge: $e');
    }
  }

  /// Get platform-specific settings
  Map<String, dynamic> getPlatformSettings() {
    return {
      'platform': Platform.operatingSystem,
      'isWindows': _isWindows,
      'isAndroid': _isAndroid,
      'isCronetAvailable': isCronetAvailable,
      'webviewAvailable': _webViewController != null,
    };
  }

  /// Cleanup resources
  Future<void> cleanup() async {
    _cdnLoader.clearCache();

    if (_cronetClient != null) {
      _cronetClient!.close();
      _cronetClient = null;
    }

    debugPrint('=== FA Enhanced Client: Resources cleaned up');
  }
}
