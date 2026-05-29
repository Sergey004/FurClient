import '../pages/fa_page.dart';

/// A comment in the FA system (tree-structured).
sealed class FAComment {
  /// Unique comment ID.
  int get cid;

  /// The comment's HTML message.
  String get htmlMessage;

  /// Child replies.
  List<FAComment> get answers;

  /// Recursively find the first comment matching a predicate.
  FAComment? recursiveFirstWhere(bool Function(FAComment) test) {
    if (test(this)) return this;
    for (final answer in answers) {
      final found = answer.recursiveFirstWhere(test);
      if (found != null) return found;
    }
    return null;
  }

  /// Recursively iterate over all comments in the tree.
  void recursiveForEach(void Function(FAComment) action) {
    action(this);
    for (final answer in answers) {
      answer.recursiveForEach(action);
    }
  }

  /// Count all comments in the tree (including children).
  int get recursiveCount {
    int count = 1;
    for (final answer in answers) {
      count += answer.recursiveCount;
    }
    return count;
  }
}

/// A visible comment with author information.
class FAVisibleComment extends FAComment {
  @override
  final int cid;
  final String author;
  final String displayAuthor;
  final DateTime datetime;
  final String naturalDatetime;
  @override
  final String htmlMessage;
  @override
  final List<FAComment> answers;

  FAVisibleComment({
    required this.cid,
    required this.author,
    required this.displayAuthor,
    required this.datetime,
    required this.naturalDatetime,
    required this.htmlMessage,
    this.answers = const [],
  });

  /// Create a copy with updated answers.
  FAVisibleComment copyWith({List<FAComment>? answers}) {
    return FAVisibleComment(
      cid: cid,
      author: author,
      displayAuthor: displayAuthor,
      datetime: datetime,
      naturalDatetime: naturalDatetime,
      htmlMessage: htmlMessage,
      answers: answers ?? this.answers,
    );
  }
}

/// A hidden/filtered comment without author info.
class FAHiddenComment extends FAComment {
  @override
  final int cid;
  @override
  final String htmlMessage;
  @override
  final List<FAComment> answers;

  FAHiddenComment({
    required this.cid,
    required this.htmlMessage,
    this.answers = const [],
  });

  FAHiddenComment copyWith({List<FAComment>? answers}) {
    return FAHiddenComment(
      cid: cid,
      htmlMessage: htmlMessage,
      answers: answers ?? this.answers,
    );
  }
}

/// Build a comment tree from a flat list of parsed page comments.
///
/// Uses indentation-based parent detection to construct the tree structure.
List<FAComment> buildCommentsTree(List<FAPageComment> flatComments) {
  if (flatComments.isEmpty) return [];

  // Build index: cid -> comment
  final index = <int, FAComment>{};
  final children = <int, List<FAComment>>{};
  final roots = <FAComment>[];

  // Track last cid at each indentation level
  final lastCidAtIndentation = <int, int>{};

  for (final pageComment in flatComments) {
    final FAComment comment;
    if (pageComment is FAVisiblePageComment) {
      comment = FAVisibleComment(
        cid: pageComment.cid,
        author: pageComment.author,
        displayAuthor: pageComment.displayAuthor,
        datetime: pageComment.datetime,
        naturalDatetime: pageComment.naturalDatetime,
        htmlMessage: pageComment.htmlMessage,
      );
    } else if (pageComment is FAHiddenPageComment) {
      comment = FAHiddenComment(
        cid: pageComment.cid,
        htmlMessage: pageComment.htmlMessage,
      );
    } else {
      continue;
    }

    index[comment.cid] = comment;
    children[comment.cid] = [];

    final indentation = pageComment.indentation;

    if (indentation == 0) {
      roots.add(comment);
      lastCidAtIndentation[0] = comment.cid;
      // Clear higher indentations
      lastCidAtIndentation.removeWhere((key, _) => key > 0);
    } else {
      // Find parent: most recent entry with lower indentation
      int? parentCid;
      for (final entry in lastCidAtIndentation.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key))) {
        if (entry.key < indentation) {
          parentCid = entry.value;
          break;
        }
      }

      if (parentCid != null && index.containsKey(parentCid)) {
        children[parentCid]!.add(comment);
      } else {
        // No parent found, treat as root
        roots.add(comment);
      }

      lastCidAtIndentation[indentation] = comment.cid;
      // Clear higher indentations
      lastCidAtIndentation.removeWhere((key, _) => key > indentation);
    }
  }

  // Attach children to parents
  for (final entry in children.entries) {
    final parent = index[entry.key];
    if (parent != null) {
      final updatedChildren = entry.value;
      if (parent is FAVisibleComment) {
        index[entry.key] = parent.copyWith(answers: updatedChildren);
      } else if (parent is FAHiddenComment) {
        index[entry.key] = parent.copyWith(answers: updatedChildren);
      }
    }
  }

  // Return roots with their updated children
  return roots.map((root) => index[root.cid] ?? root).toList();
}
