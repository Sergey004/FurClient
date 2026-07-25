import 'package:fa_kit/fa_kit.dart';
import 'package:fa_kit/src/models/fa_comment.dart'
    show OrphanedCommentException;
import 'package:test/test.dart';

FAVisiblePageComment _visible(int cid, int indentation) {
  return FAVisiblePageComment(
    cid: cid,
    indentation: indentation,
    author: 't',
    displayAuthor: 'T',
    datetime: DateTime(2022, 8, 12, 4, 8),
    naturalDatetime: 'Today',
    htmlMessage: 'Msg',
  );
}

void main() {
  group('buildCommentsTree', () {
    test('empty list gives empty tree', () {
      expect(buildCommentsTree([]), isEmpty);
    });

    test('only roots gives flat list', () async {
      final pages = [
        _visible(166652793, 0),
        _visible(166653891, 0),
        _visible(166658565, 0),
      ];
      final tree = buildCommentsTree(pages);

      expect(tree.length, 3);
      expect(
          tree.map((c) => c.cid).toList(), [166652793, 166653891, 166658565]);
      for (final root in tree) {
        expect(root.answers, isEmpty);
      }
    });

    test('simple hierarchy (0→3→6)', () {
      final pages = [
        _visible(166652793, 0),
        _visible(166653891, 3),
        _visible(166658565, 6),
      ];
      final tree = buildCommentsTree(pages);

      expect(tree.length, 1);
      expect(tree.first.cid, 166652793);

      final r1 = tree.first.answers;
      expect(r1.length, 1);
      expect(r1.first.cid, 166653891);
      expect(r1.first.answers.length, 1);
      expect(r1.first.answers.first.cid, 166658565);
    });

    test('complex hierarchy (FACommentTests.swift:61)', () {
      final pages = [
        _visible(166652793, 0),
        _visible(166653891, 3),
        _visible(166658565, 6),
        _visible(166663244, 3),
        _visible(166652794, 3),
        _visible(166658865, 6),
        _visible(166656182, 0),
      ];
      final tree = buildCommentsTree(pages);

      expect(tree.length, 2); // two roots

      // First root
      final r0 = tree.firstWhere((c) => c.cid == 166652793);
      expect(r0.answers.length, 3);

      // cid 166653891 → one child cid 166658565
      final a0 = r0.answers[0];
      expect(a0.cid, 166653891);
      expect(a0.answers.length, 1);
      expect(a0.answers.first.cid, 166658565);

      // cid 166663244 → leaf (no children)
      final a1 = r0.answers[1];
      expect(a1.cid, 166663244);
      expect(a1.answers, isEmpty);

      // cid 166652794 → one child cid 166658865
      final a2 = r0.answers[2];
      expect(a2.cid, 166652794);
      expect(a2.answers.length, 1);
      expect(a2.answers.first.cid, 166658865);

      // Second root
      final r1 = tree.firstWhere((c) => c.cid == 166656182);
      expect(r1.answers, isEmpty);
    });

    test('orphaned comment throws', () {
      final pages = [
        _visible(166653891, 3),
        _visible(166652793, 0),
      ];
      expect(
        () => buildCommentsTree(pages),
        throwsA(isA<OrphanedCommentException>().having(
          (e) => e.cid,
          'cid',
          166653891,
        )),
      );
    });

    test('recursiveCount', () {
      final pages = [
        _visible(166652793, 0),
        _visible(166653891, 3),
        _visible(166658565, 6),
        _visible(166663244, 3),
        _visible(166652794, 3),
        _visible(166658865, 6),
        _visible(166656182, 0),
      ];
      final tree = buildCommentsTree(pages);
      final total = tree.fold<int>(0, (sum, c) => sum + c.recursiveCount);
      expect(total, 7);
    });

    test('recursivePath', () async {
      final pages = [
        _visible(166652793, 0),
        _visible(166653891, 3),
        _visible(166658565, 6),
        _visible(166663244, 3),
        _visible(166652794, 3),
        _visible(166658865, 6),
        _visible(166656182, 0),
      ];
      final tree = buildCommentsTree(pages);

      // Leaf: full chain from top-level ancestor
      expect(tree.recursivePathTo(166658565)?.map((c) => c.cid).toList(),
          [166652793, 166653891, 166658565]);

      // Mid-level node
      expect(tree.recursivePathTo(166652794)?.map((c) => c.cid).toList(),
          [166652793, 166652794]);

      // Top-level root: just itself
      expect(tree.recursivePathTo(166656182)?.map((c) => c.cid).toList(),
          [166656182]);

      // Missing cid
      expect(tree.recursivePathTo(999), isNull);
    });
  });
}

extension TreePath on List<FAComment> {
  List<FAComment>? recursivePathTo(int targetCid) {
    for (final c in this) {
      final path = c.recursivePathTo(targetCid);
      if (path != null) return path;
    }
    return null;
  }
}
