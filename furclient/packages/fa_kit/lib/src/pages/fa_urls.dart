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

  /// New submissions (latest 72).
  static String get submissionsNewUrl => '$_baseUrl/msg/submissions/new@72';

  /// Submissions starting from a specific submission ID.
  static String submissionsFromUrl(int sid) =>
      '$_baseUrl/msg/submissions/new~$sid@72';

  /// Notifications page.
  static String get notificationsUrl => '$_baseUrl/msg/others/';

  /// Notes inbox.
  static String get notesInboxUrl => '$_baseUrl/controls/switchbox/inbox/';

  /// Notes sent.
  static String get notesSentUrl => '$_baseUrl/controls/switchbox/sent/';

  /// Notes archive.
  static String get notesArchiveUrl => '$_baseUrl/controls/switchbox/archive/';

  /// Notes trash.
  static String get notesTrashUrl => '$_baseUrl/controls/switchbox/trash/';

  /// User page.
  static String userUrl(String username) =>
      '$_baseUrl/user/$username/';

  /// User avatar URL (.gif).
  static String avatarUrl(String username) =>
      '$_avatarBaseUrl/$username.gif';

  /// New note to a user (get the API key page).
  static String newNoteUrl(String username) =>
      '$_baseUrl/newpm/$username/';

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
  static String submissionUrl(int sid) =>
      '$_baseUrl/view/$sid/';

  /// Journal detail page.
  static String journalUrl(int jid) =>
      '$_baseUrl/journal/$jid/';

  /// Send note endpoint.
  static String get sendNoteUrl => '$_baseUrl/msg/send/';

  /// Manage notes endpoint.
  static String get manageNotesUrl => '$_baseUrl/msg/pms/';

  /// Watchlist page (users being watched by a user).
  static String watchlistByUrl(String username, {int page = 1}) =>
      '$_baseUrl/watchlist/by/$username?page=$page';

  /// Watchlist page (users watching a user).
  static String watchlistToUrl(String username, {int page = 1}) =>
      '$_baseUrl/watchlist/to/$username?page=$page';

  /// Theme CSS URLs.
  static String themeCssUrl(FATheme theme) =>
      '$_baseUrl/themes/beta/css/ui_theme_${theme == FATheme.dark ? "dark" : "light"}.css';
}

/// FA color theme.
enum FATheme { light, dark }
