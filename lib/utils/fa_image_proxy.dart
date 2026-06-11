import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../utils/cookie_manager.dart';
import '../utils/cookie_store.dart';

/// Локальный HTTP прокси для FA CDN изображений.
///
/// Проблема: extended_image делает запросы напрямую из Dart —
/// без cookies из WebView2 профиля и с другим TLS fingerprint.
/// CF видит запрос без cf_clearance → блокирует.
///
/// Решение: прокси читает cookies из FAICookieManager (WebView2 профиль)
/// и прокидывает их в каждый запрос — точный аналог iOS setCookies() перед data(for:)
class FAImageProxy {
  static const String _host = '127.0.0.1';
  static const int _port = 47652;
  static const String _proxyPath = '/fa-proxy';

  HttpServer? _server;
  late final Dio _dio;
  bool _running = false;

  static final FAImageProxy _instance = FAImageProxy._();
  factory FAImageProxy() => _instance;
  FAImageProxy._() {
    _dio = Dio(BaseOptions(
      headers: {
        'User-Agent': 'ceylo.FurAffinityApp/1.0',
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        'Referer': 'https://www.furaffinity.net',
      },
      responseType: ResponseType.bytes,
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (s) => s != null && s < 600,
      receiveTimeout: const Duration(seconds: 15),
      connectTimeout: const Duration(seconds: 10),
    ));
  }

  bool get isRunning => _running;

  /// Запустить прокси сервер.
  Future<void> start() async {
    if (_running) return;
    try {
      _server = await HttpServer.bind(_host, _port, shared: true);
      _running = true;
      debugPrint('[FAImageProxy] Started on $_host:$_port');
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('[FAImageProxy] Server error: $e');
      });
    } catch (e) {
      debugPrint('[FAImageProxy] Failed to start: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _running = false;
  }

  /// Превращает оригинальный CDN URL в прокси URL.
  /// extended_image запрашивает этот URL — прокси подставляет cookies и форвардит.
  static String proxyUrl(String originalUrl) {
    if (!_shouldProxy(originalUrl)) return originalUrl;
    final encoded = Uri.encodeComponent(originalUrl);
    return 'http://$_host:$_port$_proxyPath?url=$encoded';
  }

  /// Проксируем только FA CDN домены.
  static bool _shouldProxy(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host == 't.furaffinity.net' ||
          uri.host == 'd.furaffinity.net' ||
          uri.host == 'a.furaffinity.net' ||
          uri.host.endsWith('.furaffinity.net');
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final urlParam = request.uri.queryParameters['url'];
      if (urlParam == null || urlParam.isEmpty) {
        request.response.statusCode = 400;
        await request.response.close();
        return;
      }

      final targetUrl = Uri.decodeComponent(urlParam);

      // Читаем cookies из WebView2 профиля — как iOS setCookies() перед data(for:)
      final cookieHeader = await _buildCookieHeader();

      final headers = <String, dynamic>{
        'User-Agent': 'ceylo.FurAffinityApp/1.0',
        'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8',
        'Referer': 'https://www.furaffinity.net',
      };
      if (cookieHeader != null) headers['Cookie'] = cookieHeader;

      final response = await _dio.get<List<int>>(
        targetUrl,
        options: Options(headers: headers, responseType: ResponseType.bytes),
      );

      if (response.statusCode == null || response.statusCode! >= 400) {
        request.response.statusCode = response.statusCode ?? 502;
        await request.response.close();
        return;
      }

      final contentType =
          response.headers.value('content-type') ?? 'image/jpeg';
      request.response.headers.set('Content-Type', contentType);
      request.response.headers.set('Cache-Control', 'public, max-age=86400');
      request.response.statusCode = 200;

      if (response.data != null) {
        request.response.add(response.data!);
      }
      await request.response.close();
    } catch (e) {
      debugPrint('[FAImageProxy] Request error: $e');
      try {
        request.response.statusCode = 502;
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<String?> _buildCookieHeader() async {
    try {
      final cookies = await FAICookieManager.getCookies(
        'https://www.furaffinity.net',
      );
      if (cookies.isEmpty) return null;

      // Синхронизуем в CookieStore — чтобы cf_clearance был доступен для
      // не-прокси запросов (на Android/iOS)
      final ioCookies = cookies.map((c) {
        final io = Cookie(c.name, c.value ?? '');
        io.domain = c.domain ?? '.furaffinity.net';
        io.path = c.path ?? '/';
        return io;
      }).toList();
      CookieStore.instance.setCookies(ioCookies);

      return cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (e) {
      debugPrint('[FAImageProxy] Cookie error: $e');
      // Fallback на CookieStore если WebView2 недоступен
      return CookieStore.instance.cookieHeader;
    }
  }
}
