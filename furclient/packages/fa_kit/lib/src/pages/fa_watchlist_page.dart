import 'package:html/parser.dart' as parser;

/// Watch direction.
enum FAWatchDirection { watching, watchedBy }

/// A user in the watchlist.
class FAWatchlistUser {
  final String name;
  final String displayName;

  FAWatchlistUser({required this.name, required this.displayName});
}

/// Parsed watchlist page.
class FAWatchlistPage {
  final FAWatchlistUser? currentUser;
  final FAWatchDirection watchDirection;
  final List<FAWatchlistUser> users;
  final Uri? nextPageUrl;

  FAWatchlistPage({
    this.currentUser,
    required this.watchDirection,
    required this.users,
    this.nextPageUrl,
  });

  /// Parse the watchlist page HTML.
  static FAWatchlistPage parse(String html, Uri url) {
    final document = parser.parse(html);

    // Determine watch direction from URL
    FAWatchDirection direction = FAWatchDirection.watching;
    if (url.path.contains('/watchlist/to/')) {
      direction = FAWatchDirection.watchedBy;
    }

    // Current user
    FAWatchlistUser? currentUser;
    final currentEl = document.querySelector('h2, .current-user');
    if (currentEl != null) {
      currentUser = FAWatchlistUser(
        name: currentEl.text.trim(),
        displayName: currentEl.text.trim(),
      );
    }

    // Parse user entries
    final users = <FAWatchlistUser>[];
    final userLinks = document.querySelectorAll('a[href*="/user/"]');

    for (final link in userLinks) {
      final href = link.attributes['href'] ?? '';
      final match = RegExp(r'/user/([^/]+)/').firstMatch(href);
      if (match == null) continue;
      final name = match.group(1)!;
      final displayName = link.text.trim();
      users.add(FAWatchlistUser(name: name, displayName: displayName));
    }

    // Pagination
    Uri? nextPageUrl;
    final nextLink = document.querySelector('a.next, a.button-right');
    if (nextLink != null) {
      final href = nextLink.attributes['href'] ?? '';
      if (href.isNotEmpty) {
        nextPageUrl = Uri.parse(href.startsWith('http')
            ? href
            : 'https://www.furaffinity.net$href');
      }
    }

    return FAWatchlistPage(
      currentUser: currentUser,
      watchDirection: direction,
      users: users,
      nextPageUrl: nextPageUrl,
    );
  }
}
