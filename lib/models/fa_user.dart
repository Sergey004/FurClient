import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:fa_kit/fa_kit.dart' as fa;

class FAProfileShout {
  final int cid;
  final String author;
  final String displayAuthor;
  final String avatarUrl;
  final String naturalDatetime;
  final String htmlMessage;

  FAProfileShout({
    required this.cid,
    required this.author,
    required this.displayAuthor,
    required this.avatarUrl,
    required this.naturalDatetime,
    required this.htmlMessage,
  });
}

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

  /// Шауты (guestbook) со страницы пользователя — стена комментариев.
  final List<FAProfileShout> shouts;

  FAUser({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.description,
    required this.stats,
    required this.isWatching,
    required this.watchUrl,
    this.shouts = const [],
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
            : FAUserStats(
                views: 0,
                submissions: 0,
                favorites: 0,
                comments: 0,
                journals: 0),
        isWatching: json['isWatching'] as bool? ?? false,
        watchUrl: json['watchUrl'] as String? ?? '',
      );

  static FAUser? parseUserPage(String htmlString, String username) {
    final document = html_parser.parse(htmlString);
    final mainWindow = document.querySelector('body div#main-window');
    final navHeader =
        mainWindow?.querySelector('div#site-content userpage-nav-header');
    final authorNode = navHeader?.querySelector(
        'username div.c-usernameBlock a.c-usernameBlock__displayName');

    final displayName = _extractDisplayName(document, username, authorNode);

    // Avatar — look for img with alt="Avatar" or inside avatar container
    final avatarEl = document.querySelector('img[alt="Avatar"]');
    final avatarUrl =
        avatarEl?.attributes['src'] ?? fa.FAURLs.avatarUrl(username) ?? '';

    // Banner — user-banner div > img
    final bannerEl = mainWindow?.querySelector('div#header a img') ??
        document.querySelector('div.user-banner img, .banner img');
    final bannerUrl = bannerEl?.attributes['src'] ?? '';

    // Description
    const descriptionQuery =
        'div#site-content div#page-userpage section.userpage-layout-profile div.userpage-layout-profile-container div.userpage-profile';
    final descEl = mainWindow?.querySelector(descriptionQuery) ??
        document.querySelector(
            'div.user-description, .profile-description, #user-description');
    final description = descEl?.text.trim() ?? '';

    // Stats — FA uses: <span class="highlight">Views:</span> 3515
    // inside div.section-body > div.table > div.cell. В бета-теме лейблы
    // рвутся адаптивными спанами (Comments/Cmts), поэтому ищем по хвостовому
    // слову лейбла в тексте без тегов — см. [_parseHighlightValue].
    final views = _parseHighlightValue(document, 'Views:');
    final submissions = _parseHighlightValue(document, 'Submissions:');
    final favorites = _parseHighlightValue(document, 'Favs:');
    // FA has "Comments Earned" and "Comments Made" — use Earned as the main count
    final comments = _parseHighlightValue(document, 'Earned:');
    final journals = _parseHighlightValue(document, 'Journals:');

    // Watch button
    final watchButton = document.querySelector('a[href*="/unwatch/"]') ??
        document.querySelector('a[href*="/watch/"]');
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
      watchUrl:
          watchHref.isNotEmpty ? 'https://www.furaffinity.net$watchHref' : '',
    );
  }

  static String _extractDisplayName(
      dom.Document document, String username, dom.Element? authorNode) {
    final authorText = authorNode?.text.trim();
    if (authorText != null && authorText.isNotEmpty) {
      final normalized = authorText.toLowerCase();
      if (normalized != 'browse') {
        return authorText;
      }
    }

    final selectors = [
      'h2.username',
      '.username',
      'h2[class*="username"]',
      'div.user-profile h2',
      'div.user-info h2',
      'div#user-profile h2',
      '.user-profile h2',
      '.user-info h2',
      '.profile h2',
      '.user-page h2',
      'h2',
    ];

    for (final selector in selectors) {
      final element = document.querySelector(selector);
      if (element == null) continue;

      final text = element.text.trim();
      if (text.isEmpty) continue;
      if (text.toLowerCase() == 'browse') continue;

      return text;
    }

    return username;
  }

  /// Parse a stat value from the FA profile stats block.
  ///
  /// Бета-тема рвёт лейблы адаптивными спанами
  /// (`<span class="hideonmobile">Comments</span> <span>Cmts</span> Earned:`),
  /// поэтому регулярка по сырой HTML с фиксированным лейблом не матчится.
  /// Вычищаем теги из текста секции и ищем [label] — хвостовое слово
  /// лейбла с двоеточием — по чистому тексту.
  static int _parseHighlightValue(dom.Document document, String label) {
    // На странице несколько div.section-body (контакт-инфо, stats, ...)
    // — ищем в каждом, затем по всему документу.
    for (final section in document.querySelectorAll('div.section-body')) {
      final text =
          section.outerHtml.replaceAll(RegExp(r'<[^>]+>'), ' ');
      final match =
          RegExp('${RegExp.escape(label)}\\s*([\\d,]+)').firstMatch(text);
      if (match != null) {
        return int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
      }
    }
    final docText =
        document.outerHtml.replaceAll(RegExp(r'<[^>]+>'), ' ');
    final match =
        RegExp('${RegExp.escape(label)}\\s*([\\d,]+)').firstMatch(docText);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!.replaceAll(',', '')) ?? 0;
  }
}
