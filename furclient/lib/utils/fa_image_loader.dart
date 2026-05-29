import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/fa_client.dart';

class FAImage extends StatelessWidget {
  final String url;
  final FAClient client;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final double scale;
  final Widget? placeholder;
  final Widget? errorWidget;
  final ExtendedImageMode mode;
  final GestureConfig? gestureConfig;
  final bool cache;

  const FAImage({
    super.key,
    required this.url,
    required this.client,
    this.width,
    this.height,
    this.fit,
    this.scale = 1.0,
    this.placeholder,
    this.errorWidget,
    this.mode = ExtendedImageMode.none,
    this.gestureConfig,
    this.cache = true,
  });

  @override
  Widget build(BuildContext context) {
    final headers = client.getImageHeaders();

    return ExtendedImage(
      image: CachedNetworkImageProvider(
        url,
        headers: headers,
        scale: scale,
      ),
      width: width,
      height: height,
      fit: fit,
      mode: mode,
      initGestureConfigHandler: (state) => gestureConfig ?? GestureConfig(
        minScale: 0.8,
        maxScale: 4.0,
        inPageView: false,
      ),
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return placeholder;
          case LoadState.failed:
            return errorWidget;
          default:
            return null;
        }
      },
    );
  }
}
