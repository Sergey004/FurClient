import 'fa_watchlist_page.dart';

/// URL constants for FurAffinity pages.
class FAURLs {
  static const String _baseUrl = 'https://www.furaffinity.net';
  static const String _avatarBaseUrl = 'https://a.furaffinity.net';

  /// Base URL for FurAffinity.
  static String get baseUrl => _baseUrl;

  /// Home page / Login page.
  static String get homeUrl => '$_baseUrl/';

  /// Signup page.
  static String get signupUrl => '$_baseUrl/register/';

  /// Submissions feed base URL.
  static String get submissionsUrl => '$_baseUrl/msg/submissions/';

  /// New submissions (latest 72).
  static String get submissionsNewUrl => '$submissionsUrl/new@72';

  /// Submissions starting from a specific submission ID.
  static String submissionsFromUrl(int sid) =>
      '$submissionsUrl/new~$sid@72';

  /// Notifications page.
  static String get notificationsUrl => '$_baseUrl/msg/others/';

  /// Notes inbox.
  static String get notesInboxUrl => '$_baseUrl/controls/switchbox/inbox/';

  /// Notes sent.
  static String get notesSentUrl => '$_baseUrl/controls/switchbox/sent/';

  /// Notes archive.
  static String get notesArchiveUrl =>
      '$_baseUrl/controls/switchbox/archive/';

  /// Notes trash.
  static String get notesTrashUrl => '$_baseUrl/controls/switchbox/trash/';

  /// User page.
  static String userUrl(String username) =>
      '$_baseUrl/user/$username/';

  /// User avatar URL (.gif). Returns null for empty username.
  static String? avatarUrl(String username) {
    if (username.isEmpty) return null;
    return '$_avatarBaseUrl/$username.gif';
  }

  /// New note to a user (get the API key page). Returns null for empty username.
  static String? newNoteUrl(String username) {
    if (username.isEmpty) return null;
    return '$_baseUrl/newpm/$username/';
  }

  /// User gallery.
  static String galleryUrl(String username) =>
      '$_baseUrl/gallery/$username/';

  /// User favorites / scraps.
  static String favoritesUrl(String username) =>
      '$_baseUrl/favorites/$username/';

  /// User journals list.
  static String journalsUrl(String username) =>
      '$_baseUrl/journals/$username/';

  /// Submission detail page.
  static String submissionUrl(int sid) => '$_baseUrl/view/$sid/';

  /// Journal detail page.
  static String journalUrl(int jid) => '$_baseUrl/journal/$jid/';

  /// Send note endpoint.
  static String get sendNoteUrl => '$_baseUrl/msg/send/';

  /// Manage notes endpoint.
  static String get manageNotesUrl => '$_baseUrl/msg/pms/';

  /// Watchlist URL with direction and page.
  static String watchlistUrl(
      String username, int page, FAWatchDirection direction) {
    final dir = direction == FAWatchDirection.watching ? 'by' : 'to';
    return '$_baseUrl/watchlist/$dir/$username?page=$page';
  }

  /// Watchlist page (users being watched by a user).
  static String watchlistByUrl(String username, {int page = 1}) =>
      watchlistUrl(username, page, FAWatchDirection.watching);

  /// Watchlist page (users watching a user).
  static String watchlistToUrl(String username, {int page = 1}) =>
      watchlistUrl(username, page, FAWatchDirection.watchedBy);

  /// Theme CSS URLs.
  static String themeCssUrl(FATheme theme) =>
      '$_baseUrl/themes/beta/css/ui_theme_${theme == FATheme.dark ? "dark" : "light"}.css';

  // ── URL Parsing & Detection ──

  /// Extract username from a user URL (e.g. `/user/foobar/` -> `foobar`).
  /// Returns null if the URL is not a valid user page URL.
  static String? usernameFrom(Uri userUrl) {
    final path = userUrl.path;
    if (!path.endsWith('/')) return null;
    final match = RegExp(r'^/user/([^/]+)/$').firstMatch(path);
    return match?.group(1);
  }

  /// Extract username from a user URL string.
  /// Returns null if the URL is not a valid user page URL.
  static String? usernameFromString(String url) {
    return usernameFrom(Uri.parse(url));
  }

  /// Parse a watchlist URL into its components.
  /// Returns null if the URL is not a valid watchlist URL.
  static ({String username, int page, FAWatchDirection direction})?
      parseWatchlistUrl(Uri url) {
    final components = url.pathSegments;
    if (components.length < 4) return null;
    if (components[1] != 'watchlist') return null;

    final dirStr = components[2];
    final username = components[3];

    final FAWatchDirection direction;
    if (dirStr == 'to') {
      direction = FAWatchDirection.watchedBy;
    } else if (dirStr == 'by') {
      direction = FAWatchDirection.watching;
    } else {
      return null;
    }

    int page = 1;
    final pageParam = url.queryParameters['page'];
    if (pageParam != null) {
      page = int.tryParse(pageParam) ?? 1;
    } else if (components.length >= 5) {
      page = int.tryParse(components[4]) ?? 1;
    }

    return (username: username, page: page, direction: direction);
  }

  /// Parse a watchlist URL from string.
  static ({String username, int page, FAWatchDirection direction})?
      parseWatchlistString(String urlString) {
    return parseWatchlistUrl(Uri.parse(urlString));
  }

  /// Parse a submission URL to get the submission ID.
  /// Returns null if the URL is not a valid submission URL.
  static int? submissionIdFrom(Uri url) {
    final match = RegExp(r'^/view/(\d+)/$').firstMatch(url.path);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Parse a journal URL to get the journal ID.
  /// Returns null if the URL is not a valid journal URL.
  static int? journalIdFrom(Uri url) {
    final match = RegExp(r'^/journal/(\d+)/$').firstMatch(url.path);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Parse a note URL to get the note ID.
  /// Returns null if the URL is not a valid note URL.
  static int? noteIdFrom(Uri url) {
    final match = RegExp(r'^/msg/pms/(\d+)/$').firstMatch(url.path);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // ── URL Type Checks ──

  /// Check if a URL is a user page URL.
  static bool isUserUrl(Uri url) {
    return RegExp(r'^/user/[^/]+/$').hasMatch(url.path);
  }

  /// Check if a URL is a submission URL.
  static bool isSubmissionUrl(Uri url) {
    return RegExp(r'^/view/\d+/$').hasMatch(url.path);
  }

  /// Check if a URL is a journal URL.
  static bool isJournalUrl(Uri url) {
    return RegExp(r'^/journal/\d+/$').hasMatch(url.path);
  }

  /// Check if a URL is a note URL.
  static bool isNoteUrl(Uri url) {
    return RegExp(r'^/msg/pms/\d+/$').hasMatch(url.path);
  }

  /// Check if a URL is a gallery URL.
  static bool isGalleryUrl(Uri url) {
    return RegExp(r'^/gallery/[^/]+/$').hasMatch(url.path);
  }

  /// Check if a URL is a favorites URL.
  static bool isFavoritesUrl(Uri url) {
    return RegExp(r'^/favorites/[^/]+/$').hasMatch(url.path);
  }

  /// Check if a URL is a journals list URL.
  static bool isJournalsListUrl(Uri url) {
    return RegExp(r'^/journals/[^/]+/$').hasMatch(url.path);
  }

  /// Check if a URL is a watchlist URL.
  static bool isWatchlistUrl(Uri url) {
    return RegExp(r'^/watchlist/(by|to)/[^/]+/?$').hasMatch(url.path);
  }
}

/// FA color theme.
enum FATheme { light, dark }
