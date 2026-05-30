import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import '../utils/webview_image_fetcher.dart';

/// Fullscreen image viewer powered by extended_image.
/// Zoom, pan, double-tap, slide-to-dismiss.
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

  @override
  Widget build(BuildContext context) {
    return ExtendedImageSlidePage(
      slideAxis: SlideAxis.both,
      slideType: SlideType.onlyImage,
      resetPageDuration: const Duration(milliseconds: 300),
      slidePageBackgroundHandler: (offset, pageSize) {
        final d = (offset.distance / (pageSize.longestSide * 0.5))
            .clamp(0.0, 1.0);
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Image with zoom/pan
            Center(
              child: FutureBuilder<Uint8List?>(
                future:
                    WebViewImageFetcher.instance.fetchImage(imageUrl),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
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
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    );
                  }
                  return ExtendedImage.memory(
                    bytes,
                    fit: BoxFit.contain,
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
                      final begin =
                          gestureState.gestureDetails?.totalScale ?? 1.0;
                      gestureState.handleDoubleTap(
                        scale: begin > 1.5 ? 1.0 : 2.5,
                        doubleTapPosition:
                            gestureState.pointerDownPosition,
                      );
                    },
                  );
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
                      Material(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => Navigator.of(context).pop(),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.close,
                                color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                      if (title != null ||
                          author != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (title != null &&
                                  title!.isNotEmpty)
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
                              if (author != null &&
                                  author!.isNotEmpty)
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
      ),
    );
  }
}
