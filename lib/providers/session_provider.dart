import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/cdn_loader.dart';
import '../utils/cookie_manager.dart';

/// Session Provider for managing client sessions
///
/// Handles:
/// - CDNLoader initialization
/// - CookieManager operations
/// - WebView controller management
/// - Session state
class SessionProvider extends ChangeNotifier {
  // ── State ────────────────────────────────────────────────────────
  bool _isInitialized = false;
  bool _isLoading = false;
  InAppWebViewController? _webViewController;
  String? _error;

  // ── Getters ──────────────────────────────────────────────────────
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  InAppWebViewController? get webViewController => _webViewController;
  String? get error => _error;
  CDNLoader get cdnLoader => CDNLoader.instance;

  // ── Initialization ───────────────────────────────────────────────

  /// Initialize session with CDNLoader
  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      await CDNLoader.instance.initialize();
      _isInitialized = true;

      debugPrint('=== SessionProvider: Initialized successfully');
    } catch (e) {
      debugPrint('=== SessionProvider: Initialization failed: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── WebView management ───────────────────────────────────────────

  /// Set WebView controller
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    CDNLoader.instance.setWebViewController(controller);

    debugPrint('=== SessionProvider: WebView controller set');
    notifyListeners();
  }

  /// Sync cookies from WebView
  Future<void> syncCookiesFromWebView() async {
    if (_webViewController == null) return;

    try {
      await FAICookieManager.syncFromWebView(_webViewController!);
      debugPrint('=== SessionProvider: Cookies synced from WebView');
    } catch (e) {
      debugPrint('=== SessionProvider: Cookie sync failed: $e');
      _error = e.toString();
    }
  }

  // ── CDN operations ───────────────────────────────────────────────

  /// Load content from CDN
  Future<Uint8List?> loadFromCDN(String url,
      {Map<String, String>? headers}) async {
    try {
      return await CDNLoader.instance.load(url, headers: headers);
    } catch (e) {
      debugPrint('=== SessionProvider: CDN load failed: $e');
      return null;
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return CDNLoader.instance.getCacheStats();
  }

  /// Clear cache
  void clearCache() {
    CDNLoader.instance.clearCache();
    notifyListeners();
  }

  // ── Cookie operations ────────────────────────────────────────────

  /// Validate cookies
  CookieValidationResult validateCookies() {
    return FAICookieManager.validate();
  }

  /// Check if session has valid cookies
  Future<bool> hasValidSession() async {
    return await FAICookieManager.hasSession();
  }

  /// Clear all cookies
  Future<void> clearCookies() async {
    await FAICookieManager.deleteAll();
    notifyListeners();
  }

  // ── Cleanup ──────────────────────────────────────────────────────

  /// Dispose resources
  @override
  void dispose() {
    CDNLoader.instance.dispose();
    super.dispose();
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
