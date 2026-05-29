import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/cdn_fetcher.dart';

/// CDN Image Loader with multi-strategy approach
/// 
/// Features:
/// - Cronet for efficient HTTP requests (Android/ChromeOS)
/// - WebView2 for Windows with fallback
/// - Cookie synchronization
/// - Error handling and retry logic
/// - Cache management
class CDNImageLoader {
  static CDNImageLoader? _instance;
  static CDNImageLoader get instance => _instance ??= CDNImageLoader._();
  
  CDNImageLoader._();
  
  // CDN Fetcher instance
  final CDNContentFetcher _cdnFetcher = CDNContentFetcher.instance;
  
  // Cache
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheTimeout = Duration(hours: 1);
  static const int _maxCacheSize = 50; // Max images in memory
  
  // Controllers
  InAppWebViewController? _webViewController;
  
  /// Initialize the CDN image loader
  Future<void> initialize() async {
    debugPrint('=== CDN Image Loader: Initializing...');
    
    // Initialize CDN fetcher
    await _cdnFetcher.initialize();
    
    // Set up WebView controller
    _cdnFetcher.setWebViewController(_webViewController!);
    
    debugPrint('=== CDN Image Loader: Initialized');
  }
  
  /// Set WebView controller for cookie synchronization
  void setWebViewController(InAppWebViewController controller) {
    _webViewController = controller;
    _cdnFetcher.setWebViewController(controller);
  }
  
  /// Load image from CDN with multiple strategies
  Future<Uint8List?> loadImage(String url, {Map<String, String>? headers}) async {
    debugPrint('=== CDN Image Loader: Loading $url');
    
    // Check cache first
    final cached = _getCachedImage(url);
    if (cached != null) {
      debugPrint('=== CDN Image Loader: Cache hit for $url');
      return cached;
    }
    
    // Try CDN fetcher with multiple strategies
    final imageBytes = await _cdnFetcher.fetchCDNContent(url, headers: headers);
    
    if (imageBytes != null) {
      // Cache the result
      _cacheImage(url, imageBytes);
      debugPrint('=== CDN Image Loader: Loaded ${imageBytes.length} bytes from $url');
      return imageBytes;
    }
    
    debugPrint('=== CDN Image Loader: Failed to load $url');
    return null;
  }
  
