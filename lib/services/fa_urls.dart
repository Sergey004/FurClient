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

  static String search(
    String query, {
    int page = 1,
    String sortBy = 'relevancy',
    String sortDirection = 'desc',
  }) {
    final q = Uri.encodeComponent(query);
    final parts = <String>[
      'q=$q',
      'order-by=$sortBy',
      'order-direction=$sortDirection',
      'mode=extended',
      'page=$page',
      'perpage=$searchPageSize',
    ];
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
