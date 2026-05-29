import 'package:html/parser.dart' as parser;

/// Parsed note detail page.
class FANotePage {
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime datetime;
  final String naturalDatetime;
  final String htmlMessage;
  final String htmlMessageWithoutWarning;
  final String? answerKey;
  final String? answerPlaceholderMessage;

  FANotePage({
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

  /// Parse the note detail page HTML.
  static FANotePage parse(String html, Uri url) {
    final document = parser.parse(html);

    // Title
    final titleEl = document.querySelector('h2, .note-title');
    final title = titleEl?.text.trim() ?? '';

    // Author
    String author = '';
    String displayAuthor = '';
    final authorLink = document.querySelector('a[href*="/user/"]');
    if (authorLink != null) {
      final href = authorLink.attributes['href'] ?? '';
      final match = RegExp(r'/user/([^/]+)/').firstMatch(href);
      author = match?.group(1) ?? '';
      displayAuthor = authorLink.text.trim();
    }

    // Date
    DateTime datetime = DateTime.now();
    String naturalDatetime = '';
    final dateEl = document.querySelector('span.popup_date, span.date, time');
    if (dateEl != null) {
      naturalDatetime = dateEl.text.trim();
      final ts =
          dateEl.attributes['title'] ?? dateEl.attributes['datetime'] ?? '';
      if (ts.isNotEmpty) {
        datetime = DateTime.tryParse(ts) ?? DateTime.now();
      }
    }

    // Message (may contain a warning block at the top)
    final messageEl = document.querySelector('div.note-body, .note-content');
    String htmlMessage = messageEl?.innerHtml ?? '';
    String htmlMessageWithoutWarning = htmlMessage;

    // Strip the warning block for clean message
    final warningEl = messageEl?.querySelector('div.warning, .note-warning');
    if (warningEl != null) {
      htmlMessageWithoutWarning =
          messageEl!.innerHtml.replaceFirst(warningEl.outerHtml, '').trim();
    }

    // Answer key and placeholder for replies
    String? answerKey;
    String? answerPlaceholderMessage;
    final answerKeyInput = document.querySelector('input[name="key"]') ??
        document.querySelector('input[name="answer_key"]');
    if (answerKeyInput != null) {
      answerKey = answerKeyInput.attributes['value'];
    }

    final placeholderInput =
        document.querySelector('input[name="answer_placeholder"]');
    if (placeholderInput != null) {
      answerPlaceholderMessage = placeholderInput.attributes['value'];
    }

    return FANotePage(
      author: author,
      displayAuthor: displayAuthor,
      title: title,
      datetime: datetime,
      naturalDatetime: naturalDatetime,
      htmlMessage: htmlMessage,
      htmlMessageWithoutWarning: htmlMessageWithoutWarning,
      answerKey: answerKey,
      answerPlaceholderMessage: answerPlaceholderMessage,
    );
  }
}
