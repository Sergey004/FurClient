import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/services/cdn_loader.dart';

void main() {
  group('CDNLoader', () {
    late CDNLoader cdnLoader;

    setUp(() {
      cdnLoader = CDNLoader.instance;
    });

    tearDown(() {
      cdnLoader.clearCache();
    });

    test('should be singleton', () {
      final instance1 = CDNLoader.instance;
      final instance2 = CDNLoader.instance;
      expect(instance1, same(instance2));
    });

    test('should initialize', () async {
      await cdnLoader.initialize();
      expect(cdnLoader.cacheSize, equals(0));
    });

    test('should detect CDN URLs', () {
      expect(CDNLoader.isCDNUrl('https://t.furaffinity.net/image.jpg'), isTrue);
      expect(CDNLoader.isCDNUrl('https://d.furaffinity.net/file.zip'), isTrue);
      expect(CDNLoader.isCDNUrl('https://a.furaffinity.net/attachment.pdf'), isTrue);
      expect(CDNLoader.isCDNUrl('https://example.com/image.jpg'), isFalse);
    });

    test('should manage cache', () {
      cdnLoader.clearCache();
      expect(cdnLoader.cacheSize, equals(0));
      expect(cdnLoader.maxCacheSize, equals(50));
    });

    test('should return cache statistics', () {
      final stats = cdnLoader.getCacheStats();
      expect(stats, contains('total'));
      expect(stats, contains('valid'));
      expect(stats, contains('expired'));
      expect(stats, contains('maxSize'));
      expect(stats, contains('timeoutMinutes'));
    });

    test('should clean expired cache', () {
      cdnLoader.cleanExpiredCache();
      // Should not throw
    });

    test('should dispose resources', () {
      cdnLoader.dispose();
      // Should not throw
    });
  });

  group('CDNUrlExtension', () {
    test('should check if URL is CDN', () {
      expect('https://t.furaffinity.net/image.jpg'.isCDNUrl, isTrue);
      expect('https://example.com/image.jpg'.isCDNUrl, isFalse);
    });

    test('should convert to full CDN URL', () {
      expect('image.jpg'.toFullCDNUrl(), equals('https://t.furaffinity.net/image.jpg'));
      expect('https://example.com/image.jpg'.toFullCDNUrl(), equals('https://example.com/image.jpg'));
    });
  });
}
