import 'package:test/test.dart';
// Direct import to bypass fa_kit barrel (diagnostic)
import 'package:fa_kit/src/utils/fa_date_parser.dart';

void main() {
  group('parseFADatetime raw', () {
    test('parses with seconds', () {
      final result = parseFADatetime('October 10, 2022 01:45:09 PM');
      print('result: $result');
      expect(result, DateTime(2022, 10, 10, 13, 45, 9));
    });
  });
}
