import 'package:html/parser.dart' as html_parser;
import 'fa_comment.dart';

/// A journal entry with full content and comments.
class FAJournal {
  final String id;
  final String title;
  final String author;
  final String date;
  final String content;
  final List<FAComment> comments;

  FAJournal({
    required this.id,
    required this.title,
    required this.author,
    required this.date,
    required this.content,
    required this.comments,
  });

  /// Parse a journal detail page HTML into an FAJournal.
  static FAJournal? parseJournalDetail(String html, String journalId) {
    final document = html_parser.parse(html);

    // Title: h2.title or h2 or .journal-title
    final titleEl = document.querySelector('h2.title') ??
        document.querySelector('h2') ??
        document.querySelector('.journal-title');
    final title = titleEl?.text.trim() ?? '';

    // Author: a[href*="/user/"]
    String author = '';
    final authorLink = document.querySelector('a[href*="/user/"]');
    if (authorLink != null) {
      final href = authorLink.attributes['href'] ?? '';
      final match = RegExp(r'/user/([^/]+)/').firstMatch(href);
      author = match?.group(1) ?? '';
    }

    // Date: span.popup_date or span.date or time
    String date = '';
    final dateEl = document.querySelector('span.popup_date') ??
        document.querySelector('span.date') ??
        document.querySelector('time');
    if (dateEl != null) {
      date = dateEl.attributes['title'] ?? dateEl.text.trim();
    }

    // Content: div#journal-description or .journal-content or .journal-body
    final descEl = document.querySelector('div#journal-description') ??
        document.querySelector('.journal-content') ??
        document.querySelector('.journal-body');
    final content = descEl?.text.trim() ?? '';

    // Comments: reuse FAComment parser
    final comments = FAComment.parseComments(html);

    if (title.isEmpty && content.isEmpty) return null;

    return FAJournal(
      id: journalId,
      title: title,
      author: author,
      date: date,
      content: content,
      comments: comments,
    );
  }
}
