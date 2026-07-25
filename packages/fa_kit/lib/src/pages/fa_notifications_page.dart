import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import '../utils/fa_date_parser.dart';
import 'fa_urls.dart';

/// A single notification header (submission comment, journal comment,
/// shout, or journal).
///
/// Mirrors `FANotificationsPage.Header` in
/// FANotificationsPage.swift:11-26.
class FANotificationHeader {
  final int id;
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime? datetime;
  final String naturalDatetime;
  final Uri url;

  FANotificationHeader({
    required this.id,
    required this.author,
    required this.displayAuthor,
    required this.title,
    required this.datetime,
    required this.naturalDatetime,
    required this.url,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FANotificationHeader && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Parsed notifications page.
///
/// Mirrors `FANotificationsPage` in FANotificationsPage.swift:11-65.
class FANotificationsPage {
  final List<FANotificationHeader> submissionCommentHeaders;
  final List<FANotificationHeader> journalCommentHeaders;
  final List<FANotificationHeader> shoutHeaders;
  final List<FANotificationHeader> journalHeaders;

  FANotificationsPage({
    required this.submissionCommentHeaders,
    required this.journalCommentHeaders,
    required this.shoutHeaders,
    required this.journalHeaders,
  });

  /// Parse the notifications page HTML.
  ///
  /// Mirrors `FANotificationsPage.init(data:url:)` in
  /// FANotificationsPage.swift:28-65.
  static FANotificationsPage parse(String html, Uri url) {
    final document = parser.parse(html);

    // body div#main-window div#site-content div#messagecenter-other
    //   div#columnpage div.submission-content form#messages-form
    final formNode = document.querySelector(
        'body div#main-window div#site-content div#messagecenter-other div#columnpage div.submission-content form#messages-form');

    final submissionCommentNodes = formNode?.querySelectorAll(
            'section#messages-comments-submission div.section-body ul.message-stream li') ??
        [];
    final journalCommentNodes = formNode?.querySelectorAll(
            'section#messages-comments-journal div.section-body ul.message-stream li') ??
        [];
    final shoutNodes = formNode?.querySelectorAll(
            'section#messages-shouts > div.section-body > ul.message-stream > li') ??
        [];
    final journalNodes = formNode?.querySelectorAll(
            'section#messages-journals ul.message-stream li div.table') ??
        [];

    return FANotificationsPage(
      submissionCommentHeaders: submissionCommentNodes
          .map((li) => _parseCommentNotification(
              li,
              urlNodeSelector: 'strong i a',
              idPattern: r'/view/\d+/#cid:(\d+)'))
          .toList(),
      journalCommentHeaders: journalCommentNodes
          .map((li) => _parseCommentNotification(
              li,
              urlNodeSelector: 'b i a',
              idPattern: r'/journal/\d+/#cid:(\d+)'))
          .toList(),
      shoutHeaders: shoutNodes
          .map((li) => _parseShoutNotification(li, document))
          .toList(),
      journalHeaders: journalNodes.map(_parseJournalNotification).toList(),
    );
  }

  /// Parse a comment notification (submission or journal comment).
  ///
  /// Mirrors `FANotificationsPage.Header.comment(_:urlNodeSelector:idMatchingPattern:)`
  /// in FANotificationsPage.swift:105-123.
  static FANotificationHeader _parseCommentNotification(
    dom.Element li, {
    required String urlNodeSelector,
    required String idPattern,
  }) {
    final datetimeNode = li.querySelector('div span.popup_date');
    final dateResult = parseFADateNode(datetimeNode);

    final authorNode = li.querySelector('span.c-usernameBlockSimple a');
    final authorHref = authorNode?.attributes['href'] ?? '';
    final authorMatch = RegExp(r'/user/(.+)/').firstMatch(authorHref);
    final author = authorMatch?.group(1) ?? '';
    final displayAuthor =
        authorNode?.querySelector('span.c-usernameBlockSimple__displayName')?.text.trim() ??
            authorNode?.text.trim() ??
            '';

    final commentTargetNode = li.querySelector(urlNodeSelector);
    final title = commentTargetNode?.text.trim() ?? '';
    final urlStr = commentTargetNode?.attributes['href'] ?? '';
    final idMatch = RegExp(idPattern).firstMatch(urlStr);
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
    final url = Uri.parse(urlStr.startsWith('http')
        ? urlStr
        : '${FAURLs.baseUrl}$urlStr');

    return FANotificationHeader(
      id: id,
      author: author,
      displayAuthor: displayAuthor,
      title: title,
      datetime: dateResult.datetime,
      naturalDatetime: dateResult.naturalDatetime,
      url: url,
    );
  }

  /// Parse a shout notification.
  ///
  /// Mirrors `FANotificationsPage.Header.shout(_:page:)` in
  /// FANotificationsPage.swift:125-146.
  static FANotificationHeader _parseShoutNotification(
      dom.Element li, dom.Document page) {
    // Author — last <a> link in the <li>.
    final allLinks = li.querySelectorAll('a');
    final linkNode = allLinks.isNotEmpty ? allLinks.last : null;
    final userStr = linkNode?.attributes['href'] ?? '';
    final authorMatch = RegExp(r'/user/(.+)/').firstMatch(userStr);
    final author = authorMatch?.group(1) ?? '';
    final displayAuthor = linkNode?.text.trim() ?? '';

    // ID — from the <input> checkbox value (shouts[]).
    final inputEl = li.querySelector('input[type="checkbox"]');
    final id = int.tryParse(inputEl?.attributes['value'] ?? '') ?? 0;

    // URL — point at the user's shoutbox; use the current user's page URL
    // (parsed from the nav avatar) plus the #shout- anchor.
    final currentUserUrl = _currentUserPageUrl(page);
    final commentAnchor = '#shout-$id';
    final url = Uri.parse(currentUserUrl + commentAnchor);
    final title = '';

    final datetimeNode = li.querySelector('div span.popup_date');
    final dateResult = parseFADateNode(datetimeNode);

    return FANotificationHeader(
      id: id,
      author: author,
      displayAuthor: displayAuthor,
      title: title,
      datetime: dateResult.datetime,
      naturalDatetime: dateResult.naturalDatetime,
      url: url,
    );
  }

  /// Parse a journal (new-journal-post) notification.
  ///
  /// Mirrors `FANotificationsPage.Header.journal(_:)` in
  /// FANotificationsPage.swift:68-91.
  static FANotificationHeader _parseJournalNotification(dom.Element tableNode) {
    // baseNode — div.user-submitted-links
    final baseNode = tableNode.querySelector('div.user-submitted-links');
    final linkNode = baseNode?.querySelector('a');
    final urlStr = linkNode?.attributes['href'] ?? '';
    final url = Uri.parse(urlStr.startsWith('http')
        ? urlStr
        : '${FAURLs.baseUrl}$urlStr');

    final idMatch = RegExp(r'/journal/(\d+)/').firstMatch(urlStr);
    final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;

    final titleEl = baseNode?.querySelector('em.journal_subject');
    final title = titleEl?.text.trim() ?? '';

    final authorNode = tableNode.querySelector('span.c-usernameBlockSimple a');
    final authorHref = authorNode?.attributes['href'] ?? '';
    final authorMatch = RegExp(r'/user/(.+)/').firstMatch(authorHref);
    final author = authorMatch?.group(1) ?? '';
    final displayAuthor =
        authorNode?.querySelector('span.c-usernameBlockSimple__displayName')?.text.trim() ??
            authorNode?.text.trim() ??
            '';

    final datetimeNode = tableNode.querySelector('span span.popup_date');
    final dateResult = parseFADateNode(datetimeNode);

    return FANotificationHeader(
      id: id,
      author: author,
      displayAuthor: displayAuthor,
      title: title,
      datetime: dateResult.datetime,
      naturalDatetime: dateResult.naturalDatetime,
      url: url,
    );
  }

  /// Get the current logged-in user's profile URL from the page's nav avatar.
  ///
  /// The Swift code uses `nav#ddmenu > ul > li > div > a > img.avatar`, but
  /// we use a more resilient fallback: `img.avatar` inside the nav, or the
  /// mobile nav content container. Falls back to the root FA URL if the
  /// current user cannot be located.
  static String _currentUserPageUrl(dom.Document page) {
    // Try the desktop nav first — exactly as the Swift code.
    var imgEl = page.querySelector('nav#ddmenu ul li div a > img.avatar');
    // Fallback — the mobile / desktop nav with `.loggedin_user_avatar.avatar`.
    imgEl ??= page.querySelector('img.loggedin_user_avatar.avatar');
    if (imgEl != null) {
      final parentA = imgEl.parent;
      final href = parentA?.attributes['href'] ?? '';
      if (href.isNotEmpty) {
        if (href.startsWith('http')) return href;
        return '${FAURLs.baseUrl}${href.startsWith('/') ? href : '/$href'}';
      }
    }
    return FAURLs.baseUrl;
  }
}
