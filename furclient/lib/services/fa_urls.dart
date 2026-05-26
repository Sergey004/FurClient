class FAUrls {
  static const String baseUrl = 'https://www.furaffinity.net';

  static String get home => baseUrl;
  static String get login => '$baseUrl/login';
  static String get register => '$baseUrl/register';
  static String get submissions => '$baseUrl/msg/submissions/new@72';
  static String submissionsFrom(int sid) =>
      '$baseUrl/msg/submissions/new~$sid@72';

  static String browse({String filter = 'all', int? page}) {
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
  static String search(String query, {int page = 1}) {
    final q = Uri.encodeComponent(query);
    final p = page > 1 ? '&page=$page' : '';
    return '$baseUrl/search/?q=$q$p';
  }

  static String get notifications => '$baseUrl/msg/others/';
  static String user(String username) => '$baseUrl/user/$username/';
  static String avatar(String username) =>
      'https://a.furaffinity.net/$username.gif';
  static String gallery(String username) => '$baseUrl/gallery/$username/';
  static String favorites(String username) =>
      '$baseUrl/favorites/$username/';
  static String journals(String username) => '$baseUrl/journals/$username/';
  static String journal(String id) => '$baseUrl/journal/$id/';

  static String watchlist(String username, String direction, {int? page}) {
    final p = (page != null && page > 1) ? '?page=$page' : '';
    return '$baseUrl/watchlist/$direction/$username/$p';
  }

  static String get notesInbox =>
      '$baseUrl/controls/switchbox/inbox/';
  static String get notesSent =>
      '$baseUrl/controls/switchbox/sent/';
  static String newNote(String username) => '$baseUrl/newpm/$username/';

  static const Map<String, String> filterMap = {
    'all': '',
    'digital': '1',
    'traditional': '2',
    'writing': '3',
  };
}
