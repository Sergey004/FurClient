import 'package:html/parser.dart' as html_parser;
import 'package:flutter/foundation.dart';
import 'package:cookie_jar/cookie_jar.dart';

import 'http_data_source.dart';
import 'fa_session.dart';
import 'fa_urls.dart';
import '../models/models.dart';
import '../utils/html_parser.dart';

/// Реализация FASession через HTTP запросы.
/// Аналог iOS OnlineFASession.
class OnlineSession implements FASession {
  @override
  final String username;

  @override
  final String displayUsername;

  final HttpDataSource _dataSource;
  final List<Cookie>? _cookies;

  final Map<String, Future<dynamic>> _pendingRequests = {};
  DateTime? _lastRequestTime;

  OnlineSession({
    required this.username,
    required this.displayUsername,
    required HttpDataSource dataSource,
    List<Cookie>? cookies,
  })  : _dataSource = dataSource,
        _cookies = cookies;

  Future<T> _cachedRequest<T>(
    String cacheKey,
    Future<T> Function() request,
  ) async {
    if (_pendingRequests.containsKey(cacheKey)) {
      return await (_pendingRequests[cacheKey]! as Future<T>);
    }
    final future = request();
    _pendingRequests[cacheKey] = future;
    try {
      final result = await future;
      _lastRequestTime = DateTime.now();
      return result;
    } finally {
      _pendingRequests.remove(cacheKey);
    }
  }

  Future<String> _fetch(String url) => _dataSource.httpData(
        url: Uri.parse(url),
        method: HttpMethod.get,
        cookies: _cookies,
      );

  @override
  Future<List<SubmissionPreview>> getSubmissionPreviews({
    int? startFromId,
  }) =>
      _cachedRequest(
        'submissions_${startFromId ?? 'latest'}',
        () async {
          final url = startFromId != null
              ? FAUrls.submissionsUrl(startFromId)
              : FAUrls.latest72SubmissionsUrl;
          final html = await _fetch(url);
          final previews = _parseSubmissionPreviews(html);
          debugPrint('Got ${previews.length} submission previews');
          return previews;
        },
      );

  @override
  Future<Submission> getSubmission(String url) =>
      _cachedRequest(
        'submission_$url',
        () async {
          final html = await _fetch(url);
          final document = html_parser.parse(html);
          return parseSubmissionFull(document, url);
        },
      );

  @override
  Future<List<SubmissionPreview>> getUserGallery(String username) =>
      _cachedRequest(
        'gallery_$username',
        () async {
          final html = await _fetch(FAUrls.userGalleryUrl(username));
          final previews = _parseSubmissionPreviews(html);
          debugPrint('Got ${previews.length} gallery previews for $username');
          return previews;
        },
      );

  @override
  Future<List<Comment>> getComments(String url) =>
      _cachedRequest(
        'comments_$url',
        () async {
          final html = await _fetch(url);
          final document = html_parser.parse(html);
          return parseComments(document);
        },
      );

  @override
  bool get isAuthenticated => username.isNotEmpty;

  List<SubmissionPreview> _parseSubmissionPreviews(String htmlString) {
    try {
      final document = html_parser.parse(htmlString);
      final previews = <SubmissionPreview>[];
      for (final fig in document.querySelectorAll('figure[id^="sid-"]')) {
        try {
          final preview = parseSubmissionPreview(fig);
          if (preview != null) previews.add(preview);
        } catch (e) {
          debugPrint('Failed to parse preview: $e');
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

  DateTime? get lastRequestTime => _lastRequestTime;
}
