import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Режим транспорта для HTML-страниц FA.
enum TransportMode {
  /// Всё через WebView — прежнее поведение.
  webview,

  /// Прямой HTTP; при челлендже — WebView.
  http,

  /// HTTP первым, WebView как фолбэк. Значение по умолчанию.
  auto;

  static TransportMode fromName(String? name) => switch (name) {
        'webview' => TransportMode.webview,
        'http' => TransportMode.http,
        _ => TransportMode.auto,
      };

  String get storageName => switch (this) {
        TransportMode.webview => 'webview',
        TransportMode.http => 'http',
        TransportMode.auto => 'auto',
      };
}

/// Ответ прямого HTTP-фетча.
class HttpPageResult {
  const HttpPageResult({
    this.html,
    this.status,
    this.challenge = false,
    this.elapsed = Duration.zero,
    this.setCookies = const [],
    this.error,
  });

  final String? html;
  final int? status;

  /// Cloudflare отдал челлендж (403/503 + cf-mitigated или маркеры в HTML).
  final bool challenge;
  final Duration elapsed;

  /// Значения Set-Cookie из ответа — FA ротирует сессионные куки.
  final List<String> setCookies;
  final String? error;

  /// Настоящая страница, а не челлендж и не пустота.
  bool get ok => error == null && status == 200 && !challenge && html != null;

  @override
  String toString() => 'HttpPageResult(status: $status, challenge: $challenge, '
      'len: ${html?.length ?? 0}, ${elapsed.inMilliseconds}ms'
      '${error == null ? '' : ', error: $error'})';
}

/// Прямой HTTP-фетч страниц FA.
///
/// Работает, если у клиента есть валидный `cf_clearance` и UA того же
/// WebView, который этот clearance получил. Замер CFPROBE (Android,
/// эмулятор, живая страница /browse/):
///
/// | транспорт          | статус | сабмишенов | челлендж | время  |
/// |--------------------|--------|------------|----------|--------|
/// | WebView            | 200    | 72         | нет      | 6785 мс|
/// | HTTP, Dart TLS     | 200    | 72         | нет      | 2193 мс|
/// | HTTP, Chromium TLS | 200    | 72         | нет      | 1923 мс|
///
/// Без clearance тот же запрос получает 403 + `cf-mitigated: challenge`.
/// Значит WebView нужен как РЕШАТЕЛЬ CF (он исполняет JS и получает
/// clearance), а данные можно брать напрямую по HTTP — втрое быстрее.
class HttpPageTransport {
  HttpPageTransport({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Забрать страницу напрямую. Ошибки не бросает — результат в [HttpPageResult].
  Future<HttpPageResult> fetch(
    String url, {
    String? cookieHeader,
    required String userAgent,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final sw = Stopwatch()..start();
    try {
      final request = http.Request('GET', Uri.parse(url))
        ..headers.addAll({
          'User-Agent': userAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Referer': 'https://www.furaffinity.net/',
          if (cookieHeader != null) 'Cookie': cookieHeader,
        });
      final response = await _client.send(request).timeout(
            timeout,
            onTimeout: () => throw TimeoutException('HTTP timeout for $url'),
          );
      final body = await response.stream.bytesToString();
      sw.stop();

      final mitigated = response.headers['cf-mitigated']?.toLowerCase();
      final challenge = (response.statusCode == 403 ||
              response.statusCode == 503) &&
          (mitigated == 'challenge' || _looksLikeChallenge(body));

      return HttpPageResult(
        html: body,
        status: response.statusCode,
        challenge: challenge,
        elapsed: sw.elapsed,
        setCookies: response.headersSplitValues['set-cookie'] ?? const [],
      );
    } catch (e) {
      sw.stop();
      debugPrint('=== HttpPageTransport: failed for $url: $e');
      return HttpPageResult(
        status: null,
        elapsed: sw.elapsed,
        error: e.toString(),
      );
    }
  }

  /// Локаль-независимые маркеры CF-челленджа (те же, что у FAClient).
  static bool _looksLikeChallenge(String html) {
    if (html.isEmpty) return false;
    return html.contains('_cf_chl_opt') ||
        html.contains('cf-chl-widget') ||
        html.contains('cf_chl_page');
  }

  void close() => _client.close();
}
