import 'package:fa_kit/fa_kit.dart';
import 'package:test/test.dart';

void main() {
  group('parseFADatetime', () {
    test('parses with seconds (submission/comment format)', () {
      final result = parseFADatetime('October 10, 2022 01:45:09 PM');
      expect(result, DateTime(2022, 10, 10, 13, 45, 9));
    });

    test('parses without seconds (notification format)', () {
      final result = parseFADatetime('Jan 17, 2025 10:11 PM');
      expect(result, DateTime(2025, 1, 17, 22, 11));
    });

    test('strips "on " prefix (shout notification format)', () {
      final result = parseFADatetime('on Dec 23, 2024 05:56 PM');
      expect(result, DateTime(2024, 12, 23, 17, 56));
    });

    test('AM/PM boundary cases', () {
      expect(parseFADatetime('Aug 12, 2022 12:00 AM'), DateTime(2022, 8, 12, 0, 0));
      expect(parseFADatetime('Aug 12, 2022 12:00 PM'), DateTime(2022, 8, 12, 12, 0));
      expect(parseFADatetime('Aug 12, 2022 01:05 AM'), DateTime(2022, 8, 12, 1, 5));
      expect(parseFADatetime('Aug 12, 2022 01:05 PM'), DateTime(2022, 8, 12, 13, 5));
      expect(parseFADatetime('Aug 12, 2022 11:59 PM'), DateTime(2022, 8, 12, 23, 59));
      expect(parseFADatetime('Aug 12, 2022 12:05 PM'), DateTime(2022, 8, 12, 12, 5));
    });

    test('returns null on empty/null/invalid input', () {
      expect(parseFADatetime(null), isNull);
      expect(parseFADatetime(''), isNull);
      expect(parseFADatetime(' '), isNull);
      expect(parseFADatetime('invalid'), isNull);
      expect(parseFADatetime('not a date string'), isNull);
    });
  });
}