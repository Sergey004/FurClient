class FAUrls {
  static const String baseUrl = 'https://www.furaffinity.net';

  static String get home => baseUrl;
  static Uri get homeUrl => Uri.parse(baseUrl);

  static String get login => '$baseUrl/login';
  static Uri get loginUrl => Uri.parse(login);

  static String get register => '$baseUrl/register';
  static Uri get registerUrl => Uri.parse(register);

  static String get submissions => '$baseUrl/msg/submissions/new@72';
  static Uri get latest72SubmissionsUrl => Uri.parse(submissions);

  static String submissionsFrom(int sid) =>
      '$baseUrl/msg/submissions/new~$sid@72';

  static Uri submissionsUrl(int sid) => Uri.parse(submissionsFrom(sid));

  static String browse({
    String filter = 'all',
    int? page,
  }) {
    final params = <String>[];
    if (filter != 'all' && filterMap.containsKey(filter)) {
      params.add('type=${filterMap[filter]}');
    }
    if (page != null && page > 1) {
      params.add('page=$page');
    }
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    return '$baseUrl/browse/$query';
  }

  static String viewSubmission(String id) => '$baseUrl/view/$id/';

  /// FA search sort options — mirror FurAffinityApp/FASearchQuery.swift.
  /// `order-by` accepts: relevancy | date | popularity (no `t` suffix).
  /// `order-direction` accepts: asc | desc.
  static const Map<String, String> searchSortLabels = {
    'relevancy': 'Relevance',
    'date': 'Newest',
    'popularity': 'Popular',
  };

  /// Results requested per search page — same value as FurAffinityApp
  /// (FAURLs.swift:158). Used by the client to decide whether a full
  /// page means more may follow.
  static const int searchPageSize = 72;

  /// All rating checkbox suffixes the `/search/` form exposes
  /// (`rating-general`, `rating-mature`, `rating-adult`).
  static const List<String> allSearchRatings = ['general', 'mature', 'adult'];

  /// All content-type checkbox suffixes the `/search/` form exposes
  /// (`type-art`, `type-music`, ...). Mirrors
  /// FASearchQuery.ContentType.allCases.
  static const List<String> allSearchContentTypes = [
    'art',
    'music',
    'flash',
    'story',
    'photo',
    'poetry',
  ];

  /// Builds the `GET /search/` URL. Mirrors FurAffinityApp's
  /// `FAURLs.searchUrl(for:)` exactly — including the `rating-*`,
  /// `type-*` and `range` parameters. Omitting these (as the previous
  /// implementation did) leaves the server to apply its own defaults for
  /// ratings/content types, which silently narrows the result set that
  /// sorting is then applied to and makes "date"/"popularity" sort look
  /// broken or incomplete.
  ///
  /// Defaults mirror FASearchQuery.default: all ratings, all content
  /// types, last 5 years — the same defaults the `/search/` web form uses.
  static String search(
    String query, {
    int page = 1,
    String sortBy = 'relevancy',
    String sortDirection = 'desc',
    List<String> ratings = allSearchRatings,
    List<String> contentTypes = allSearchContentTypes,
    String range = '5years',
  }) {
    final q = Uri.encodeComponent(query);
    final parts = <String>[
      'q=$q',
      'order-by=$sortBy',
      'order-direction=$sortDirection',
      'range=$range',
    ];
    for (final rating in ratings) {
      parts.add('rating-$rating=1');
    }
    for (final type in contentTypes) {
      parts.add('type-$type=1');
    }
    parts.add('mode=extended');
    parts.add('page=$page');
    parts.add('perpage=$searchPageSize');
    return '$baseUrl/search/?${parts.join('&')}';
  }

  static String get notifications => '$baseUrl/msg/others/';
  static String user(String username) => '$baseUrl/user/$username/';
  static String avatar(String username) =>
      'https://a.furaffinity.net/$username.gif';
  static String gallery(String username, {int? page}) {
    final q = (page != null && page > 1) ? '?page=$page' : '';
    return '$baseUrl/gallery/$username/$q';
  }

  static Uri userGalleryUrl(String username, {int? page}) =>
      Uri.parse(gallery(username, page: page));

  static String favorites(String username, {int? page}) {
    final q = (page != null && page > 1) ? '?page=$page' : '';
    return '$baseUrl/favorites/$username/$q';
  }

  static Uri userFavoritesUrl(String username, {int? page}) =>
      Uri.parse(favorites(username, page: page));

  static String journals(String username) => '$baseUrl/journals/$username/';
  static Uri userJournalsUrl(String username) => Uri.parse(journals(username));

  static String journal(String id) => '$baseUrl/journal/$id/';
  static Uri journalUrl(String id) => Uri.parse(journal(id));

  static String watchlist(String username, String direction, {int? page}) {
    final p = (page != null && page > 1) ? '?page=$page' : '';
    return '$baseUrl/watchlist/$direction/$username/$p';
  }

  static String get notesInbox => '$baseUrl/controls/switchbox/inbox/';
  static String get notesSent => '$baseUrl/controls/switchbox/sent/';
  static String newNote(String username) => '$baseUrl/newpm/$username/';

  static const Map<String, String> filterMap = {
    'all': '',
    'digital': '1',
    'traditional': '2',
    'writing': '3',
  };
}
