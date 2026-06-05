import 'package:html/parser.dart' as parser;

/// A note header in the notes list.
class FANoteHeader {
  final int id;
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime datetime;
  final String naturalDatetime;
  final bool unread;
  final Uri noteUrl;

  FANoteHeader({
    required this.id,
    required this.author,
    required this.displayAuthor,
    required this.title,
    required this.datetime,
    required this.naturalDatetime,
    required this.unread,
    required this.noteUrl,
  });
}

/// Parsed notes list page.
class FANotesPage {
  final List<FANoteHeader?> noteHeaders;

  FANotesPage({required this.noteHeaders});

  /// Parse the notes list page HTML.
  static FANotesPage parse(String html, Uri url) {
    final document = parser.parse(html);
    final headers = <FANoteHeader?>[];

    final rows = document.querySelectorAll('table.notes-table tr, table tbody tr, .note-list-item');
    for (final row in rows) {
      try {
        final link = row.querySelector('a[href*="/msg/pms/"]');
        if (link == null) continue;
        final href = link.attributes['href'] ?? '';

        final idMatch = RegExp(r'/(\d+)/').firstMatch(href);
        final id = int.tryParse(idMatch?.group(1) ?? '') ?? 0;
        if (id == 0) continue;

        final noteUrl = Uri.parse(href.startsWith('http')
            ? href
            : 'https://www.furaffinity.net$href');

        // Author
        final authorLink = row.querySelector('a[href*="/user/"]');
        String author = '';
        String displayAuthor = '';
        if (authorLink != null) {
          final authorHref = authorLink.attributes['href'] ?? '';
          final match = RegExp(r'/user/([^/]+)/').firstMatch(authorHref);
          author = match?.group(1) ?? '';
          displayAuthor = authorLink.text.trim();
        }

        // Title
        final title = link.text.trim();

        // Date
        final dateEl = row.querySelector('span.popup_date, span.date, time');
        String naturalDatetime = dateEl?.text.trim() ?? '';
        DateTime datetime = DateTime.now();
        if (dateEl != null) {
          final ts = dateEl.attributes['title'] ?? dateEl.attributes['datetime'] ?? '';
          if (ts.isNotEmpty) {
            datetime = DateTime.tryParse(ts) ?? DateTime.now();
          }
        }

        // Unread status (bold title or unread class)
        final isBold = link.classes.contains('bold') ||
            link.classes.contains('unread') ||
            (link.querySelector('b, strong') != null);
        final unread = isBold;

        headers.add(FANoteHeader(
          id: id,
          author: author,
          displayAuthor: displayAuthor,
          title: title,
          datetime: datetime,
          naturalDatetime: naturalDatetime,
          unread: unread,
          noteUrl: noteUrl,
        ));
      } catch (_) {
        headers.add(null);
      }
    }

    return FANotesPage(noteHeaders: headers);
  }
}
