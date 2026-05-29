import 'package:html/parser.dart' as parser;

/// A single journal in a user's journal list.
class FAUserJournalEntry {
  final int id;
  final String title;
  final DateTime datetime;
  final String naturalDatetime;
  final Uri url;

  FAUserJournalEntry({
    required this.id,
    required this.title,
    required this.datetime,
    required this.naturalDatetime,
    required this.url,
  });
}

/// Parsed user journals list page.
class FAUserJournalsPage {
  final String displayAuthor;
  final List<FAUserJournalEntry> journals;

  FAUserJournalsPage({
    required this.displayAuthor,
    required this.journals,
  });

  /// Parse the user journals list page HTML.
  static FAUserJournalsPage parse(String html, Uri url) {
    final document = parser.parse(html);

    String displayAuthor = '';
    final authorEl = document.querySelector('h2, .section-title');
    if (authorEl != null) {
      displayAuthor = authorEl.text.trim();
    }

    final journals = <FAUserJournalEntry>[];
    final journalLinks = document.querySelectorAll('a[href*="/journal/"]');

    for (final link in journalLinks) {
      try {
        final href = link.attributes['href'] ?? '';
        final idMatch = RegExp(r'/journal/(\d+)/').firstMatch(href);
        if (idMatch == null) continue;
        final id = int.parse(idMatch.group(1)!);

        final journalUrl = Uri.parse(href.startsWith('http')
            ? href
            : 'https://www.furaffinity.net$href');

        final title = link.text.trim();
        if (title.isEmpty) continue;

        // Try to find date near the link
        DateTime datetime = DateTime.now();
        String naturalDatetime = '';
        final parent = link.parent;
        if (parent != null) {
          final dateEl = parent.querySelector('span.popup_date, span.date, time');
          if (dateEl != null) {
            naturalDatetime = dateEl.text.trim();
            final ts = dateEl.attributes['title'] ?? dateEl.attributes['datetime'] ?? '';
            if (ts.isNotEmpty) {
              datetime = DateTime.tryParse(ts) ?? DateTime.now();
            }
          }
        }

        journals.add(FAUserJournalEntry(
          id: id,
          title: title,
          datetime: datetime,
          naturalDatetime: naturalDatetime,
          url: journalUrl,
        ));
      } catch (_) {
        // Skip
      }
    }

    return FAUserJournalsPage(
      displayAuthor: displayAuthor,
      journals: journals,
    );
  }
}
