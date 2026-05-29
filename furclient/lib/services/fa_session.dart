import 'package:flutter/foundation.dart';

import '../models/models.dart';

/// Абстрактный интерфейс для сессии с FurAffinity
/// Аналогично iOS FASession протоколу
///
/// Отделяет логику работы с сессией от конкретной реализации
@immutable
abstract interface class FASession {
  String get username;
  String get displayUsername;

  /// Получает превью собственных submission'ов
  ///
  /// [startFromId] - ID первого submission'а (в хронологическом порядке)
  /// Если null, возвращает последние submission'ы
  Future<List<SubmissionPreview>> getSubmissionPreviews({
    int? startFromId,
  });

  /// Получает полную информацию о submission'е
  Future<Submission> getSubmission(String url);

  /// Получает галерею пользователя (лайки или галерея)
  Future<List<SubmissionPreview>> getUserGallery(String username);

  /// Получает комментарии к submission'у или журналу
  Future<List<Comment>> getComments(String url);

  /// Проверяет, авторизован ли пользователь
  bool get isAuthenticated;
}

/// Превью submission'а для списков
@immutable
class SubmissionPreview {
  final String id;
  final String title;
  final String author;
  final String displayAuthor;
  final String thumbnailUrl;
  final double widthOnHeightRatio;
  final String submissionUrl;
  final bool isNsfw;

  const SubmissionPreview({
    required this.id,
    required this.title,
    required this.author,
    required this.displayAuthor,
    required this.thumbnailUrl,
    required this.widthOnHeightRatio,
    required this.submissionUrl,
    required this.isNsfw,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubmissionPreview &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Расширенная информация о submission'е (полная страница)
@immutable
class SubmissionFull {
  final String id;
  final String title;
  final String author;
  final String displayAuthor;
  final String description;
  final String previewImageUrl;
  final String fullResolutionMediaUrl;
  final double widthOnHeightRatio;
  final String category;
  final List<String> tags;
  final DateTime uploadDate;
  final int views;
  final int favorites;
  final bool isFavorite;
  final bool isNsfw;
  final String favoriteUrl;
  final List<Comment> comments;
  final bool acceptsNewComments;

  const SubmissionFull({
    required this.id,
    required this.title,
    required this.author,
    required this.displayAuthor,
    required this.description,
    required this.previewImageUrl,
    required this.fullResolutionMediaUrl,
    required this.widthOnHeightRatio,
    required this.category,
    required this.tags,
    required this.uploadDate,
    required this.views,
    required this.favorites,
    required this.isFavorite,
    required this.isNsfw,
    required this.favoriteUrl,
    required this.comments,
    required this.acceptsNewComments,
  });
}

/// Комментарий к submission'у или журналу
@immutable
class Comment {
  final int id;
  final String author;
  final String displayAuthor;
  final String content;
  final DateTime date;
  final String authorAvatarUrl;
  final List<Comment> replies;
  final bool isDeleted;

  const Comment({
    required this.id,
    required this.author,
    required this.displayAuthor,
    required this.content,
    required this.date,
    required this.authorAvatarUrl,
    this.replies = const [],
    this.isDeleted = false,
  });
}

/// Исключение при работе с сессией
class FASessionException implements Exception {
  final String message;
  final Exception? originalException;

  FASessionException(this.message, {this.originalException});

  @override
  String toString() => 'FASessionException: $message';
}
