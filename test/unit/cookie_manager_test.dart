import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/utils/cookie_manager.dart';

void main() {
  group('FAICookieManager', () {
    setUp(() async {
      await FAICookieManager.loadCookies();
    });

    test('should load cookies', () async {
      await FAICookieManager.loadCookies();
      // Should not throw
    });

    test('should parse and store cookies', () {
      FAICookieManager.parseAndStoreCookies(
        'session=abc123; Path=/; Domain=.furaffinity.net',
        '.furaffinity.net',
      );
      expect(FAICookieManager.cookieCount, greaterThan(0));
    });

    test('should validate cookies', () {
      final result = FAICookieManager.validate();
      expect(result.isValid, isA<bool>());
      expect(result.totalCookies, greaterThanOrEqualTo(0));
    });

    test('should clean expired optional cookies', () {
      FAICookieManager.cleanExpiredOptionalCookies();
      // Should not throw
    });

    test('should get cookie names', () {
      final names = FAICookieManager.cookieNames;
      expect(names, isA<List<String>>());
    });
  });

  group('CookieValidationResult', () {
    test('should create valid result', () {
      final result = CookieValidationResult(
        isValid: true,
        expiredEssential: [],
        expiredOptional: [],
        totalCookies: 3,
      );

      expect(result.isValid, isTrue);
      expect(result.expiredEssential, isEmpty);
      expect(result.expiredOptional, isEmpty);
      expect(result.totalCookies, equals(3));
    });

    test('should create invalid result', () {
      final result = CookieValidationResult(
        isValid: false,
        expiredEssential: ['a', 'b'],
        expiredOptional: ['sz'],
        totalCookies: 3,
      );

      expect(result.isValid, isFalse);
      expect(result.expiredEssential, contains('a'));
      expect(result.expiredEssential, contains('b'));
      expect(result.expiredOptional, contains('sz'));
    });

    test('should have toString', () {
      final result = CookieValidationResult(
        isValid: true,
        expiredEssential: [],
        expiredOptional: [],
        totalCookies: 3,
      );

      expect(result.toString(), contains('isValid=true'));
    });
  });
}
