import 'dart:async';
import 'dart:io' show Platform;

import 'package:cronet_http/cronet_http.dart';
import 'package:fa_kit/fa_kit.dart' as fa;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/cookie_manager.dart';
import 'fa_client.dart';

/// Итог одной попытки забрать страницу конкретным транспортом.
class ProbeResult {
  const ProbeResult({
    required this.transport,
    required this.status,
    required this.length,
    required this.challenge,
    required this.items,
    required this.elapsed,
    this.error,
  });

  /// Имя транспорта: webview / http-dart / http-cronet.
  final String transport;
  final int? status;
  final int length;

  /// Cloudflare-челлендж в теле ответа (локаль-независимые маркеры).
  final bool challenge;

  /// Сколько сабмишенов распарсилось — показатель «страница настоящая».
  final int items;
  final Duration elapsed;
  final String? error;

  /// Транспорт отдал настоящую страницу.
  bool get ok => error == null && status == 200 && !challenge && items > 0;

  @override
  String toString() => '=== CFPROBE $transport: status=$status len=$length '
      'items=$items challenge=$challenge ${elapsed.inMilliseconds}ms'
      '${error == null ? '' : ' error=$error'}';
}

/// Проба транспорта: сравнивает текущий путь (WebView) с прямым HTTP.
///
/// Зачем: переезд на HTTP-сессионный слой (fa_kit `OnlineFASession`) упирается
/// в Cloudflare. Прямой запрос с куками и UA WebView может получить челлендж
/// вместо страницы — и тогда весь план миграции не имеет смысла. Меряем ДО
/// переписывания транспорта, на живой странице.
///
/// Ничего не меняет в боевых путях: только читает.
class TransportProbe {
  static const String probeUrl = 'https://www.furaffinity.net/browse/';

  /// Запустить все варианты и вернуть результаты по каждому.
  static Future<List<ProbeResult>> run(FAClient client) async {
    final results = <ProbeResult>[];

    // 1. Эталон — нынешний боевой путь через WebView.
    results.add(await _probeWebView(client));

    // 2. Куки берём из живого стора WebView.
    var cookieHeader = await _liveCookieHeader();

    // 2a. Если clearance не выдан — заставляем CF выдать его: чистим CF-куки
    // и снова грузим страницу через WebView. На Android headless-WebView
    // проходит челлендж сам, поэтому clearance оказывается в сторе.
    if (!(await _hasClearance())) {
      debugPrint('=== CFPROBE: no cf_clearance — forcing challenge via WebView');
      await client.clearCloudflareCookies();
      results.add(await _probeWebView(client));
      await Future<void>.delayed(const Duration(seconds: 2));
      cookieHeader = await _liveCookieHeader();
    }

    final names = await _cookieNames();
    debugPrint('=== CFPROBE: cookies used: $names');
    debugPrint('=== CFPROBE: cf_clearance present: ${names.contains('cf_clearance')}');

    // 3. Прямой HTTP на Dart TLS (как ходит fa_kit OnlineFASession).
    results.add(await _probeHttp(client, cookieHeader, 'http-dart'));

    // 4. Прямой HTTP на Chromium TLS (Android) — если доступен.
    if (Platform.isAndroid) {
      results.add(await _probeCronet(cookieHeader));
    }

    return results;
  }

  // ── WebView (эталон) ───────────────────────────────────────────────

  static Future<ProbeResult> _probeWebView(FAClient client) async {
    final sw = Stopwatch()..start();
    try {
      final html = await client.getHtml(probeUrl);
      sw.stop();
      final items = _countItems(html);
      return ProbeResult(
        transport: 'webview',
        status: 200,
        length: html.length,
        challenge: FAClient.isCloudflarePageHtml(html),
        items: items,
        elapsed: sw.elapsed,
      );
    } catch (e) {
      sw.stop();
      return ProbeResult(
        transport: 'webview',
        status: null,
        length: 0,
        challenge: false,
        items: 0,
        elapsed: sw.elapsed,
        error: e.toString(),
      );
    }
  }

  // ── Прямой HTTP ────────────────────────────────────────────────────

