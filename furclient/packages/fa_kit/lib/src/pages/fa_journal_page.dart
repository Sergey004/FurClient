import 'package:html/parser.dart' as parser;
import 'fa_page.dart';

/// Parsed journal detail page.
class FAJournalPage implements FAPage {
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime datetime;
  final String naturalDatetime;
  final String htmlDescription;
  final List<FAPageComment> comments;
  final int? targetCommentId;
  final bool acceptsNewComments;

  FAJournalPage({
    required this.author,
    required this.displayAuthor,
    required this.title,
    required this.datetime,
    required this.naturalDatetime,
    required this.htmlDescription,
    required this.comments,
    this.targetCommentId,
    required this.acceptsNewComments,
  });

  /// Parse the journal detail page HTML.
  static FAJournalPage parse(String html, Uri url) {
    final document = parser.parse(html);

    // Title
    final titleEl = document.querySelector('h2.title') ??
        document.querySelector('h2') ??
        document.querySelector('.journal-title');
    final title = titleEl?.text.trim() ?? '';

    // Author
    String author = '';
    String displayAuthor = '';
    final authorLink = document.querySelector('a[href*="/user/"]');
    if (authorLink != null) {
      final href = authorLink.attributes['href'] ?? '';
      final match = RegExp(r'/user/([^/]+)/').firstMatch(href);
      author = match?.group(1) ?? '';
      displayAuthor = authorLink.text.trim();
    }

    // Date/time
    DateTime datetime = DateTime.now();
    String naturalDatetime = '';
    final dateEl = document.querySelector('span.popup_date') ??
        document.querySelector('span.date') ??
        document.querySelector('time');
    if (dateEl != null) {
      naturalDatetime = dateEl.text.trim();
      final ts = dateEl.attributes['title'] ?? dateEl.attributes['datetime'] ?? '';
      if (ts.isNotEmpty) {
        datetime = DateTime.tryParse(ts) ?? DateTime.now();
      }
    }

    // Description / content
    final descEl = document.querySelector('div#journal-description') ??
        document.querySelector('.journal-content') ??
        document.querySelector('.journal-body');
    final htmlDescription = descEl?.innerHtml ?? '';

    // Comments (reuse same logic as submission comments)
    final comments = <FAPageComment>[];
    final commentElements = document.querySelectorAll(
        'div.comment-container, div.comment, li.comment');

    for (final commentEl in commentElements) {
      try {
        final hiddenText = commentEl.querySelector('.comment-hidden, .hidden-comment');
        if (hiddenText != null) {
          final cidMatch = RegExp(r'cid=(\d+)').firstMatch(commentEl.outerHtml);
          final cid = int.tryParse(cidMatch?.group(1) ?? '') ?? 0;
          comments.add(FAHiddenPageComment(
            cid: cid,
            indentation: 0,
            htmlMessage: hiddenText.text.trim(),
          ));
          continue;
        }

        final cidMatch = RegExp(r'cid=(\d+)').firstMatch(commentEl.outerHtml);
        final cid = int.tryParse(cidMatch?.group(1) ?? '') ?? 0;

        final indentEl = commentEl.querySelector('.comment-indentation, .comment-avatar');
        int indentation = 0;
        if (indentEl != null) {
          final widthAttr = indentEl.attributes['width'] ?? '0';
          indentation = (double.tryParse(widthAttr) ?? 0).toInt() ~/ 16;
        }

        final cAuthorLink = commentEl.querySelector('a.comment-username, a[href*="/user/"]');
        final cAuthor = cAuthorLink != null
            ? (RegExp(r'/user/([^/]+)/').firstMatch(
                cAuthorLink.attributes['href'] ?? '')?.group(1) ?? '')
            : '';
        final cDisplayAuthor = cAuthorLink?.text.trim() ?? '';

        final cDateEl = commentEl.querySelector('span.comment-date, span.popup_date');
        final cNaturalDatetime = cDateEl?.text.trim() ?? '';
        final cDatetimeAttr = cDateEl?.attributes['title'] ?? '';
        final cDatetime = DateTime.tryParse(cDatetimeAttr) ?? DateTime.now();

        final messageEl = commentEl.querySelector('div.comment-text, div.comment_message');
        final htmlMessage = messageEl?.innerHtml ?? '';

        comments.add(FAVisiblePageComment(
          cid: cid,
          indentation: indentation,
          author: cAuthor,
          displayAuthor: cDisplayAuthor,
          datetime: cDatetime,
          naturalDatetime: cNaturalDatetime,
          htmlMessage: htmlMessage,
        ));
      } catch (_) {
        // Skip malformed comments
      }
    }

    // Target comment from URL
    int? targetCommentId;
    final hashMatch = RegExp(r'cid(\d+)').firstMatch(url.fragment);
    if (hashMatch != null) {
      targetCommentId = int.tryParse(hashMatch.group(1)!);
    }

    // Accepts new comments?
    final commentForm = document.querySelector('form[action*="reply"]');
    final acceptsNewComments = commentForm != null;

    return FAJournalPage(
      author: author,
      displayAuthor: displayAuthor,
      title: title,
      datetime: datetime,
      naturalDatetime: naturalDatetime,
      htmlDescription: htmlDescription,
      comments: comments,
      targetCommentId: targetCommentId,
      acceptsNewComments: acceptsNewComments,
    );
  }
}
