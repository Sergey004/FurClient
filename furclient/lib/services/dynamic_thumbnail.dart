import 'package:flutter/material.dart';

/// Умная система для выбора оптимального размера thumbnail'а
/// Аналогично iOS DynamicThumbnail из FAKit
///
/// FurAffinity поддерживает несколько предустановленных размеров:
/// 200, 300, 320, 400, 600 пикселей (макс)
class DynamicThumbnail {
  static const List<int> supportedSizes = [200, 300, 320, 400, 600];
  static const int maximumSize = 600;

  /// Original thumbnail URL (e.g., https://.../@300-submission123.jpg)
  final String _url;

  DynamicThumbnail(this._url);

  /// Возвращает оптимальный URL для заданного размера
  ///
  /// Выбирает ближайший поддерживаемый размер, не меньший чем requested
  String getOptimalUrl(double requestedSize) {
    final size = requestedSize.toInt().clamp(0, maximumSize);

    // Находим ближайший поддерживаемый размер
    final optimalSize = supportedSizes.firstWhere(
      (s) => s >= size,
      orElse: () => supportedSizes.last,
    );

    return _replaceSize(optimalSize);
  }

  /// Возвращает оптимальный URL для размера элемента на экране
  String getOptimalUrlForWidget(Size size) {
    final maxDimension = size.width > size.height ? size.width : size.height;
    return getOptimalUrl(maxDimension);
  }

  /// Заменяет размер в URL
  /// Ожидает формат: https://.../@300-... → https://.../@600-...
  String _replaceSize(int newSize) {
    final regex = RegExp(r'(@)(\d+)(-.+)');
    return _url.replaceAllMapped(regex, (match) {
      return '${match.group(1)}$newSize${match.group(3)}';
    });
  }

  /// Возвращает URL в полном разрешении (если возможно)
  /// Обычно это максимальный поддерживаемый размер
  String getFullResolutionUrl() => _replaceSize(maximumSize);
}

/// Хелпер для преобразования aspect ratio thumbnail'ов
///
/// FurAffinity возвращает: widthOnHeightRatio = width / height
/// Для получения правильной высоты: height = width / ratio
extension ThumbnailAspectRatio on double {
  /// Вычисляет высоту контейнера для заданной ширины и соотношения сторон
  ///
  /// Пример: width=300, ratio=1.5 → height=200
  double heightForWidth(double width) => width / this;

  /// Вычисляет высоту для Fill режима (заполнение ширины)
  ///
  /// Используется когда элемент должен занимать всю доступную ширину
  Size sizeForFillWidth(double containerWidth) {
    final height = heightForWidth(containerWidth);
    return Size(containerWidth, height);
  }
}
