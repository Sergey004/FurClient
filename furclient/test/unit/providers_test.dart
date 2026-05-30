import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/providers/auth_provider.dart';
import 'package:furclient/providers/session_provider.dart';
import 'package:furclient/utils/cookie_manager.dart';

void main() {
  group('AuthProvider', () {
    late AuthProvider authProvider;

    setUp(() {
      authProvider = AuthProvider();
    });

    tearDown(() {
      authProvider.dispose();
    });

    test('should initialize with default state', () {
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.currentSession, isNull);
      expect(authProvider.error, isNull);
    });

    test('should initialize from storage', () async {
      await authProvider.initialize();
      expect(authProvider.isLoading, isFalse);
    });

    test('should clear error', () {
      authProvider.clearError();
      expect(authProvider.error, isNull);
    });
  });

  group('SessionProvider', () {
    late SessionProvider sessionProvider;

    setUp(() {
      sessionProvider = SessionProvider();
    });

    tearDown(() {
      sessionProvider.dispose();
    });

    test('should initialize with default state', () {
      expect(sessionProvider.isInitialized, isFalse);
      expect(sessionProvider.isLoading, isFalse);
      expect(sessionProvider.webViewController, isNull);
      expect(sessionProvider.error, isNull);
    });

    test('should initialize CDNLoader', () async {
      await sessionProvider.initialize();
      expect(sessionProvider.isInitialized, isTrue);
    });

    test('should get cache statistics', () {
      final stats = sessionProvider.getCacheStats();
      expect(stats, contains('total'));
      expect(stats, contains('maxSize'));
    });

    test('should clear cache', () {
      sessionProvider.clearCache();
      expect(sessionProvider.cdnLoader.cacheSize, equals(0));
    });

    test('should validate cookies', () {
      final result = sessionProvider.validateCookies();
      expect(result.isValid, isA<bool>());
      expect(result.totalCookies, isA<int>());
    });

    test('should clear error', () {
      sessionProvider.clearError();
      expect(sessionProvider.error, isNull);
    });
  });
}
