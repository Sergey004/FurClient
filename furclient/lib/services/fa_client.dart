import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'fa_urls.dart';

class CloudflareError implements Exception {
  final String message;
  CloudflareError()
      : message =
            'FA is currently protected by Cloudflare challenge. Please try again later.';

  @override
  String toString() => 'CloudflareError: $message';
}

class FAClient {
  UserSession? _session;
  late final Dio _dio;
  late CookieJar _cookieJar;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  static const String _userAgent = 'ceylo.FurAffinityApp/1.0';

  FAClient() {
    _dio = Dio(BaseOptions(
      headers: {
        'User-Agent': _userAgent,
      },
      validateStatus: (status) => status != null && status < 600,
      followRedirects: true,
      maxRedirects: 5,
    ));
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      return;
    }
    _initCompleter = Completer<void>();
    try {
      final appDocDir = await getApplicationSupportDirectory();
      final cookiePath = '${appDocDir.path}/.cookies';
      final cookieDir = Directory(cookiePath);
      if (!cookieDir.existsSync()) {
        cookieDir.createSync(recursive: true);
      }
      _cookieJar = PersistCookieJar(
        storage: FileStorage(cookiePath),
      );
      _dio.interceptors.add(CookieManager(_cookieJar));
      _initialized = true;
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }

  Future<void> init() async {
    await _ensureInitialized();
  }

  UserSession? get session => _session;

  Future<void> setSession(UserSession? session) async {
    _session = session;
    await _restoreCookiesFromSession();
  }

  Future<void> _restoreCookiesFromSession() async {
    if (_session?.cookies == null) return;
    await _ensureInitialized();
    try {
      final List<dynamic> cookiePairs = jsonDecode(_session!.cookies!);
      final cookies = <Cookie>[];
      for (final pair in cookiePairs) {
        if (pair is List && pair.length >= 2) {
          final name = pair[0].toString();
          final value = pair[1].toString();
          if (name.isNotEmpty && value.isNotEmpty) {
            final cookie = Cookie(name, value)
              ..domain = '.furaffinity.net'
              ..path = '/';
            cookies.add(cookie);
          }
        }
      }
      if (cookies.isNotEmpty) {
        await _cookieJar.saveFromResponse(
          Uri.parse(FAUrls.baseUrl),
          cookies,
        );
        debugPrint('=== Restored ${cookies.length} cookies from session');
      }
    } catch (e) {
      debugPrint('=== Error restoring cookies from session: $e');
    }
  }

  void _checkCloudflare(Response response) {
    final cfMitigated = response.headers.value('cf-mitigated');
    if (cfMitigated == 'challenge') {
      throw CloudflareError();
    }
  }

  Future<String> _getHtml(String url) async {
    await _ensureInitialized();
    final response = await _dio.get<String>(url);
    _checkCloudflare(response);
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'HTTP ${response.statusCode}',
      );
    }
    return response.data ?? '';
  }

  Future<bool> verifySession() async {
    if (_session?.cookies == null) return false;
    try {
      await _ensureInitialized();
      final response = await _dio.get<String>(FAUrls.home);
      final status = response.statusCode ?? 0;
      if (status == 401 || status == 403) return false;
      if (status >= 500) return true;
      if (status >= 200 && status < 300) return true;
      return false;
    } catch (_) {
      return true;
    }
  }

  Future<void> clearCookies() async {
    if (_initialized) {
      await _cookieJar.deleteAll();
    }
  }

  Future<List<Submission>> getSubmissions(int page, String category) async {
    final url = FAUrls.browse(filter: category, page: page);
    final html = await _getHtml(url);
    return Submission.parseSubmissionsPage(html);
  }

  Future<List<Submission>> getGallery(String username, {int page = 1}) async {
    final url = '${FAUrls.gallery(username)}?page=$page';
    final html = await _getHtml(url);
    return Submission.parseSubmissionsPage(html);
  }

  Future<Submission?> getSubmission(String id) async {
    final url = FAUrls.viewSubmission(id);
    final html = await _getHtml(url);
    return Submission.parseSubmissionDetails(html, id);
  }

  Future<List<FAComment>> getComments(String id) async {
    final url = FAUrls.viewSubmission(id);
    final html = await _getHtml(url);
    return FAComment.parseComments(html);
  }

  Future<List<Submission>> search(String query, {int page = 1}) async {
    final url = FAUrls.search(query, page: page);
    final html = await _getHtml(url);
    return Submission.parseSearchResults(html);
  }

  Future<List<FANotification>> getNotifications() async {
    final html = await _getHtml(FAUrls.notifications);
    return FANotification.parseNotifications(html);
  }

  Future<FAUser?> getUser(String username) async {
    final url = FAUrls.user(username);
    final html = await _getHtml(url);
    return FAUser.parseUserPage(html, username);
  }

  Future<FAUser?> getUserProfile(String username) async {
    if (username == 'me') {
      if (_session?.username != null && _session!.username != 'user') {
        return getUser(_session!.username);
      }
      return null;
    }
    return getUser(username);
  }

  Future<bool> toggleWatch(String username, bool currentlyWatching) async {
    final action = currentlyWatching ? 'unwatch' : 'watch';
    final url = '${FAUrls.baseUrl}/$action/$username/';
    await _ensureInitialized();
    await _dio.post<String>(url);
    return !currentlyWatching;
  }
}
