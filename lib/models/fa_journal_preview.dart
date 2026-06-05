import 'package:html/parser.dart' as html_parser;

/// A preview of a journal entry in a user's journal list.
class FAJournalPreview {
  final String id;
  final String title;
  final String date;

  FAJournalPreview({
    required this.id,
    required this.title,
    required this.date,
  });

  /// Parse a user journals list page HTML into a list of previews.
  static List<FAJournalPreview> parseJournalList(String html) {
    final document = html_parser.parse(html);
    final journals = <FAJournalPreview>[];
    final journalLinks = document.querySelectorAll('a[href*="/journal/"]');

    for (final link in journalLinks) {
      try {
        final href = link.attributes['href'] ?? '';
        final idMatch = RegExp(r'/journal/(\d+)/').firstMatch(href);
        if (idMatch == null) continue;
        final id = idMatch.group(1)!;

        final title = link.text.trim();
        if (title.isEmpty) continue;

        // Try to find date near the link
        String date = '';
        final parent = link.parent;
        if (parent != null) {
          final dateEl = parent.querySelector(
            'span.popup_date, span.date, time',
          );
          if (dateEl != null) {
            date = dateEl.attributes['title'] ??
                dateEl.attributes['datetime'] ??
                dateEl.text.trim();
          }
        }

        journals.add(FAJournalPreview(id: id, title: title, date: date));
      } catch (_) {
        // Skip malformed entries
      }
    }

    return journals;
  }
}
