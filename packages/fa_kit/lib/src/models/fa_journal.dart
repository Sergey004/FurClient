import 'fa_comment.dart';
import '../pages/fa_journal_page.dart';

/// A full journal entry with all details.
class FAJournal {
  final Uri url;
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime? datetime;
  final String naturalDatetime;
  final String htmlDescription;
  final List<FAComment> comments;
  final int? targetCommentId;
  final bool acceptsNewComments;

  FAJournal({
    required this.url,
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

  /// Create from a parsed journal page.
  factory FAJournal.fromPage(FAJournalPage page, Uri url) {
    return FAJournal(
      url: url,
      author: page.author,
      displayAuthor: page.displayAuthor,
      title: page.title,
      datetime: page.datetime,
      naturalDatetime: page.naturalDatetime,
      htmlDescription: page.htmlDescription,
      comments: buildCommentsTree(page.comments),
      targetCommentId: page.targetCommentId,
      acceptsNewComments: page.acceptsNewComments,
    );
  }
}
