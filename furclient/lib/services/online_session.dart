import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'dart:async';

import 'http_data_source.dart';
import 'fa_session.dart';
import 'fa_urls.dart';
import '../models/models.dart';
import '../utils/html_parser.dart';

/// Реализация FASession, использующая онлайн источник (HTTP запросы)
/// Аналогично iOS OnlineFASession
class OnlineSession implements FASession {
  @override
  final String username;

  @override
  final String displayUsername;

  final HttpDataSource _dataSource;
  final List<Cookie>? _cookies;

  /// Кэш для предотвращения дублирующихся запросов
  final Map<String, Future<dynamic>> _pendingRequests = {};

  /// Время последнего успешного запроса (для отладки и мониторинга)
  DateTime? _lastRequestTime;

  OnlineSession({
    required this.username,
    required this.displayUsername,
    required HttpDataSource dataSource,
    List<Cookie>? cookies,
  })  : _dataSource = dataSource,
        _cookies = cookies;

  /// Кэширует запросы, чтобы избежать дублирования при одновременных запросах
  Future<T> _cachedRequest<T>(
    String cacheKey,
    Future<T> Function() request,
  ) async {
    if (_pendingRequests.containsKey(cacheKey)) {
      return _pendingRequests[cacheKey]! as Future<T>;
    }

    final future = request();
    _pendingRequests[cacheKey] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _pendingRequests.remove(cacheKey);
      _lastRequestTime = DateTime.now();
    }
  }

  @override
  Future<List<SubmissionPreview>> getSubmissionPreviews({
    int? startFromId,
  }) async {
    return _cachedRequest<List<SubmissionPreview>>(
      'submissions_${startFromId ?? 'latest'}',
      () async {
        final url = startFromId != null
            ? FAUrls.submissionsUrl(startFromId)
            : FAUrls.latest72SubmissionsUrl;

        final html = await _dataSource.getData(
          url: url,
          cookies: _cookies,
        );

        final previews = _parseSubmissionPreviews(html);
        debugPrint('Got ${previews.length} submission previews');
        return previews;
      },
    );
  }

  @override
  Future<SubmissionFull> getSubmission(String url) async {
    return _cachedRequest<SubmissionFull>(
      'submission_$url',
      () async {
        final uri = Uri.parse(url);
        final html = await _dataSource.getData(
          url: uri,
          cookies: _cookies,
        );

        final submission = _parseSubmissionFull(html, url);
        return submission;
      },
    ) as Future<SubmissionFull>;
  }

  @override
  Future<List<SubmissionPreview>> getUserGallery(String username) async {
    return _cachedRequest<List<SubmissionPreview>>(
      'gallery_$username',
      () async {
        final url = FAUrls.userGalleryUrl(username);
        final html = await _dataSource.getData(
          url: url,
          cookies: _cookies,
        );

        final previews = _parseSubmissionPreviews(html);
        debugPrint('Got ${previews.length} gallery previews for $username');
        return previews;
      },
    ) as Future<List<SubmissionPreview>>;
  }

  // Убрали дублирующийся метод
  Future<List<SubmissionPreview>> _getGalleryOld(String username) async {
    return _cachedRequest<List<SubmissionPreview>>(
      'gallery_$username',
      () async {
        final url = FAUrls.userGalleryUrl(username);
        final html = await _dataSource.getData(
          url: url,
          cookies: _cookies,
        );

        final previews = _parseSubmissionPreviews(html);
        debugPrint('Got ${previews.length} gallery previews for $username');
        return previews;
      },
    );
  }

  @override
  Future<List<Comment>> getComments(String url) async {
    return _cachedRequest<List<Comment>>(
      'comments_$url',
      () async {
        final uri = Uri.parse(url);
        final html = await _dataSource.getData(
          url: uri,
          cookies: _cookies,
        );

        final comments = _parseComments(html);
        debugPrint('Got ${comments.length} comments');
        return comments;
      },
    );
  }

  @override
  bool get isAuthenticated => username.isNotEmpty;

  // ──── Парсинг HTML ─────────────────────────────────────────────

  /// Парсит превью submission'ов со страницы списка
  List<SubmissionPreview> _parseSubmissionPreviews(String htmlString) {
    try {
      final document = html_parser.parse(htmlString);
      final previews = <SubmissionPreview>[];

      // Селектор: figure[id^="sid-"] - аналог iOS FASubmissionsPage
      final figures = document.querySelectorAll('figure[id^="sid-"]');

      for (final fig in figures) {
        try {
          final preview = _parseSubmissionPreviewElement(fig);
          if (preview != null) {
            previews.add(preview);
          }
        } catch (e) {
          debugPrint('Failed to parse submission preview: $e');
          continue;
        }
      }

      return previews;
    } catch (e) {
      throw FASessionException(
        'Failed to parse submission previews',
        originalException: e as Exception,
      );
    }
  }

  /// Парсит один элемент превью
  SubmissionPreview? _parseSubmissionPreviewElement(dynamic element) {
    try {
      // Парсим используя существующий парсер из utils
      return parseSubmissionPreview(element);
    } catch (e) {
      debugPrint('Error parsing submission preview element: $e');
      return null;
    }
  }

  /// Парсит полную информацию о submission'е
  SubmissionFull _parseSubmissionFull(String htmlString, String url) {
    try {
      final document = html_parser.parse(htmlString);
      return parseSubmissionFull(document, url);
    } catch (e) {
      throw FASessionException(
        'Failed to parse submission full page',
        originalException: e as Exception,
      );
    }
  }

  /// Парсит комментарии
  List<Comment> _parseComments(String htmlString) {
    try {
      final document = html_parser.parse(htmlString);
      return parseComments(document);
    } catch (e) {
      throw FASessionException(
        'Failed to parse comments',
        originalException: e as Exception,
      );
    }
  }

  /// Возвращает время последнего успешного запроса (для отладки)
  DateTime? get lastRequestTime => _lastRequestTime;
}
