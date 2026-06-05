import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

/// A single notification header (submission comment, journal comment, shout, journal).
class FANotificationHeader {
  final int id;
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime datetime;
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
}

/// Parsed notifications page.
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
  static FANotificationsPage parse(String html, Uri url) {
    final document = parser.parse(html);

    return FANotificationsPage(
      submissionCommentHeaders: _parseNotificationSection(
          document, 'submission_comments', 'comments-submissions'),
      journalCommentHeaders: _parseNotificationSection(
          document, 'journal_comments', 'comments-journals'),
      shoutHeaders: _parseNotificationSection(
          document, 'shouts', 'shouts'),
      journalHeaders: _parseNotificationSection(
          document, 'journals', 'journals'),
    );
  }

  static List<FANotificationHeader> _parseNotificationSection(
      dom.Document document, String sectionId, String inputName) {
    final headers = <FANotificationHeader>[];
    final section = document.querySelector('#$sectionId') ??
        document.querySelector('div.list-$sectionId') ??
        document.querySelector('ul.$inputName');

    if (section == null) return headers;

    final items = section.querySelectorAll('li, .notification-item, div.notification');
    for (final item in items) {
      try {
        final link = item.querySelector('a');
        if (link == null) continue;
        final href = link.attributes['href'] ?? '';

        // Extract ID from checkbox or link
        final checkbox = item.querySelector('input[type="checkbox"]');
        String? idStr;
        if (checkbox != null) {
          idStr = checkbox.attributes['value'];
        }
        if (idStr == null) {
          final idMatch = RegExp(r'id=(\d+)|/(\d+)/').firstMatch(href);
          idStr = idMatch?.group(1) ?? idMatch?.group(2);
        }
        final id = int.tryParse(idStr ?? '') ?? 0;

        // Author
        String author = '';
        String displayAuthor = '';
        final authorLink = item.querySelector('a[href*="/user/"]');
        if (authorLink != null) {
          final authorHref = authorLink.attributes['href'] ?? '';
          final match = RegExp(r'/user/([^/]+)/').firstMatch(authorHref);
          author = match?.group(1) ?? '';
          displayAuthor = authorLink.text.trim();
        }

        // Title
        final title = link.text.trim();

        // Date
        final dateEl = item.querySelector('span.popup_date, span.date, time');
        String naturalDatetime = dateEl?.text.trim() ?? '';
        DateTime datetime = DateTime.now();
        if (dateEl != null) {
          final ts = dateEl.attributes['title'] ?? dateEl.attributes['datetime'] ?? '';
          if (ts.isNotEmpty) {
            datetime = DateTime.tryParse(ts) ?? DateTime.now();
          }
        }

        final notifUrl = Uri.parse(href.startsWith('http')
            ? href
            : 'https://www.furaffinity.net$href');

        headers.add(FANotificationHeader(
          id: id,
          author: author,
          displayAuthor: displayAuthor,
          title: title,
          datetime: datetime,
          naturalDatetime: naturalDatetime,
          url: notifUrl,
        ));
      } catch (_) {
        // Skip malformed entries
      }
    }

    return headers;
  }
}
