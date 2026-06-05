import 'package:html/parser.dart' as parser;

/// Parsed "new note" page (used to obtain the API key for sending notes).
class FANewNotePage {
  final String apiKey;

  FANewNotePage({required this.apiKey});

  /// Parse the new note page HTML to extract the API key.
  static FANewNotePage parse(String html, Uri url) {
    final document = parser.parse(html);

    final keyInput = document.querySelector('input[name="key"]') ??
        document.querySelector('input[name="reply_key"]') ??
        document.querySelector('input[type="hidden"][value*="-"]');

    final apiKey = keyInput?.attributes['value'] ?? '';

    if (apiKey.isEmpty) {
      throw Exception('Could not extract API key from new note page');
    }

    return FANewNotePage(apiKey: apiKey);
  }
}