  /// Load image widget with fallbacks
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
          return placeholder ?? const CircularProgressIndicator();
        }
        
        if (snapshot.hasError || snapshot.data == null) {
          return errorWidget ?? 
            Container(
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
  
  /// Load image with cached_network_image fallback
  Widget loadImageWithFallback(
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
          return CachedNetworkImage(
            imageUrl: url,
            placeholder: (context, url) => placeholder ?? const CircularProgressIndicator(),
            errorWidget: (context, url, error) => errorWidget ?? 
              Container(
                width: width,
                height: height,
                color: Colors.grey[200],
                child: const Icon(Icons.error),
              ),
            width: width,
            height: height,
            fit: fit,
          );
        }
        
        if (snapshot.hasError || snapshot.data == null) {
          return CachedNetworkImage(
            imageUrl: url,
            placeholder: (context, url) => placeholder ?? const CircularProgressIndicator(),
            errorWidget: (context, url, error) => errorWidget ?? 
              Container(
                width: width,
                height: height,
                color: Colors.grey[200],
                child: const Icon(Icons.error),
              ),
            width: width,
            height: height,
            fit: fit,
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
  
  /// Get cached image
  Uint8List? _getCachedImage(String url) {
    final now = DateTime.now();
    
    // Check if cache entry exists and is not expired
    if (_imageCache.containsKey(url)) {
      final timestamp = _cacheTimestamps[url]!;
      final age = now.difference(timestamp);
      
      if (age < _cacheTimeout) {
        return _imageCache[url];
      } else {
        // Remove expired entry
        _imageCache.remove(url);
        _cacheTimestamps.remove(url);
      }
    }
    
    return null;
  }
  
  /// Cache image
  void _cacheImage(String url, Uint8List data) {
    // Check cache size limit
    if (_imageCache.length >= _maxCacheSize) {
      // Remove oldest entry
      final oldestUrl = _cacheTimestamps.entries.reduce(
        (a, b) => a.value.isBefore(b.value) ? a : b,
      ).key;
      
      _imageCache.remove(oldestUrl);
      _cacheTimestamps.remove(oldestUrl);
    }
    
    _imageCache[url] = data;
    _cacheTimestamps[url] = DateTime.now();
  }
  
  /// Clear cache
  Future<void> clearCache() async {
    _imageCache.clear();
    _cacheTimestamps.clear();
    debugPrint('=== CDN Image Loader: Cache cleared');
  }
  
  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    final now = DateTime.now();
    int expiredCount = 0;
    int validCount = 0;
    
    for (final timestamp in _cacheTimestamps.values) {
      final age = now.difference(timestamp);
      if (age > _cacheTimeout) {
        expiredCount++;
      } else {
        validCount++;
      }
    }
    
    return {
      'total': _imageCache.length,
      'valid': validCount,
      'expired': expiredCount,
      'maxSize': _maxCacheSize,
      'timeout': _cacheTimeout.inMilliseconds,
    };
  }
  
  /// Preload multiple images
  Future<void> preloadImages(List<String> urls) async {
    debugPrint('=== CDN Image Loader: Preloading ${urls.length} images');
    
    for (final url in urls) {
      if (!_imageCache.containsKey(url)) {
        await loadImage(url);
      }
    }
    
    debugPrint('=== CDN Image Loader: Preloading completed');
  }
  
  /// Check if image is cached
  bool isCached(String url) {
    return _getCachedImage(url) != null;
  }
  
  /// Get cached image size
  int? getCachedImageSize(String url) {
    return _imageCache[url]?.length;
  }
  
  /// Sync cookies from WebView
  Future<void> syncCookies() async {
    await _cdnFetcher.syncCookiesFromWebView();
  }
  
  /// Clear cookies
  Future<void> clearCookies() async {
    await _cdnFetcher.clearCookies();
  }
  
  /// Clean up expired cache
  Future<void> cleanup() async {
    await _cdnFetcher.cleanExpiredCookies();
    
    // Clean up expired image cache
    final now = DateTime.now();
    final expiredUrls = <String>[];
    
    for (final entry in _cacheTimestamps.entries) {
      final age = now.difference(entry.value);
      if (age > _cacheTimeout) {
        expiredUrls.add(entry.key);
      }
    }
    
    for (final url in expiredUrls) {
      _imageCache.remove(url);
      _cacheTimestamps.remove(url);
    }
    
    if (expiredUrls.isNotEmpty) {
      debugPrint('=== CDN Image Loader: Cleaned ${expiredUrls.length} expired images');
    }
  }
}

/// Extension for CDN image URLs
extension CDNImageUrl on String {
  /// Convert to CDN URL
  String toCDNUrl() {
    if (startsWith('http://') || startsWith('https://')) {
      return this;
    }
    
    // Handle different CDN patterns
    if (contains('t.furaffinity.net') || 
        contains('d.furaffinity.net') || 
        contains('a.furaffinity.net')) {
      return 'https://$this';
    }
    
    // Default to FA CDN
    return 'https://t.furaffinity.net/$this';
  }
  
  /// Check if URL is CDN
  bool get isCDN {
    return contains('t.furaffinity.net') || 
           contains('d.furaffinity.net') || 
           contains('a.furaffinity.net');
  }
}

/// Widget for CDN image loading with platform-specific optimizations
class CDNImage extends StatelessWidget {
  final String url;
  final Map<String, String>? headers;
  final Widget? placeholder;
  final Widget? errorWidget;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool useFallback;
  
  const CDNImage(
    this.url, {
    super.key,
    this.headers,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.useFallback = true,
  });
  
  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorWidget ?? 
        Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Icon(Icons.error),
        );
    }
    
    final cdnUrl = url.toCDNUrl();
    
    if (useFallback) {
      return CDNImageLoader.instance.loadImageWithFallback(
        cdnUrl,
        headers: headers,
        placeholder: placeholder,
        errorWidget: errorWidget,
        width: width,
        height: height,
        fit: fit,
      );
    } else {
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
}

/// Widget for preloading CDN images
class CDNImagePreloader extends StatefulWidget {
  final List<String> urls;
  final Widget? child;
  final VoidCallback? onCompleted;
  
  const CDNImagePreloader({
    super.key,
    required this.urls,
    this.child,
    this.onCompleted,
  });
  
  @override
  State<CDNImagePreloader> createState() => _CDNImagePreloaderState();
}

class _CDNImagePreloaderState extends State<CDNImagePreloader> {
  bool _isPreloading = false;
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _preloadImages(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return widget.child ?? const SizedBox.shrink();
      },
    );
  }
  
  Future<void> _preloadImages() async {
    if (!_isPreloading) {
      setState(() {
        _isPreloading = true;
      });
      
      await CDNImageLoader.instance.preloadImages(widget.urls);
      
      if (widget.onCompleted != null) {
        widget.onCompleted!();
      }
      
      setState(() {
        _isPreloading = false;
      });
    }
  }
}