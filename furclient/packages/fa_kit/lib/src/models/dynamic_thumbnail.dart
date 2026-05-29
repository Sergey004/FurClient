/// Dynamic thumbnail URL generator for FurAffinity images.
///
/// FA thumbnails have format: `...@{size}-...` with discrete sizes: 200, 300, 320, 400, 600.
/// The maximum allowed size is 600x600 pixels.
class DynamicThumbnail {
  final Uri _thumbnailUrl;

  static const List<int> _availableSizes = [200, 300, 320, 400, 600];

  DynamicThumbnail(this._thumbnailUrl);

  /// Get the raw thumbnail URL.
  Uri get thumbnailUrl => _thumbnailUrl;

  /// Get the best thumbnail URL for the requested size.
  ///
  /// [width] and [height] are the desired display dimensions.
  /// Returns the smallest available size that covers both dimensions.
  Uri bestThumbnailUrl({required double width, required double height}) {
    final maxDimension = width > height ? width : height;

    // Find the smallest size >= requested dimension
    int bestSize = _availableSizes.first;
    for (final size in _availableSizes) {
      if (size >= maxDimension) {
        bestSize = size;
        break;
      }
      bestSize = size; // Use the largest if none fit
    }

    // Cap at 600
    if (bestSize > 600) bestSize = 600;

    return _thumbnailUrlForSize(bestSize);
  }

  /// Get the best thumbnail URL fitting within the given max dimension.
  Uri bestThumbnailUrlForMaxSize(double maxDimension) {
    int bestSize = _availableSizes.first;
    for (final size in _availableSizes) {
      if (size >= maxDimension) {
        bestSize = size;
        break;
      }
      bestSize = size;
    }
    if (bestSize > 600) bestSize = 600;
    return _thumbnailUrlForSize(bestSize);
  }

  Uri _thumbnailUrlForSize(int size) {
    final urlStr = _thumbnailUrl.toString();
    final updated = urlStr.replaceFirstMapped(
      RegExp(r'@(\d+)-'),
      (match) => '@$size-',
    );
    return Uri.parse(updated);
  }
}
