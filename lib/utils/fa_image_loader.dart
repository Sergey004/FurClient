import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fa_kit/fa_kit.dart';
import 'webview_image_fetcher.dart';
import 'fa_image_cache.dart';
import '../utils/cookie_store.dart';
import '../widgets/adaptive/adaptive_progress.dart';

/// FA-специфичный виджет для загрузки изображений.
class FAImage extends StatefulWidget {
  final String url;
  final DynamicThumbnail? dynamicThumbnail;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const FAImage({
    super.key,
    required this.url,
    this.dynamicThumbnail,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<FAImage> createState() => _FAImageState();
}

class _FAImageState extends State<FAImage> {
  Uint8List? _bytes;
  bool _isLoading = true;
  bool _hasError = false;

  String get _resolvedUrl {
    String url = widget.url;
    if (widget.dynamicThumbnail != null &&
        widget.width != null &&
        widget.height != null) {
      url = widget.dynamicThumbnail!
          .bestThumbnailUrl(width: widget.width!, height: widget.height!)
          .toString();
    }
    // Normalise protocol-relative URLs (//host/...) — these come from FA HTML
    // sometimes and Uri.parse leaves the scheme empty, which then crashes
    // HttpClient.getUrl with "Unsupported scheme ''".
    if (url.startsWith('//')) {
      url = 'https:$url';
    }
    // Windows: WebView fetcher handles CF (same TLS fingerprint as login WebView).
    // Android: direct HTTP with cookies (proxy server only runs on Windows).
    return url;
  }

  Map<String, String> get _requestHeaders {
    final headers = <String, String>{
      'User-Agent': 'ceylo.FurAffinityApp/1.0',
      'Referer': 'https://www.furaffinity.net',
    };
    // On Windows, WebView fetcher handles cookies and auth.
    // On Android/other, add cookies from CookieStore for direct HTTP.
    if (!io.Platform.isWindows) {
      final cookieHeader = CookieStore.instance.cookieHeader;
      if (cookieHeader != null) headers['Cookie'] = cookieHeader;
    }
    return headers;
  }

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(FAImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final imageUrl = _resolvedUrl;
    if (imageUrl.isEmpty) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasError = false;
      _bytes = null;
    });

    // Cached fetch — dedups concurrent requests and persists bytes on disk.
    final bytes = await FAImageCache.instance.load(imageUrl, _fetchFromNetwork);
    if (!mounted) return;
    if (bytes != null && bytes.isNotEmpty) {
      setState(() {
        _bytes = bytes;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// Performs the actual network fetch.  Called by [FAImageCache] only on a
  /// cache miss, and deduped per URL across concurrent widgets.
  Future<Uint8List?> _fetchFromNetwork() async {
    final imageUrl = _resolvedUrl;

    // Use WebView-based image fetching on all platforms.
    // WebView shares cookies + browser TLS fingerprint, so CF doesn't block it.
    try {
      final bytes = await WebViewImageFetcher.instance.fetchImage(imageUrl);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    } catch (e) {
      debugPrint('=== FAImage: WebView fetch error: $e');
    }

    // Fallback: HTTP-based loading (for non-Windows or if WebView fails)
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        debugPrint('=== FAImage: trying HTTP for $imageUrl (attempt $attempt)');
        final client = io.HttpClient()
          ..connectionTimeout = const Duration(seconds: 30);
        final request = await client.getUrl(Uri.parse(imageUrl));
        _requestHeaders.forEach((k, v) => request.headers.set(k, v));
        final response = await request.close();

        if (response.statusCode == 403 && attempt < 2) {
          client.close();
          debugPrint('FAImage retry $attempt after 403');
          if (attempt == 0) {
            await Future.delayed(const Duration(seconds: 3));
          } else {
            await Future.delayed(Duration(seconds: 2 + attempt * 3));
          }
          continue;
        }

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final completer = Completer<Uint8List>();
        final chunks = <int>[];
        response.listen(
          (chunk) => chunks.addAll(chunk),
          onDone: () => completer.complete(Uint8List.fromList(chunks)),
          onError: (e) => completer.completeError(e),
        );
        final bytes = await completer.future;
        client.close();
        return bytes;
      } catch (e) {
        debugPrint('FAImage error (attempt $attempt): $e');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 2 + attempt * 3));
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.placeholder ?? _defaultPlaceholder();
    }

    if (_hasError || _bytes == null) {
      return widget.errorWidget ?? _defaultError();
    }

    if (widget.fit == BoxFit.contain) {
      return InteractiveViewer(
        child: Image.memory(
          _bytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        ),
      );
    }

    return Image.memory(
      _bytes!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Center(
        child: AdaptiveProgress(strokeWidth: 2),
      ),
    );
  }

  Widget _defaultError() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: const Icon(Icons.broken_image, color: Colors.white38),
    );
  }
}

/// Аватар пользователя FA.
class FAAvatar extends StatelessWidget {
  final String username;
  final double size;

  const FAAvatar({
    super.key,
    required this.username,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final avatarUrl = 'https://a.furaffinity.net/$username.gif';
    return ClipOval(
      child: FAImage(
        url: avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: CircleAvatar(
          radius: size / 2,
          backgroundColor: colors.primaryContainer,
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontSize: size * 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
