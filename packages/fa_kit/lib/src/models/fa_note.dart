import '../pages/fa_note_page.dart';

/// A full note message.
class FANote {
  final Uri url;
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime datetime;
  final String naturalDatetime;
  final String htmlMessage;
  final String htmlMessageWithoutWarning;
  final String? answerKey;
  final String? answerPlaceholderMessage;

  FANote({
    required this.url,
    required this.author,
    required this.displayAuthor,
    required this.title,
    required this.datetime,
    required this.naturalDatetime,
    required this.htmlMessage,
    required this.htmlMessageWithoutWarning,
    this.answerKey,
    this.answerPlaceholderMessage,
  });

  /// Create from a parsed note page.
  factory FANote.fromPage(FANotePage page, Uri url) {
    return FANote(
      url: url,
      author: page.author,
      displayAuthor: page.displayAuthor,
      title: page.title,
      datetime: page.datetime,
      naturalDatetime: page.naturalDatetime,
      htmlMessage: page.htmlMessage,
      htmlMessageWithoutWarning: page.htmlMessageWithoutWarning,
      answerKey: page.answerKey,
      answerPlaceholderMessage: page.answerPlaceholderMessage,
    );
  }
}
