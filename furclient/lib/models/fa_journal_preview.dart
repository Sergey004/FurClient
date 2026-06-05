import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../services/fa_urls.dart';

/// Preview of a journal entry from a user's journals list page.
class FAJournalPreview {
  final int id;
  final String title;
  final String date;
  final String url;

  FAJournalPreview({
    required this.id,
    required this.title,
    required this.date,
    required this.url,
  });

  /// Parse journals list page HTML — same selectors as FAKit FAUserJournalsPage.
  static List<FAJournalPreview> parseJournalsPage(String htmlString) {
    final document = html_parser.parse(htmlString);
    final journals = <FAJournalPreview>[];

    final journalLinks = document.querySelectorAll('a[href*="/journal/"]');

    for (final link in journalLinks) {
      try {
        final href = link.attributes['href'] ?? '';
        final idMatch = RegExp(r'/journal/(\d+)/').firstMatch(href);
        if (idMatch == null) continue;
        final id = int.parse(idMatch.group(1)!);

        final title = link.text.trim();
        if (title.isEmpty) continue;

        final journalUrl = href.startsWith('http')
            ? href
            : '${FAUrls.baseUrl}$href';

        // Try to find date near the link
        String date = '';
        final parent = link.parent;
        if (parent != null) {
          final dateEl = parent.querySelector(
              'span.popup_date, span.date, time');
          if (dateEl != null) {
            date = dateEl.attributes['title'] ?? dateEl.text.trim();
          }
        }

        journals.add(FAJournalPreview(
          id: id,
          title: title,
          date: date,
          url: journalUrl,
        ));
      } catch (_) {
        // Skip
      }
    }

    debugPrint('=== parseJournalsPage: ${journals.length} journals');
    return journals;
  }
}
