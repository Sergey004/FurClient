import 'dart:async';
import 'dart:io' as io;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:extended_image/extended_image.dart';
import '../utils/webview_image_fetcher.dart';
import '../utils/cookie_store.dart';
import '../utils/platform_utils.dart';

/// Fullscreen image viewer powered by extended_image.
/// Zoom, pan, double-tap, slide-to-dismiss.
///
/// Platform-aware image loading:
/// - Windows: WebViewImageFetcher (CF won't block WebView2 TLS fingerprint)
/// - Android/other: Direct HTTP with cookies and retry
///
/// Usage:
///   ```dart
///   FullscreenImageViewer.open(context, imageUrl: sub.imageUrl, title: sub.title);
///   ```
class FullscreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final String? author;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrl,
    this.title,
    this.author,
  });

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    String? title,
    String? author,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, animation, secondaryAnimation) =>
            FullscreenImageViewer(
          imageUrl: imageUrl,
          title: title,
          author: author,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  /// Load image bytes — platform-aware.
  /// WebView fetcher first (browser TLS fingerprint bypasses CF),
  /// HTTP fallback if WebView fails.
  static Future<Uint8List?> loadImageBytes(String url) async {
    // WebView fetcher on all platforms (browser TLS → CF passes).
    try {
      final bytes = await WebViewImageFetcher.instance.fetchImage(url);
      if (bytes != null && bytes.isNotEmpty) return bytes;
    } catch (e) {
      debugPrint('=== FullscreenImageViewer: WebView fetch error: $e');
    }

    // HTTP fallback with cookies + retry
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final client = io.HttpClient()
          ..connectionTimeout = const Duration(seconds: 30);
        final request = await client.getUrl(Uri.parse(url));

        final headers = <String, String>{
          'User-Agent': 'ceylo.FurAffinityApp/1.0',
          'Referer': 'https://www.furaffinity.net',
        };
        final cookieHeader = CookieStore.instance.cookieHeader;
        if (cookieHeader != null) headers['Cookie'] = cookieHeader;
        headers.forEach((k, v) => request.headers.set(k, v));

        final response = await request.close();

        if (response.statusCode == 403 && attempt < 2) {
          client.close();
          if (attempt == 0) {
            await Future.delayed(const Duration(seconds: 3));
          } else {
            await Future.delayed(Duration(seconds: 2 + attempt * 3));
          }
          continue;
        }

        if (response.statusCode != 200) {
          client.close();
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
        debugPrint(
            '=== FullscreenImageViewer: HTTP error (attempt $attempt): $e');
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: 2 + attempt * 3));
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ExtendedImageSlidePage(
      slideAxis: SlideAxis.both,
      slideType: SlideType.onlyImage,
      resetPageDuration: const Duration(milliseconds: 300),
      slidePageBackgroundHandler: (offset, pageSize) {
        final d =
            (offset.distance / (pageSize.longestSide * 0.5)).clamp(0.0, 1.0);
        return Colors.black.withValues(alpha: 1.0 - d);
      },
      slideEndHandler: (
        Offset offset, {
        ExtendedImageSlidePageState? state,
        ScaleEndDetails? details,
      }) {
        Navigator.of(context).pop();
        return true;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image with zoom/pan
          Center(
            child: FutureBuilder<Uint8List?>(
              future: loadImageBytes(imageUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: isWindows
                        ? const fluent.ProgressRing()
                        : const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white54),
                  );
                }
                final bytes = snapshot.data;
                if (bytes == null || bytes.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image,
                            color: Colors.white38, size: 48),
                        SizedBox(height: 8),
                        Text('Failed to load image',
                            style:
                                TextStyle(color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  );
                }
                return _ImageViewer(bytes: bytes);
              },
            ),
          ),

          // Top bar with title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child:
                              Icon(Icons.close, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                    if (title != null || author != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (title != null && title!.isNotEmpty)
                              Text(
                                title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (author != null && author!.isNotEmpty)
                              Text(
                                author!,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Image viewer widget that decodes image dimensions upfront so the
/// gesture detector's zoom/pan math uses the actual image bounds, not
/// the parent container. Without this, zooming on a letterboxed image
/// leaves empty/clipped regions.
class _ImageViewer extends StatefulWidget {
  final Uint8List bytes;
  const _ImageViewer({required this.bytes});

  @override
  State<_ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<_ImageViewer> {
  ui.Image? _decoded;
  Future<ui.Image>? _decodeFuture;

  @override
  void initState() {
    super.initState();
    _decodeFuture = _decodeImage();
    _decodeFuture!.then((img) {
      if (mounted) setState(() => _decoded = img);
    }).catchError((_) {});
  }

  Future<ui.Image> _decodeImage() {
    return ui.instantiateImageCodec(widget.bytes).then((codec) {
      return codec.getNextFrame().then((frame) => frame.image);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_decoded == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: Expanded(
            child: Container(
              color: Colors.black87,
              child: ExtendedImage.memory(
              widget.bytes,
              fit: BoxFit.fill,
              mode: ExtendedImageMode.gesture,
              enableSlideOutPage: true,
              initGestureConfigHandler: (state) {
                return GestureConfig(
                  minScale: 0.5,
                  animationMinScale: 0.3,
                  maxScale: 8.0,
                  animationMaxScale: 9.0,
                  speed: 1.0,
                  inertialSpeed: 100.0,
                  initialScale: 1.0,
                  inPageView: false,
                  cacheGesture: false,
                );
              },
              onDoubleTap: (ExtendedImageGestureState gestureState) {
                final begin = gestureState.gestureDetails?.totalScale ?? 1.0;
                gestureState.handleDoubleTap(
                  scale: begin > 1.5 ? 1.0 : 2.5,
                  doubleTapPosition: gestureState.pointerDownPosition,
                );
              },
            ),
          ),
        ),
      );
      },
    );
  }
}
