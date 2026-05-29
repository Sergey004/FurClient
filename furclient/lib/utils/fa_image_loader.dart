import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:cronet_http/cronet_http.dart' as cronet;
import 'package:cupertino_http/cupertino_http.dart' as cupertino;
import 'dart:io';
import '../services/fa_client.dart';

/// Custom cache manager that uses native HTTP clients for better TLS fingerprinting
class CustomCacheManager extends CacheManager {
  static const key = 'fa_image_cache';
  
  CustomCacheManager(super.config);
}

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

    return Material(
      color: Colors.transparent,
      child: ExtendedImage(
        image: CachedNetworkImageProvider(
          url,
          headers: headers,
          scale: scale,
          cacheManager: _getCustomCacheManager(),
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
      ),
    );
  }

  static BaseCacheManager? _customCacheManager;

  BaseCacheManager _getCustomCacheManager() {
    if (_customCacheManager != null) {
      return _customCacheManager!;
    }

    // Create the same native HTTP client as in main.dart
    final httpClient = _createNativeHttpClient();
    final customFileService = HttpFileService(httpClient: httpClient);
    
    _customCacheManager = CustomCacheManager(
      Config(
        'fa_image_cache',
        stalePeriod: const Duration(days: 30),
        maxNrOfCacheObjects: 1000,
        fileService: customFileService,
      ),
    );

    return _customCacheManager!;
  }

  http.Client _createNativeHttpClient() {
    // Use the same logic as in main.dart
    if (Platform.isAndroid) {
      return cronet.CronetClient.defaultCronetEngine();
    } else if (Platform.isIOS || Platform.isMacOS) {
      return cupertino.CupertinoClient.defaultSessionConfiguration();
    } else {
      // Fallback for Windows and other platforms
      return IOClient(HttpClient());
    }
  }
}
