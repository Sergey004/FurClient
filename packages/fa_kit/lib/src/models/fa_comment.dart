import '../pages/fa_page.dart';

/// Error raised when [buildCommentsTree] encounters a comment whose
/// indentation implies a parent that does not exist in the flat list.
///
/// Mirrors `FACommentError.orphanedComment(cid:)` in
/// FAComment.swift:13-15.
class OrphanedCommentException implements Exception {
  final int cid;
  OrphanedCommentException(this.cid);

  @override
  String toString() => 'OrphanedCommentException: cid=$cid';
}

/// A comment in the FA system (tree-structured).
///
/// Mirrors the `FAComment` sealed enum in FAComment.swift:17-22.
sealed class FAComment {
  /// Unique comment ID.
  int get cid;

  /// Indentation level (0 = root, 3 = reply, 6 = reply-to-reply, …).
  int get indentation;

  /// The comment's HTML message.
  String get htmlMessage;

  /// Child replies.
  List<FAComment> get answers;

  /// Recursively find the first comment matching a predicate.
  ///
  /// Mirrors `recursiveFirst(where:)` in FAComment.swift:190-200.
  FAComment? recursiveFirstWhere(bool Function(FAComment) test) {
    if (test(this)) return this;
    for (final answer in answers) {
      final found = answer.recursiveFirstWhere(test);
      if (found != null) return found;
    }
    return null;
  }

  /// Recursively iterate over all comments in the tree.
  ///
  /// Mirrors `recursiveForEach(_:)` in FAComment.swift:202-207.
  void recursiveForEach(void Function(FAComment) action) {
    action(this);
    for (final answer in answers) {
      answer.recursiveForEach(action);
    }
  }

  /// Count all comments in the tree (including children).
  ///
  /// Mirrors `recursiveCount` in FAComment.swift:209-215.
  int get recursiveCount {
    var count = 1;
    for (final answer in answers) {
      count += answer.recursiveCount;
    }
    return count;
  }

  /// Path from this top-level comment down to and including the comment
  /// with `cid`. Returns `null` if absent.
  ///
  /// Mirrors `recursivePath(toCid:)` in FAComment.swift:219-225.
  List<FAComment>? recursivePathTo(int targetCid) {
    if (cid == targetCid) return [this];
    for (final answer in answers) {
      final tail = answer.recursivePathTo(targetCid);
      if (tail != null) return [this, ...tail];
    }
    return null;
  }
}

/// A visible comment with author information.
///
/// Mirrors `FAVisibleComment` in FAComment.swift:22-41.
class FAVisibleComment extends FAComment {
  @override
  final int cid;
  @override
  final int indentation;
  final String author;
  final String displayAuthor;
  final DateTime? datetime;
  final String naturalDatetime;
  @override
  final String htmlMessage;
  @override
  final List<FAComment> answers;

  FAVisibleComment({
    required this.cid,
    required this.indentation,
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
      indentation: indentation,
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
///
/// Mirrors `FAHiddenComment` in FAComment.swift:43-53.
class FAHiddenComment extends FAComment {
  @override
  final int cid;
  @override
  final int indentation;
  @override
  final String htmlMessage;
  @override
  final List<FAComment> answers;

  FAHiddenComment({
    required this.cid,
    required this.indentation,
    required this.htmlMessage,
    this.answers = const [],
  });

  FAHiddenComment copyWith({List<FAComment>? answers}) {
    return FAHiddenComment(
      cid: cid,
      indentation: indentation,
      htmlMessage: htmlMessage,
      answers: answers ?? this.answers,
    );
  }
}

/// Build a comment tree from a flat list of parsed page comments.
///
/// Uses indentation-based parent detection to construct the tree structure.
///
/// Mirrors `FAComment.buildCommentsTree(_:)` in FAComment.swift:155-186.
///
/// Throws [OrphanedCommentException] if a non-root comment has no preceding
/// comment with a lower indentation level (i.e. its parent is missing).
List<FAComment> buildCommentsTree(List<FAPageComment> flatComments) {
  if (flatComments.isEmpty) return [];

  // Map cid → built FAComment.
  final index = <int, FAComment>{};
  // Map parent cid → ordered list of child comments.
  final children = <int, List<FAComment>>{};
  // Roots (indentation == 0).
  final roots = <FAComment>[];

  // Tracks the last cid seen at each indentation. Maintained in insertion
  // order — checked from highest indentation to lowest when looking for a
  // parent (hence `.reversed` below).
  final lastCidAtIndentation = <int, int>{};

  for (final pageComment in flatComments) {
    final FAComment comment;
    if (pageComment is FAVisiblePageComment) {
      comment = FAVisibleComment(
        cid: pageComment.cid,
        indentation: pageComment.indentation,
        author: pageComment.author,
        displayAuthor: pageComment.displayAuthor,
        datetime: pageComment.datetime,
        naturalDatetime: pageComment.naturalDatetime,
        htmlMessage: pageComment.htmlMessage,
      );
    } else if (pageComment is FAHiddenPageComment) {
      comment = FAHiddenComment(
        cid: pageComment.cid,
        indentation: pageComment.indentation,
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
    } else {
      // Find parent — most recent entry with a strictly lower indentation.
      // `.entries.toList()..sort` gives descending keys (deepest first),
      // then we take the first with key < indentation.
      int? parentCid;
      final descending = lastCidAtIndentation.entries.toList()
        ..sort((a, b) => b.key.compareTo(a.key));
      for (final entry in descending) {
        if (entry.key < indentation) {
          parentCid = entry.value;
          break;
        }
      }

      if (parentCid == null || !index.containsKey(parentCid)) {
        // No parent found — this is an orphan; mirror Swift's error behavior.
        throw OrphanedCommentException(comment.cid);
      }
      children[parentCid]!.add(comment);
    }

    // Record current cid at its indentation, then drop any entries at
    // deeper indentations (we've left that branch).
    lastCidAtIndentation[indentation] = comment.cid;
    lastCidAtIndentation
        .removeWhere((key, _) => key > indentation);
  }

  // Attach children to parents (rebuild each parent with its answers).
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

  // Return roots with their updated children.
  return roots.map((root) => index[root.cid] ?? root).toList();
}
