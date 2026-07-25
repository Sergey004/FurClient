import 'package:html/parser.dart' as parser;
import 'fa_page.dart';
import '../utils/fa_date_parser.dart';

/// Parsed journal detail page.
///
/// Mirrors `FAJournalPage` in FAJournalPage.swift:11-76.
class FAJournalPage implements FAPage {
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime? datetime;
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
  ///
  /// Mirrors `FAJournalPage.init(data:url:)` in
  /// FAJournalPage.swift:24-76.
  static FAJournalPage parse(String html, Uri url) {
    final document = parser.parse(html);

    // html body#pageid-journal div#main-window div#site-content
    final siteContentNode = document.querySelector(
        'html body#pageid-journal div#main-window div#site-content');

    // ── Author ──────────────────────────────────────────────────────
    // userpage-nav-header userpage-nav-user-details username
    //   div.c-usernameBlock a.c-usernameBlock__displayName
    final userNode = siteContentNode?.querySelector(
        'userpage-nav-header userpage-nav-user-details username div.c-usernameBlock a.c-usernameBlock__displayName');
    String author = '';
    String displayAuthor = '';
    if (userNode != null) {
      final href = userNode.attributes['href'] ?? '';
      final match = RegExp(r'/user/(.+)/').firstMatch(href);
      author = match?.group(1) ?? '';
      displayAuthor = userNode.text.trim();
    }

    // ── Section node ────────────────────────────────────────────────
    final sectionNode =
        siteContentNode?.querySelector('div#columnpage div.content section');

    // ── Title ───────────────────────────────────────────────────────
    // div.section-header div#c-journalTitleTop span#c-journalTitleTop__subject
    final titleEl = sectionNode?.querySelector(
        'div.section-header div#c-journalTitleTop span#c-journalTitleTop__subject');
    final title = titleEl?.text.trim() ?? '';

    // ── Date ────────────────────────────────────────────────────────
    // div.section-header div span.popup_date
    final dateEl =
        sectionNode?.querySelector('div.section-header div span.popup_date');
    final dateResult = parseFADateNode(dateEl);

    // ── htmlDescription ───────────────────────────────────────────
    // div.journal-body-theme div.journal-item
    final descEl =
        sectionNode?.querySelector('div.journal-body-theme div.journal-item');
    final htmlDescription = descEl?.innerHtml.trim() ?? '';

    // ── Comments ───────────────────────────────────────────────────
    // div#columnpage div.content div#comments-journal div.comment_container
    final commentNodes = siteContentNode?.querySelectorAll(
            'div#columnpage div.content div#comments-journal div.comment_container') ??
        [];
    final comments = commentNodes
        .map((node) => parsePageComment(node, CommentType.comment))
        .toList();

    // ── Target comment from URL ───────────────────────────────────
    int? targetCommentId;
    final targetMatch =
        RegExp(r'www\.furaffinity\.net\/journal\/\d+\/#cid:(\d+)$')
            .firstMatch(url.toString());
    if (targetMatch != null) {
      targetCommentId = int.tryParse(targetMatch.group(1) ?? '');
    }

    // ── Accepts new comments? ──────────────────────────────────
    final responseBox =
        siteContentNode?.querySelector('div#columnpage div#responsebox');
    final responseText = responseBox?.text ?? '';
    final acceptsNewComments =
        !responseText.contains('Comment posting has been disabled');

    return FAJournalPage(
      author: author,
      displayAuthor: displayAuthor,
      title: title,
      datetime: dateResult.datetime,
      naturalDatetime: dateResult.naturalDatetime,
      htmlDescription: htmlDescription,
      comments: comments,
      targetCommentId: targetCommentId,
      acceptsNewComments: acceptsNewComments,
    );
  }
}
