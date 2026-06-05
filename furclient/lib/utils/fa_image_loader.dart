import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fa_kit/fa_kit.dart';
import 'webview_image_fetcher.dart';
import '../utils/cookie_store.dart';


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
      setState(() { _isLoading = false; _hasError = true; });
      return;
    }

    setState(() { _isLoading = true; _hasError = false; _bytes = null; });

    // Use WebView-based image fetching on all platforms.
    // WebView shares cookies + browser TLS fingerprint, so CF doesn't block it.
    try {
      debugPrint('=== FAImage: using WebView fetcher for $imageUrl');
      final bytes = await WebViewImageFetcher.instance.fetchImage(imageUrl);
      if (bytes != null && bytes.isNotEmpty) {
        if (mounted) {
          setState(() {
            _bytes = bytes;
            _isLoading = false;
          });
        }
        return;
      }
      debugPrint('=== FAImage: WebView fetch returned null, falling back to HTTP');
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
        debugPrint('=== FAImage request to: $imageUrl');
        _requestHeaders.forEach((k, v) => request.headers.set(k, v));
        final response = await request.close();

        if (response.statusCode == 403 && attempt < 2) {
          client.close();
          debugPrint('FAImage retry $attempt after 403');
          
          // Если это первая попытка и 403, ждем чтобы FACeline мог решить Cloudflare
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

        if (mounted) {
          setState(() {
            _bytes = bytes;
            _isLoading = false;
          });
        }
        return;
      } catch (e) {
        debugPrint('FAImage error (attempt $attempt): $e');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 2 + attempt * 3));
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
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
        child: CircularProgressIndicator(strokeWidth: 2),
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
/// Supports custom avatar URL or falls back to FA CDN patterns.
class FAAvatar extends StatelessWidget {
  final String username;
  final double size;
  final String? avatarUrl; // custom URL — if provided, used instead of CDN fallback

  const FAAvatar({
    super.key,
    required this.username,
    this.size = 40,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final url = (avatarUrl != null && avatarUrl!.isNotEmpty)
        ? avatarUrl!
        : 'https://a.furaffinity.net/$username.gif';
    return ClipOval(
      child: FAImage(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: CircleAvatar(
          radius: size / 2,
          backgroundColor: const Color(0xFF2A2A2A),
          child: Text(
            username.isNotEmpty ? username[0].toUpperCase() : '?',
            style: TextStyle(
              color: const Color(0xFF4FC3F7),
              fontSize: size * 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
