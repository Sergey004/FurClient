import 'package:fa_kit/fa_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Глобальное качество отображения полноразмерных изображений. Оригинальный
/// URL остаётся в Submission и всегда используется для скачивания.
class FAImageQuality {
  static const preferenceKey = 'image_quality';
  static final ValueNotifier<String> current = ValueNotifier<String>('high');

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    current.value = _normalize(prefs.getString(preferenceKey));
  }

  static Future<void> setQuality(String quality) async {
    final normalized = _normalize(quality);
    current.value = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferenceKey, normalized);
  }

  static String _normalize(String? quality) =>
      quality == 'low' || quality == 'medium' ? quality! : 'high';

  /// High — оригинал, medium — FA preview 600, low — FA preview 300.
  /// Для видео, Flash и URL без thumbnail-вариантов остаётся оригинал.
  static String resolveUrl({
    required String fullUrl,
    String previewUrl = '',
    required String quality,
  }) {
    final normalized = _normalize(quality);
    if (normalized == 'high' || fullUrl.isEmpty || previewUrl.isEmpty) {
      return fullUrl;
    }
    final uri = Uri.tryParse(previewUrl);
    if (uri == null || !uri.path.contains('@')) return fullUrl;
    return DynamicThumbnail(uri)
        .bestThumbnailUrlForMaxSize(normalized == 'low' ? 300 : 600)
        .toString();
  }
}
