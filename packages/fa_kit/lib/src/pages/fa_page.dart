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
  final DateTime datetime;
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
