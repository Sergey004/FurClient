import 'package:fa_kit/fa_kit.dart' as fa;

/// A journal entry with full content and comments.
class FAJournal {
  final int id;
  final String title;
  final String author;
  final String displayAuthor;
  final String date;
  final String naturalDate;
  final String content;
  final List<FAComment> comments;

  FAJournal({
    required this.id,
    required this.title,
    required this.author,
    this.displayAuthor = '',
    required this.date,
    this.naturalDate = '',
    required this.content,
    required this.comments,
  });

  // ── Backward compat ──
  String get idString => id.toString();

  factory FAJournal.fromFAJournalPage(fa.FAJournalPage page, int journalId) {
    return FAJournal(
      id: journalId,
      title: page.title,
      author: page.author,
      displayAuthor: page.displayAuthor,
      date: page.naturalDatetime,
      naturalDate: page.naturalDatetime,
      content: page.htmlDescription,
      comments: fa
          .buildCommentsTree(page.comments)
          .map((c) => FAComment.fromFAComment(c))
          .toList(),
    );
  }

  // ── Legacy parser (deprecated, kept for backward compat) ──

  static FAJournal? parseJournalDetail(String html, String journalId) {
    final id = int.tryParse(journalId);
    if (id == null) return null;
    final page = fa.FAJournalPage.parse(
        html, Uri.parse('https://www.furaffinity.net/journal/$journalId/'));
    return FAJournal.fromFAJournalPage(page, id);
  }
}
