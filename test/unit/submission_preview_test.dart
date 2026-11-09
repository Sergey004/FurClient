import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/models/submission_preview.dart';

void main() {
  group('SubmissionPreview', () {
    const preview = SubmissionPreview(
      id: '66491081',
      title: 'what u lookin at',
      author: 'carlarzall',
      displayName: 'carlarzall',
      thumbnailUrl: 'https://t.furaffinity.net/66491081@300-1.jpg',
      url: 'https://www.furaffinity.net/view/66491081/',
      rating: 'general',
    );

    test('encodes to a JSON string and decodes back', () {
      final encoded = preview.encode();
      expect(encoded, isNotNull);

      final decoded = SubmissionPreview.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.id, preview.id);
      expect(decoded.title, preview.title);
      expect(decoded.author, preview.author);
      expect(decoded.thumbnailUrl, preview.thumbnailUrl);
      expect(decoded.url, preview.url);
      expect(decoded.rating, preview.rating);
    });

    test('decode tolerates broken payloads without throwing', () {
      expect(SubmissionPreview.decode(null), isNull);
      expect(SubmissionPreview.decode(''), isNull);
      expect(SubmissionPreview.decode('{not json'), isNull);
      expect(SubmissionPreview.decode('[]'), isNull);
      expect(SubmissionPreview.decode('{"id":1}')?.id, '1');
    });

    test('notification payload envelope carries url and preview', () {
      final encoded = preview.encode()!;
      final payload = jsonEncode({'url': preview.url, 'preview': encoded});

      final map = jsonDecode(payload) as Map;
      expect(map['url'], preview.url);
      expect(
          SubmissionPreview.decode(map['preview'] as String)?.title, preview.title);
    });
  });
}
