import 'package:html/parser.dart' as parser;

/// Parsed FA home page, used to validate login and extract username.
class FAHomePage {
  final String username;
  final String displayUsername;

  FAHomePage({
    required this.username,
    required this.displayUsername,
  });

  /// Parse the FA home page HTML.
  static FAHomePage parse(String html, Uri url) {
    final document = parser.parse(html);

    // Try multiple selectors to find the username
    String? username;
    String? displayUsername;

    // Look for the logged-in user indicator
    final userLink = document.querySelector('a[href*="/user/"]');
    if (userLink != null) {
      final href = userLink.attributes['href'] ?? '';
      final nameMatch = RegExp(r'/user/([^/]+)/').firstMatch(href);
      username = nameMatch?.group(1);
      displayUsername = userLink.text.trim();
    }

    // Fallback: look for the profile header
    if (username == null) {
      final profileLink =
          document.querySelector('div.username a[href*="/user/"]');
      if (profileLink != null) {
        final href = profileLink.attributes['href'] ?? '';
        final nameMatch = RegExp(r'/user/([^/]+)/').firstMatch(href);
        username = nameMatch?.group(1);
        displayUsername = profileLink.text.trim();
      }
    }

    // Fallback: try to extract from the "My FA" link or profile link
    if (username == null) {
      final links = document.querySelectorAll('a');
      for (final link in links) {
        final href = link.attributes['href'] ?? '';
        if (href.contains('/user/') && !href.contains('favorites')) {
          final nameMatch = RegExp(r'/user/([^/]+)/?').firstMatch(href);
          if (nameMatch != null) {
            username = nameMatch.group(1);
            displayUsername = link.text.trim();
            break;
          }
        }
      }
    }

    if (username == null) {
      throw Exception('Could not extract username from home page');
    }

    return FAHomePage(
      username: username,
      displayUsername: displayUsername ?? username,
    );
  }
}