  static Future<ProbeResult> _probeHttp(
      FAClient client, String? cookieHeader, String label) async {
    final sw = Stopwatch()..start();
    final httpClient = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(probeUrl))
        ..headers.addAll(_headers(cookieHeader));
      final response = await httpClient.send(request).timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('HTTP timeout'),
          );
      final body = await response.stream.bytesToString();
      sw.stop();
      return ProbeResult(
        transport: label,
        status: response.statusCode,
        length: body.length,
        challenge: FAClient.isCloudflarePageHtml(body),
        items: _countItems(body),
        elapsed: sw.elapsed,
        error: _cfMitigated(response.headers),
      );
    } catch (e) {
      sw.stop();
      return ProbeResult(
        transport: label,
        status: null,
        length: 0,
        challenge: false,
        items: 0,
        elapsed: sw.elapsed,
        error: e.toString(),
      );
    } finally {
      httpClient.close();
    }
  }

  /// Тот же запрос, но через Chromium TLS (Cronet) — на Android это тот же
  /// стек, что у настоящего браузера, поэтому Cloudflare к нему мягче,
  /// чем к Dart TLS.
  static Future<ProbeResult> _probeCronet(String? cookieHeader) async {
    final sw = Stopwatch()..start();
    try {
      final engine = CronetEngine.build(
        userAgent: FAClient.webViewUserAgent,
        enableHttp2: true,
        enableQuic: true,
        enableBrotli: true,
      );
      final cronet = CronetClient.fromCronetEngine(engine);
      try {
        final request = http.Request('GET', Uri.parse(probeUrl))
          ..headers.addAll(_headers(cookieHeader));
        final response = await cronet.send(request).timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Cronet timeout'),
            );
        final body = await response.stream.bytesToString();
        sw.stop();
        return ProbeResult(
          transport: 'http-cronet',
          status: response.statusCode,
          length: body.length,
          challenge: FAClient.isCloudflarePageHtml(body),
          items: _countItems(body),
          elapsed: sw.elapsed,
          error: _cfMitigated(response.headers),
        );
      } finally {
        cronet.close();
      }
    } catch (e) {
      sw.stop();
      return ProbeResult(
        transport: 'http-cronet',
        status: null,
        length: 0,
        challenge: false,
        items: 0,
        elapsed: sw.elapsed,
        error: e.toString(),
      );
    }
  }

  // ── Вспомогательное ────────────────────────────────────────────────

  static Map<String, String> _headers(String? cookieHeader) => {
        'User-Agent': FAClient.webViewUserAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Referer': 'https://www.furaffinity.net/',
        if (cookieHeader != null) 'Cookie': cookieHeader,
      };

  /// Cookie-заголовок из живого стора WebView (включая cf_clearance,
  /// который CF мог выдать во время webview-запроса).
  static Future<String?> _liveCookieHeader() async {
    try {
      final cookies = await FAICookieManager.getCookies(
          'https://www.furaffinity.net');
      final parts = cookies
          .where((c) => c.name.isNotEmpty && c.value.isNotEmpty)
          .map((c) => '${c.name}=${c.value}')
          .toList();
      return parts.isEmpty ? null : parts.join('; ');
    } catch (e) {
      debugPrint('=== CFPROBE: cookie header failed: $e');
      return null;
    }
  }

  /// Имена кук в сторе (значения не светим).
  static Future<List<String>> _cookieNames() async {
    try {
      final cookies = await FAICookieManager.getCookies(
          'https://www.furaffinity.net');
      return cookies.map((c) => c.name).toList()..sort();
    } catch (e) {
      debugPrint('=== CFPROBE: cookie names failed: $e');
      return const [];
    }
  }

  static Future<bool> _hasClearance() async =>
      (await _cookieNames()).contains('cf_clearance');

  /// Сколько сабмишенов на странице — «страница настоящая» (не челлендж).
  static int _countItems(String html) {
    if (html.isEmpty) return 0;
    try {
      final page = fa.FASubmissionsPage.parse(html, Uri.parse(probeUrl));
      return page.submissions.where((s) => s != null).length;
    } catch (_) {
      return 0;
    }
  }

  /// Заголовок `cf-mitigated: challenge` — официальный признак того, что
  /// Cloudflare отдала челлендж вместо страницы.
  static String? _cfMitigated(Map<String, String> headers) {
    final value = headers['cf-mitigated'];
    if (value == null) return null;
    return 'cf-mitigated=$value';
  }
}

/// Печать результатов пробы в лог (одиночная строка на транспорт).
void logProbeResults(List<ProbeResult> results) {
  for (final r in results) {
    debugPrint(r.toString());
  }
  final winners = results.where((r) => r.ok).map((r) => r.transport).toList();
  debugPrint('=== CFPROBE: workable transports: $winners');
}
