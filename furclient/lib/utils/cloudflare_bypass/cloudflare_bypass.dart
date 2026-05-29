import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'storage.dart';
import 'useragents.dart';
import '../../main.dart' show webViewEnvironment;

Future<String?> cloudflareBypass({
  required String url,
  required String id,
  required String method,
}) async {
  String? html;
  bool isOk = false;
  int count = 0;
  Map<String, String> headers = await getHeaders();
  String useragent = UserAgents.getChromeWindows();
  
  debugPrint('=== CF bypass: Starting for $url');
  
  HeadlessInAppWebView? headlessWebView;
  headlessWebView = HeadlessInAppWebView(
    webViewEnvironment: webViewEnvironment,
    onLoadStop: (controller, u) async {
      html = await controller.getHtml();
      debugPrint('=== CF bypass: Initial HTML length: ${html?.length ?? 0}');
      
      await Future.doWhile(() async {
        count++;
        html = await controller.getHtml();
        
        debugPrint('=== CF bypass: Attempt $count, HTML length: ${html?.length ?? 0}');
        
        if (html == null ||
            html!.contains("Just a moment") ||
            html!.contains("challenges.cloudflare.com") ||
            html!.contains("DDoS protection by") ||
            html!.contains("Verify you are human")) {
          // Ждем еще 1 секунду и пробуем снова
          await Future.delayed(const Duration(seconds: 1));
          return true;
        }
        
        // Если прошло много попыток и все еще Cloudflare, сохраняем cookie
        if (count > 40) {
          debugPrint('=== CF bypass: Many attempts, saving cf_clearance...');
          await saveCookie(url, id);
          return false;
        }
        
        // Если нет Cloudflare, завершаем
        debugPrint('=== CF bypass: Cloudflare resolved!');
        return false;
      });
      
      // Финальная проверка
      html = await controller.getHtml();
      debugPrint('=== CF bypass: Final HTML length: ${html?.length ?? 0}');
      
      await Future.delayed(const Duration(seconds: 1));
      isOk = true;
    },
    onReceivedHttpError: (controller, request, response) async {
      if (request.isForMainFrame ?? false) {
        debugPrint('=== CF bypass: HTTP error: ${response.statusCode}');
      }
    },
    onReceivedError: (controller, request, error) async {
      if (request.isForMainFrame ?? false) {
        debugPrint('=== CF bypass: Error: ${error.description}');
      }
    },
    initialSettings: InAppWebViewSettings(
      userAgent: useragent,
      javaScriptEnabled: true,
    ),
    initialUrlRequest: URLRequest(
      headers: headers,
      method: method,
      url: WebUri(url),
    ),
  );

  await headlessWebView.run();
  await Future.doWhile(() async {
    await Future.delayed(const Duration(seconds: 2));
    if (isOk == true) {
      headlessWebView?.dispose();
      return false;
    }
    return true;
  });

  return html;
}

Future<Map<String, String>> getHeaders() async {
  Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'gzip, deflate, br',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
  };
  return headers;
}

Future<void> saveCookie(String url, String id) async {
  final cookieManager = CookieManager.instance();
  final cookies = await cookieManager.getCookies(url: WebUri(url));
  
  for (final cookie in cookies) {
    if (cookie.name == 'cf_clearance') {
      debugPrint('=== CF bypass: Found cf_clearance: ${cookie.value}');
      final cookieMain = CookieMain();
      await cookieMain.setCookie(id, jsonEncode({
        'name': cookie.name,
        'value': cookie.value,
        'domain': cookie.domain,
        'path': cookie.path,
        'expires': cookie.expiresDate is DateTime 
            ? (cookie.expiresDate as DateTime).toIso8601String()
            : null,
        'isSecure': cookie.isSecure,
        'isHttpOnly': cookie.isHttpOnly,
      }));
      break;
    }
  }
}

