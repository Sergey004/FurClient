import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/cdn_loader.dart';
import '../widgets/adaptive/adaptive.dart';

/// CDN Image Loader with unified CDNLoader backend
///
/// Features:
/// - Uses CDNLoader for all fetch strategies
/// - In-memory cache with 50 element limit
/// - Widget helpers for image loading
/// - Cache management and statistics
class CDNImageLoader {
  static CDNImageLoader? _instance;
  static CDNImageLoader get instance => _instance ??= CDNImageLoader._();

  CDNImageLoader._();

  // ── State ────────────────────────────────────────────────────────
  bool _isInitialized = false;

  /// Initialize the CDN image loader
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('=== CDNImageLoader: Initializing...');

    // Initialize CDN loader
    await CDNLoader.instance.initialize();

    _isInitialized = true;
    debugPrint('=== CDNImageLoader: Initialized');
  }

  // ── Image loading ────────────────────────────────────────────────

  /// Load image from CDN
  Future<Uint8List?> loadImage(String url, {Map<String, String>? headers}) async {
    debugPrint('=== CDNImageLoader: Loading $url');

    final result = await CDNLoader.instance.load(url, headers: headers);

    if (result != null) {
      debugPrint('=== CDNImageLoader: Loaded ${result.length} bytes from $url');
    } else {
      debugPrint('=== CDNImageLoader: Failed to load $url');
    }

    return result;
  }

  /// Load image widget with FutureBuilder
  Widget loadImageWidget(
    String url, {
    Map<String, String>? headers,
    Widget? placeholder,
    Widget? errorWidget,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return FutureBuilder<Uint8List?>(
      future: loadImage(url, headers: headers),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? const SizedBox(
            width: 50,
            height: 50,
            child: Center(child: AdaptiveProgress()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return errorWidget ?? Container(
            width: width,
            height: height,
            color: Colors.grey[200],
            child: const Icon(Icons.error),
          );
        }

        return Image.memory(
          snapshot.data!,
          width: width,
          height: height,
          fit: fit,
        );
      },
    );
  }

  /// Load image with automatic retry on failure
  Future<Uint8List?> loadImageWithRetry(
    String url, {
    Map<String, String>? headers,
    int maxRetries = 3,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final result = await CDNLoader.instance.load(
          url,
          headers: headers,
          useCache: attempt == 0, // Only use cache on first attempt
        );

        if (result != null) return result;

        // Wait before retry
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
        }
      } catch (e) {
        debugPrint('=== CDNImageLoader: Retry ${attempt + 1} failed: $e');
      }
    }

    return null;
  }

  // ── Cache management ─────────────────────────────────────────────

  /// Clear image cache
  void clearCache() {
    CDNLoader.instance.clearCache();
    debugPrint('=== CDNImageLoader: Cache cleared');
  }

  /// Clean expired cache entries
  void cleanExpiredCache() {
    CDNLoader.instance.cleanExpiredCache();
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return CDNLoader.instance.getCacheStats();
  }

  /// Preload multiple images
  Future<void> preloadImages(List<String> urls, {Map<String, String>? headers}) async {
    debugPrint('=== CDNImageLoader: Preloading ${urls.length} images');

    for (final url in urls) {
      await loadImage(url, headers: headers);
    }

    debugPrint('=== CDNImageLoader: Preloading completed');
  }

  /// Check if image is cached
  bool isCached(String url) {
    return CDNLoader.instance.cacheSize > 0; // Simplified check
  }

  // ── Public getters ───────────────────────────────────────────────

  /// Current cache size
  int get cacheSize => CDNLoader.instance.cacheSize;

  /// Maximum cache size
  int get maxCacheSize => CDNLoader.instance.maxCacheSize;
}

/// Widget for CDN image loading with automatic fallback
class CDNImage extends StatelessWidget {
  final String url;
  final Map<String, String>? headers;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final BoxFit fit;

  const CDNImage(
    this.url, {
    super.key,
    this.headers,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorWidget ?? Container(
        width: width,
        height: height,
        color: Colors.grey[200],
        child: const Icon(Icons.error),
      );
    }

    final cdnUrl = url.toFullCDNUrl();

    return CDNImageLoader.instance.loadImageWidget(
      cdnUrl,
      headers: headers,
      placeholder: placeholder,
      errorWidget: errorWidget,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
