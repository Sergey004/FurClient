import 'package:html/dom.dart' as dom;
import '../utils/fa_date_parser.dart';

/// Abstract interface for all parseable FurAffinity pages.
///
/// Each page type (submissions, journals, notes, etc.) implements this interface.
/// The [parse] factory takes raw HTML data + the requesting URL and returns
/// a typed page struct.
abstract class FAPage {
  /// Parse raw HTML data into a typed page struct.
  ///
  /// [html] is the raw HTML string from the HTTP response.
  /// [url] is the URL that was requested.
  static FAPage? detectAndParse(String html, Uri url) {
    // Check for system error page
    if (html.contains('System Error') &&
        html.contains('<h2>System Error</h2>')) {
      return FASystemErrorPage.parse(html);
    }
    // Check for system message page
    if (html.contains('System Message') &&
        html.contains('<h2>System Message</h2>')) {
      return FASystemMessagePage.parse(html);
    }
    return null;
  }
}

/// Comment type — determines how the comment ID is parsed.
///
/// Mirrors `CommentType` in FAPageComment.swift. Regular comments use
/// `cid:(\d+)` from the `<a id="cid:N">` anchor. Shouts use `shout-(\d+)`
/// from the `<a id="shout-N">` anchor.
enum CommentType { comment, shout }

/// Parse a single `.comment_container` element into an [FAPageComment].
///
/// Mirrors the Swift `FAPageComment.init(_:type:)` logic in
/// FAPageComment.swift:94-129.
///
/// - For [CommentType.comment]: cid extracted from `<a id="cid:N">`.
/// - For [CommentType.shout]: cid extracted from `<a id="shout-N">`.
///
/// Indentation is derived from the `style="width:N%"` attribute on the
/// container: `indentation = 100 - N`. A 100% width root comment yields
/// indentation 0.
///
/// If the author node is missing the comment is treated as hidden and an
/// [FAHiddenPageComment] is returned (e.g. "Comment hidden by its owner").
FAPageComment parsePageComment(dom.Element node, CommentType type) {
  // CID: <a id="cid:N"> or <a id="shout-N">
  final cidAnchor = type == CommentType.comment
      ? node.querySelector('a[id^="cid:"]')
      : node.querySelector('a[id^="shout-"]');
  int cid = 0;
  if (cidAnchor != null) {
    final rawId = cidAnchor.attributes['id'] ?? '';
    final pattern = type == CommentType.comment ? r'cid:(\d+)' : r'shout-(\d+)';
    final match = RegExp(pattern).firstMatch(rawId);
    cid = int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  // Indentation: style="width:N%" → 100 - N
  int indentation = 0;
  final style = node.attributes['style'] ?? '';
  final widthMatch = RegExp(r'width:(\d+)%').firstMatch(style);
  if (widthMatch != null) {
    final width = int.tryParse(widthMatch.group(1) ?? '') ?? 100;
    indentation = 100 - width;
  }

  // htmlMessage: primary selector with fallback (as in FAPageComment.swift)
  final primaryMsg = node.querySelector(
      'comment-container div.comment-content comment-user-text div.user-submitted-links');
  final fallbackMsg = node
      .querySelector('comment-container div.comment-content comment-user-text');
  final htmlMessage = (primaryMsg ?? fallbackMsg)?.innerHtml.trim() ?? '';

  // Author / displayAuthor / datetime
  final authorNode = node.querySelector(
      'comment-container comment-username div.c-usernameBlock a.c-usernameBlock__displayName');

  if (authorNode == null) {
    return FAHiddenPageComment(
      cid: cid,
      indentation: indentation,
      htmlMessage: htmlMessage,
    );
  }

  final href = authorNode.attributes['href'] ?? '';
  final authorMatch = RegExp(r'/user/(.+)/').firstMatch(href);
  final author = authorMatch?.group(1) ?? '';
  final displayAuthor = authorNode.text.trim();

  final dateNode = node.querySelector(
      'comment-container div.comment-content comment-date span.popup_date');
  final dateResult = parseFADateNode(dateNode);

  return FAVisiblePageComment(
    cid: cid,
    indentation: indentation,
    author: author,
    displayAuthor: displayAuthor,
    datetime: dateResult.datetime,
    naturalDatetime: dateResult.naturalDatetime,
    htmlMessage: htmlMessage,
  );
}

/// A parsed comment from a FA page (flat list, not yet a tree).
sealed class FAPageComment {
  int get cid;
  int get indentation;
  String get htmlMessage;
}

/// A visible comment with author info.
class FAVisiblePageComment extends FAPageComment {
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

  FAVisiblePageComment({
    required this.cid,
    required this.indentation,
    required this.author,
    required this.displayAuthor,
    required this.datetime,
    required this.naturalDatetime,
    required this.htmlMessage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FAVisiblePageComment && cid == other.cid;

  @override
  int get hashCode => cid.hashCode;
}

/// A hidden/filtered comment (no author info).
class FAHiddenPageComment extends FAPageComment {
  @override
  final int cid;
  @override
  final int indentation;
  @override
  final String htmlMessage;

  FAHiddenPageComment({
    required this.cid,
    required this.indentation,
    required this.htmlMessage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FAHiddenPageComment && cid == other.cid;

  @override
  int get hashCode => cid.hashCode;
}

/// A folder on FA (used in gallery organization).
class FAFolder {
  final String title;
  final Uri url;
  final bool isActive;
  final String id;

  FAFolder({
    required this.title,
    required this.url,
    required this.isActive,
    required this.id,
  });
}

/// A group of folders (used in gallery/scrap views).
class FAFolderGroup {
  final String? title;
  final List<FAFolder> folders;
  final String id;

  FAFolderGroup({
    required this.title,
    required this.folders,
    required this.id,
  });
}

/// System error page.
class FASystemErrorPage implements FAPage {
  final String message;

  FASystemErrorPage({required this.message});

  static FASystemErrorPage parse(String html) {
    // Extract error message from the page
    final match = RegExp(r'<h2>System Error</h2>.*?<p>(.*?)</p>',
            dotAll: true, multiLine: true)
        .firstMatch(html);
    return FASystemErrorPage(
      message: match?.group(1)?.trim() ?? 'Unknown system error',
    );
  }
}

/// System message page.
class FASystemMessagePage implements FAPage {
  final String message;

  FASystemMessagePage({required this.message});

  static FASystemMessagePage parse(String html) {
    final match = RegExp(r'<h2>System Message</h2>.*?<p>(.*?)</p>',
            dotAll: true, multiLine: true)
        .firstMatch(html);
    return FASystemMessagePage(
      message: match?.group(1)?.trim() ?? 'Unknown system message',
    );
  }
}
