import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

class FAUserStats {
  final int views;
  final int submissions;
  final int favorites;
  final int comments;
  final int journals;

  FAUserStats({
    required this.views,
    required this.submissions,
    required this.favorites,
    required this.comments,
    required this.journals,
  });

  Map<String, dynamic> toJson() => {
        'views': views,
        'submissions': submissions,
        'favorites': favorites,
        'comments': comments,
        'journals': journals,
      };

  factory FAUserStats.fromJson(Map<String, dynamic> json) => FAUserStats(
        views: json['views'] as int? ?? 0,
        submissions: json['submissions'] as int? ?? 0,
        favorites: json['favorites'] as int? ?? 0,
        comments: json['comments'] as int? ?? 0,
        journals: json['journals'] as int? ?? 0,
      );
}

class FAUser {
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bannerUrl;
  final String description;
  final FAUserStats stats;
  final bool isWatching;
  final String watchUrl;

  FAUser({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.description,
    required this.stats,
    required this.isWatching,
    required this.watchUrl,
  });

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'bannerUrl': bannerUrl,
        'description': description,
        'stats': stats.toJson(),
        'isWatching': isWatching,
        'watchUrl': watchUrl,
      };

  factory FAUser.fromJson(Map<String, dynamic> json) => FAUser(
        username: json['username'] as String,
        displayName: json['displayName'] as String,
        avatarUrl: json['avatarUrl'] as String? ?? '',
        bannerUrl: json['bannerUrl'] as String? ?? '',
        description: json['description'] as String? ?? '',
        stats: json['stats'] is Map<String, dynamic>
            ? FAUserStats.fromJson(json['stats'] as Map<String, dynamic>)
            : FAUserStats(views: 0, submissions: 0, favorites: 0, comments: 0, journals: 0),
        isWatching: json['isWatching'] as bool? ?? false,
        watchUrl: json['watchUrl'] as String? ?? '',
      );

  static FAUser? parseUserPage(String htmlString, String username) {
    final document = html_parser.parse(htmlString);

    final userLink = document.querySelector('a[href*="/user/$username/"]');
    final displayName = userLink?.text.trim() ?? username;

    final avatarEl = document.querySelector('img[alt="Avatar"]');
    final avatarUrl = avatarEl?.attributes['src'] ?? '';

    final bannerEl = document.querySelector('div[class*="banner"] img');
    final bannerUrl = bannerEl?.attributes['src'] ?? '';

    final descEl = document.querySelector('div[class*="description"]');
    final description = descEl?.text.trim() ?? '';

    final views = _parseDtValue(document, 'Views');
    final submissions = _parseDtValue(document, 'Submissions');
    final favorites = _parseDtValue(document, 'Favorites');
    final comments = _parseDtValue(document, 'Comments');
    final journals = _parseDtValue(document, 'Journals');

    final watchButton =
        document.querySelector('a[href*="/watch/"]') ??
            document.querySelector('a[href*="/unwatch/"]');
    final watchHref = watchButton?.attributes['href'] ?? '';
    final isWatching = watchHref.contains('/unwatch/');

    return FAUser(
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
      description: description,
      stats: FAUserStats(
        views: views,
        submissions: submissions,
        favorites: favorites,
        comments: comments,
        journals: journals,
      ),
      isWatching: isWatching,
      watchUrl: watchHref.isNotEmpty
          ? 'https://www.furaffinity.net$watchHref'
          : '',
    );
  }

  static int _parseDtValue(dom.Document document, String label) {
    final dd = _findDtSibling(document, label);
    if (dd == null) return 0;
    return int.tryParse(dd.text.trim()) ?? 0;
  }

  static dom.Element? _findDtSibling(dom.Document document, String label) {
    final dts = document.querySelectorAll('dt');
    for (final dt in dts) {
      if (dt.text.trim() == label) {
        final next = dt.nextElementSibling;
        if (next != null && next.localName == 'dd') return next;
      }
    }
    return null;
  }
}
