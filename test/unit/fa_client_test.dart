import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/services/fa_client.dart';

void main() {
  group('FAClient cookie merge', () {
    test(
        'keeps existing session cookies and overwrites with newer webview values',
        () {
      final existingCookies = [
        {
          'name': 'a',
          'value': 'session-a',
          'domain': '.furaffinity.net',
          'path': '/',
        },
        {
          'name': 'b',
          'value': 'session-b',
          'domain': '.furaffinity.net',
          'path': '/',
        },
      ];

      final incomingCookies = [
        {
          'name': 'cf_clearance',
          'value': 'new-clearance',
          'domain': '.furaffinity.net',
          'path': '/',
        },
        {
          'name': 'a',
          'value': 'updated-a',
          'domain': '.furaffinity.net',
          'path': '/',
        },
      ];

      final merged = FAClient.mergeCookiesForSession(
        existingCookies,
        incomingCookies,
      );

      expect(merged, hasLength(3));
      final aCookie = merged.firstWhere((cookie) => cookie['name'] == 'a');
      final cfCookie =
          merged.firstWhere((cookie) => cookie['name'] == 'cf_clearance');

      expect(aCookie['value'], 'updated-a');
      expect(cfCookie['value'], 'new-clearance');
    });
  });
}
