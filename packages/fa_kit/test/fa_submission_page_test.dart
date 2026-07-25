import 'dart:io';
import 'package:fa_kit/fa_kit.dart';
import 'package:test/test.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('FASubmissionPage', () {
    test('parses submission without comments', () {
      final html = fixture('www.furaffinity.net-view-49338772-nocomment.html');
      final url = Uri.parse('https://www.furaffinity.net/view/49338772/');
      final page = FASubmissionPage.parse(html, url);

      // Preview image
      expect(page.previewImageUrl.toString(),
          'https://t.furaffinity.net/49338772@600-1665402309.jpg');
      expect(
          page.fullResolutionMediaUrl!.toString(),
          startsWith(
              'https://d.furaffinity.net/art/annetpeas/1665402309/1665402309.annetpeas_the_hookah_fa'));

      // Metadata
      final m = page.metadata;
      expect(m.title, 'The hookah');
      expect(m.author, 'annetpeas');
      expect(m.displayAuthor, 'AnnetPeas');
      expect(m.datetime, DateTime(2022, 10, 10, 13, 45, 9));
      expect(m.naturalDatetime, '3 years ago');
      expect(m.viewCount, 810);
      expect(m.commentCount, 0);
      expect(m.favoriteCount, 65);
      expect(m.rating, Rating.general);
      expect(m.category, 'Artwork (Digital)');
      expect(m.theme, 'All');
      expect(m.species, 'Rabbit / Hare');
      expect(m.fileSize, '1.22 MB');
      expect(m.resolution, '1217 x 1280');
      expect(m.keywords.length, 15);
      expect(m.folders.length, 1);
      expect(m.folders.first.title, 'My arts - 2022');

      // Description
      expect(page.htmlDescription, contains('YCH'));

      // Favorite
      expect(page.isFavorite, false);
      expect(page.favoriteUrl.toString(), contains('/fav/49338772/'));

      // Comments
      expect(page.comments, isEmpty);
      expect(page.acceptsNewComments, true);
    });

    test('parses submission with comments', () {
      final html = fixture('www.furaffinity.net-view-48519387-comments.html');
      final url =
          Uri.parse('https://www.furaffinity.net/view/48519387/#cid:166652794');
      final page = FASubmissionPage.parse(html, url);

      expect(page.comments.length, 10);

      // Comment 0: root
      final c0 = page.comments[0] as FAVisiblePageComment;
      expect(c0.cid, 166652793);
      expect(c0.indentation, 0);
      expect(c0.author, 'terriniss');
      expect(c0.displayAuthor, 'Terriniss');
      expect(c0.datetime, DateTime(2022, 8, 12, 2, 48, 38));
      expect(c0.naturalDatetime, '4 years ago');
      expect(c0.htmlMessage, contains('BID HERE'));
      expect(c0.htmlMessage, contains('<br>'));

      // Comment 1: reply (width=97% → indent=3)
      final c1 = page.comments[1] as FAVisiblePageComment;
      expect(c1.cid, 166653891);
      expect(c1.indentation, 3);

      // Comment 3: deepest (width=91% → indent=9)
      final c3 = page.comments[3] as FAVisiblePageComment;
      expect(c3.cid, 166663244);
      expect(c3.indentation, 9);

      // Comment 4: another root (tree split)
      final c4 = page.comments[4] as FAVisiblePageComment;
      expect(c4.cid, 166652794);
      expect(c4.indentation, 0);

      // A non-terriniss author
      final c8 = page.comments[8] as FAVisiblePageComment;
      expect(c8.author, 'fallen5592');

      // Target comment from URL
      expect(page.targetCommentId, 166652794);
    });

    test('parses submission with hidden comment', () {
      final html =
          fixture('www.furaffinity.net-view-49917619-comment-hidden.html');
      final url = Uri.parse('https://www.furaffinity.net/view/49917619/');
      final page = FASubmissionPage.parse(html, url);

      expect(page.comments.length, 12);

      // 6th comment is hidden
      for (var i = 0; i < page.comments.length; i++) {
        if (i == 6) {
          expect(page.comments[i], isA<FAHiddenPageComment>());
          final h = page.comments[i] as FAHiddenPageComment;
          expect(h.cid, 168829732);
          expect(h.indentation, 6);
          expect(h.htmlMessage, 'Comment hidden by its owner');
        } else {
          expect(page.comments[i], isA<FAVisiblePageComment>());
        }
      }
    });

    test('parses submission with disabled comments', () {
      final html =
          fixture('www.furaffinity.net-view-52209828-disabled-comments.html');
      final url = Uri.parse('https://www.furaffinity.net/view/52209828/');
      final page = FASubmissionPage.parse(html, url);

      expect(page.acceptsNewComments, false);
    });
  });

  group('buildCommentsTree from submission fixture', () {
    test('complex hierarchy builds correctly', () {
      final html = fixture('www.furaffinity.net-view-48519387-comments.html');
      final url = Uri.parse('https://www.furaffinity.net/view/48519387/');
      final page = FASubmissionPage.parse(html, url);

      final tree = buildCommentsTree(page.comments);
      expect(tree.length, 5); // 5 roots (indentation 0)

      // Root 166652793 has 3 children (indent 3) with one grandchild (indent 6)
      final rootC0 = tree.firstWhere((c) => c.cid == 166652793);
      expect(rootC0.answers.length, 3);

      // First child (cid 166653891) has one answer (cid 166658565)
      final child0 = rootC0.answers[0];
      expect(child0.cid, 166653891);
      expect(child0.answers.length, 1);
      expect(child0.answers.first.cid, 166658565);

      // Third child (cid 166652794) has one answer (cid 166658865)
      final child2 = rootC0.answers[2];
      expect(child2.cid, 166652794);
      expect(child2.answers.length, 1);
      expect(child2.answers.first.cid, 166658577);

      // Total recursive count
      final total = tree.fold<int>(0, (sum, c) => sum + c.recursiveCount);
      expect(total, 10);
    });
  });
}
