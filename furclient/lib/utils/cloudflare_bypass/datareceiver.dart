import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http_client;
import 'cloudflare_bypass.dart';
import 'storage.dart';

Future<String> httpRequest(String url, String id) async {
  try {
    final urlData = jsonDecode(url) as Map<String, dynamic>;
    final headersMap = urlData["headers"] as Map<String, dynamic>?;
    final isCloudflare = urlData["isCloudflare"] as String?;
    final method = urlData["method"] as String;
    final requestUrl = urlData["url"] as String;

    debugPrint('=== CF receiver: Requesting $requestUrl');

    final cookieMain = CookieMain();
    var cookieEncoded = await cookieMain.getData(id);
    
    // Если Cloudflare и нет сохраненного cookie, выполняем обход
    if (isCloudflare == "yes" && cookieEncoded == null) {
      debugPrint('=== CF receiver: No cf_clearance found, bypassing...');
      return await bypassCloudflare(url, id, method);
    }
    
    // Собираем заголовки
    Map<String, String> headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.5',
    };
    
    // Если есть сохраненный cookie, добавляем его
    if (cookieEncoded != null) {
      try {
        final cookieData = jsonDecode(cookieEncoded) as Map<String, dynamic>;
        final cookieValue = '${cookieData["name"]}=${cookieData["value"]}';
        headers['Cookie'] = cookieValue;
        debugPrint('=== CF receiver: Using saved cookie: $cookieValue');
      } catch (e) {
        debugPrint('=== CF receiver: Error decoding cookie: $e');
      }
    }
    
    // Добавляем дополнительные заголовки из параметров
    if (headersMap != null) {
      headers.addAll(headersMap.map((key, value) => MapEntry(key.toString(), value.toString())));
    }

    // Выполняем запрос
    http_client.Response response;
    if (method.toUpperCase() == 'GET') {
      response = await http_client.get(Uri.parse(requestUrl), headers: headers);
    } else if (method.toUpperCase() == 'POST') {
      response = await http_client.post(Uri.parse(requestUrl), headers: headers);
    } else {
      response = await http_client.get(Uri.parse(requestUrl), headers: headers);
    }

    debugPrint('=== CF receiver: Status code: ${response.statusCode}');
    
    if (response.statusCode == 403) {
      debugPrint('=== CF receiver: Cloudflare detected, retrying...');
      return await bypassCloudflare(url, id, method);
    } else if (response.statusCode != 200) {
      return "error";
    } else {
      return response.body;
    }
  } catch (e) {
    debugPrint('=== CF receiver: Error: $e');
    return "error";
  }
}

Future<String> bypassCloudflare(String url, String id, String method) async {
  debugPrint('=== CF receiver: Starting bypass...');
  final result = await cloudflareBypass(
    url: jsonDecode(url)["url"], 
    id: id, 
    method: method
  );
  
  if (result == null) {
    return "empty";
  }
  
  debugPrint('=== CF receiver: Bypass completed, HTML length: ${(result['html'] as String?)?.length ?? 0}');
  return result['html'] as String? ?? "empty";
}
