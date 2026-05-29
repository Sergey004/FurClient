import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Вспомогательный класс для работы с cookies
class CookieHelper {
  /// Парсит JSON строку cookies и возвращает список Cookie объектов
  static List<Cookie> parseCookiesFromJson(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> data = jsonDecode(jsonString);
      return data.map((e) => _mapToCookie(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('=== Error parsing cookies from JSON: $e');
      return [];
    }
  }

  /// Конвертирует список Cookie объектов в JSON строку
  static String cookiesToJson(List<Cookie> cookies) {
    try {
      final List<Map<String, dynamic>> data = cookies
          .map((c) => {
                'name': c.name,
                'value': c.value ?? '',
                'domain': c.domain ?? '.furaffinity.net',
                'path': c.path ?? '/',
                'isHttpOnly': c.isHttpOnly ?? false,
                'isSecure': c.isSecure ?? true,
                'expiresDate': c.expiresDate is int ? c.expiresDate as int : 0,
              })
          .toList();
      return jsonEncode(data);
    } catch (e) {
      debugPrint('=== Error converting cookies to JSON: $e');
      return '[]';
    }
  }

  /// Форматирует cookies в Netscape format (как они показаны в примере)
  /// .furaffinity.net	TRUE	/	TRUE	1786435447	b	хххх
  static String cookiesToNetscapeFormat(List<Cookie> cookies) {
    final buffer = StringBuffer();
    buffer.writeln(
      '# Netscape HTTP Cookie File\n'
      '# This is a generated file!  Do not edit.\n',
    );

    for (final c in cookies) {
      final domain = c.domain ?? '.furaffinity.net';
      final path = c.path ?? '/';
      final httpOnly = (c.isHttpOnly ?? false) ? 'TRUE' : 'FALSE';
      final secure = (c.isSecure ?? true) ? 'TRUE' : 'FALSE';
      final expires = c.expiresDate is int ? c.expiresDate as int : 0;
      final name = c.name;
      final value = c.value ?? '';

      buffer.writeln(
          '$domain\t$httpOnly\t$path\t$secure\t$expires\t$name\t$value');
    }

    return buffer.toString();
  }

  /// Получает специфичные для FA cookies
  static Map<String, String> getFACookies(List<Cookie> cookies) {
    final faCookies = <String, String>{};

    // Важные cookies для FurAffinity
    const requiredCookies = ['a', 'b', 'cf_clearance', 'sz'];

    for (final required in requiredCookies) {
      final cookie = cookies.firstWhere(
        (c) => c.name.toLowerCase() == required.toLowerCase(),
        orElse: () => Cookie(name: ''),
      );
      if (cookie.value != null && cookie.value!.isNotEmpty) {
        faCookies[required] = cookie.value!;
      }
    }

    return faCookies;
  }

  /// Логирует cookies для отладки
  static void logCookies(List<Cookie> cookies) {
    debugPrint('=== === Extracted Cookies === ===');
    for (final c in cookies) {
      final value = c.value ?? '';
      final displayValue =
          value.length > 20 ? '${value.substring(0, 20)}...' : value;
      debugPrint(
        'Cookie: ${c.name}\n'
        '  Domain: ${c.domain}\n'
        '  Path: ${c.path}\n'
        '  Secure: ${c.isSecure}\n'
        '  HttpOnly: ${c.isHttpOnly}\n'
        '  Value: $displayValue',
      );
    }
    debugPrint('=== === === === === === === ===');
  }

  static Cookie _mapToookie(Map<String, dynamic> map) {
    final expiresDateMs = map['expiresDate'] as int?;

    return Cookie(
      name: map['name'] as String? ?? '',
      value: map['value'] as String?,
      domain: map['domain'] as String?,
      path: map['path'] as String?,
      isSecure: map['isSecure'] as bool? ?? true,
      isHttpOnly: map['isHttpOnly'] as bool? ?? false,
      expiresDate: expiresDateMs,
    );
  }

  // Alias для исправления опечатки
  static Cookie _mapToCookie(Map<String, dynamic> map) => _mapToookie(map);
}

// Extension для удобства
extension CookieListExtension on List<Cookie> {
  String toJson() => CookieHelper.cookiesToJson(this);

  String toNetscapeFormat() => CookieHelper.cookiesToNetscapeFormat(this);

  Map<String, String> getFACookies() => CookieHelper.getFACookies(this);

  void logCookies() => CookieHelper.logCookies(this);
}
