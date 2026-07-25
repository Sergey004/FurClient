import 'dart:io';
import 'package:fa_kit/fa_kit.dart';
import 'package:test/test.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('FAJournalPage', () {
    test('parses journal with comments', () {
      final html =
          fixture('www.furaffinity.net-journal-10516170-withcomments.html');
      final url = Uri.parse('https://www.furaffinity.net/journal/10516170/');
      final page = FAJournalPage.parse(html, url);

      expect(page.author, 'rudragon');
      expect(page.displayAuthor, 'RUdragon');
      expect(page.title, 'UPGRADES ARE OPEN!!! 5');
      expect(page.datetime, DateTime(2023, 4, 3, 6, 59, 20));
      expect(page.naturalDatetime, '3 years ago');
      expect(page.htmlDescription, contains('what you will need to get one'));
      expect(page.htmlDescription, contains('<br>'));
      expect(page.acceptsNewComments, true);

      // Comments
      expect(page.comments.length, 7);

      // Comment 5 (xaraphiel) with nested reply (flamekillaxxx)
      final c5 = page.comments[5] as FAVisiblePageComment;
      expect(c5.cid, 59820673);
      expect(c5.author, 'xaraphiel');
      expect(c5.indentation, 0);
      expect(c5.htmlMessage, contains('time zones'));

      final c6 = page.comments[6] as FAVisiblePageComment;
      expect(c6.cid, 59820831);
      expect(c6.author, 'flamekillaxxx');
      expect(c6.displayAuthor, 'flamekillaXxX');
      expect(c6.indentation, 3);
      expect(c6.htmlMessage, contains('Best of luck'));
    });

    test('parses journal with disabled comments', () {
      final html = fixture(
          'www.furaffinity.net-journal-10882268-disabled-comments.html');
      final url = Uri.parse('https://www.furaffinity.net/journal/10882268/');
      final page = FAJournalPage.parse(html, url);

      expect(page.acceptsNewComments, false);
    });
  });
}
