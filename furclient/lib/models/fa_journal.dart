import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'fa_comment.dart';

/// Full journal detail — parsed from /journal/{id}/ page.
class FAJournal {
  final int id;
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
    this.comments = const [],
  });

  /// Parse journal detail page HTML.
  /// Uses FAKit FAJournalPage selectors for all fields.
  static FAJournal? parseJournalPage(String htmlString, String journalId) {
    final document = html_parser.parse(htmlString);
    final id = int.tryParse(journalId) ?? 0;
    if (id == 0) return null;

    // ── Title ──────────────────────────────────────────────────────────
    String title = 'Untitled';
    for (final sel in ['h2.title', 'h2', '.journal-title']) {
      final el = document.querySelector(sel);
      if (el != null && el.text.trim().isNotEmpty) {
        title = el.text.trim();
        break;
      }
    }

    // ── Author ─────────────────────────────────────────────────────────
    String author = '';
    final authorLink = document.querySelector('a[href*="/user/"]');
    if (authorLink != null) {
      author = RegExp(r'/user/([^/?#]+)/')
              .firstMatch(authorLink.attributes['href'] ?? '')
              ?.group(1) ??
          authorLink.text.trim();
    }

    // ── Date ───────────────────────────────────────────────────────────
    String date = '';
    for (final sel in ['span.popup_date', 'span.date', 'time']) {
      final el = document.querySelector(sel);
      if (el != null) {
        date = el.attributes['title'] ??
            el.attributes['datetime'] ??
            el.text.trim();
        if (date.isNotEmpty) break;
      }
    }

    // ── Content ────────────────────────────────────────────────────────
    String content = '';
    for (final sel in [
      'div#journal-description',
      'div.journal-description',
      '.journal-content',
      '.journal-body',
      'div[class*="journal-content"]',
      'div[class*="journal-body"]',
    ]) {
      final el = document.querySelector(sel);
      if (el != null && el.text.trim().isNotEmpty) {
        content = el.text.trim();
        break;
      }
    }

    // ── Comments (reuse FAComment parser) ───────────────────────────────
    final comments = FAComment.parseComments(htmlString);

    debugPrint(
        '=== parseJournalPage: id=$id, title=$title, author=$author, '
        'date=$date, content=${content.length} chars, comments=${comments.length}');

    return FAJournal(
      id: id,
      title: title,
      author: author,
      date: date,
      content: content,
      comments: comments,
    );
  }
}
