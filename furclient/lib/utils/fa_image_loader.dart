import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import '../services/fa_client.dart';

/// FA-специфичный виджет для загрузки изображений.
/// Аналог iOS Kingfisher — кэширование, Referer заголовок, состояния загрузки.
///
/// Использует extended_image с правильными FA CDN заголовками.
/// На Windows cookies прокидываются через FAICookieManager автоматически.
class FAImage extends StatelessWidget {
  final String url;
  final FAClient? client;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final ExtendedImageMode mode;
  final GestureConfig? gestureConfig;

  const FAImage({
    super.key,
    required this.url,
    this.client,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.mode = ExtendedImageMode.none,
    this.gestureConfig,
  });

  static const Map<String, String> _faHeaders = {
    'Referer': 'https://www.furaffinity.net',
    'User-Agent': 'ceylo.FurAffinityApp/1.0',
    'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
  };

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) return _buildPlaceholder();

    return ExtendedImage.network(
      url,
      width: width,
      height: height,
      fit: fit,
      cache: true,
      headers: _faHeaders,
      mode: mode,
      initGestureConfigHandler: gestureConfig != null
          ? (_) => gestureConfig!
          : (state) => GestureConfig(
                minScale: 0.8,
                maxScale: 4.0,
                inPageView: false,
              ),
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return placeholder ?? _defaultPlaceholder();
          case LoadState.failed:
            return errorWidget ?? _defaultError();
          case LoadState.completed:
            return null; // рендерит сам
        }
      },
    );
  }

  Widget _buildPlaceholder() {
    return SizedBox(
      width: width,
      height: height,
      child: placeholder ?? _defaultPlaceholder(),
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
    final avatarUrl = 'https://a.furaffinity.net/$username.gif';
    return ClipOval(
      child: FAImage(
        url: avatarUrl,
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
