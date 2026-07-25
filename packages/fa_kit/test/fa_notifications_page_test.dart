import 'dart:io';
import 'package:fa_kit/fa_kit.dart';
import 'package:test/test.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('FANotificationsPage', () {
    test('parses all notification categories from full fixture', () {
      final html = fixture(
          'www.furaffinity.net-msg-others-comments-journals-shout.html');
      final page = FANotificationsPage.parse(
          html, Uri.parse('https://www.furaffinity.net/msg/others/'));

      // Submission comment
      expect(page.submissionCommentHeaders.length, 1);
      final sc = page.submissionCommentHeaders.first;
      expect(sc.id, 183695893);
      expect(sc.author, 'someuser');
      expect(sc.displayAuthor, 'SomeUser');
      expect(sc.title, 'FurAffinity iOS App 1.3 Update');
      expect(sc.datetime, DateTime(2025, 1, 17, 22, 11));
      expect(sc.naturalDatetime, 'a month ago');
      expect(sc.url.toString(),
          'https://www.furaffinity.net/view/49215481/#cid:183695893');

      // Journal comment
      expect(page.journalCommentHeaders.length, 1);
      final jc = page.journalCommentHeaders.first;
      expect(jc.id, 60980385);
      expect(jc.author, 'someuser');
      expect(jc.title, 'Test');
      expect(jc.datetime, DateTime(2025, 3, 4, 23, 23));
      expect(jc.naturalDatetime, 'a minute ago');

      // Shout
      expect(page.shoutHeaders.length, 1);
      final sh = page.shoutHeaders.first;
      expect(sh.id, 56046409);
      expect(sh.author, 'someuser');
      expect(sh.displayAuthor, 'SomeUser');
      expect(sh.title, '');
      // "on Dec 23, 2024 05:56 PM" → prefix stripped
      expect(sh.datetime, DateTime(2024, 12, 23, 17, 56));
      expect(sh.naturalDatetime, '2 months ago');
      // URL points to current user shoutbox
      expect(sh.url.toString(), contains('/user/furrycount#shout-56046409'));

      // Journals
      expect(page.journalHeaders.length, 21);

      // First journal
      final j0 = page.journalHeaders[0];
      expect(j0.id, 11084927);
      expect(j0.author, 'leilryu');
      expect(j0.title, 'Commissions are open!');
      expect(j0.datetime, DateTime(2025, 3, 3, 22, 41));
      expect(j0.naturalDatetime, 'a day ago');

      // Second journal
      final j1 = page.journalHeaders[1];
      expect(j1.id, 11064320);
      expect(j1.title, '[closed]');
      expect(j1.datetime, DateTime(2025, 2, 3, 21, 51));

      // Third journal
      final j2 = page.journalHeaders[2];
      expect(j2.id, 11049380);
      expect(j2.author, 'ishiru');
      expect(j2.displayAuthor, 'Ishiru');
      expect(j2.title, 'YCH ends this evening');
      expect(j2.datetime, DateTime(2025, 1, 14, 19, 36));
    });

    test('empty fixture returns all empty lists', () {
      final html = fixture('www.furaffinity.net-msg-others-empty.html');
      final page = FANotificationsPage.parse(
          html, Uri.parse('https://www.furaffinity.net/msg/others/'));

      expect(page.submissionCommentHeaders, isEmpty);
      expect(page.journalCommentHeaders, isEmpty);
      expect(page.shoutHeaders, isEmpty);
      expect(page.journalHeaders, isEmpty);
    });
  });
}
