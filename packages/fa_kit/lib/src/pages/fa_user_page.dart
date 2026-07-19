import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'fa_page.dart';

/// Watch data from a user profile.
class FAWatchData {
  final Uri watchUrl;

  FAWatchData({required this.watchUrl});

  /// Whether the current user is watching this user.
  bool get watching => watchUrl.path.contains('/unwatch/');
}

/// Parsed user profile page.
class FAUserPage implements FAPage {
  final String name;
  final String displayName;
  final Uri? bannerUrl;
  final String htmlDescription;
  final List<FAPageComment> shouts;
  final int? targetShoutId;
  final FAWatchData? watchData;

  FAUserPage({
    required this.name,
    required this.displayName,
    this.bannerUrl,
    required this.htmlDescription,
    required this.shouts,
    this.targetShoutId,
    this.watchData,
  });

  /// Parse the user profile page HTML.
  static FAUserPage parse(String html, Uri url) {
    final document = parser.parse(html);

    // Username from URL
    final nameMatch = RegExp(r'/user/([^/]+)/').firstMatch(url.path);
    final name = nameMatch?.group(1) ?? '';

    final mainWindow = document.querySelector('body div#main-window');
    final navHeader =
        mainWindow?.querySelector('div#site-content userpage-nav-header');

    // Display name
    final authorNode = navHeader?.querySelector(
        'username div.c-usernameBlock a.c-usernameBlock__displayName');
    final displayName = _extractDisplayName(document, name, authorNode);

    // Banner
    Uri? bannerUrl;
    final bannerEl = mainWindow?.querySelector('div#header a img') ??
        document.querySelector('div.user-banner img, .banner img');
    if (bannerEl != null) {
      final src = bannerEl.attributes['src'] ?? '';
      if (src.isNotEmpty) {
        bannerUrl = Uri.parse(
            src.startsWith('http') ? src : 'https://www.furaffinity.net$src');
      }
    }

    // Description
    const descriptionQuery =
        'div#site-content div#page-userpage section.userpage-layout-profile div.userpage-layout-profile-container div.userpage-profile';
    final descEl = mainWindow?.querySelector(descriptionQuery) ??
        document.querySelector(
            'div.user-description, .profile-description, #user-description');
    final htmlDescription = descEl?.innerHtml ?? '';

    // Shouts (guestbook comments)
    final shouts = <FAPageComment>[];
    const shoutsQuery =
        'div#site-content div#page-userpage section.userpage-right-column div.userpage-section-right div.comment_container';
    final shoutElements = mainWindow?.querySelectorAll(shoutsQuery) ??
        document.querySelectorAll('div.shout-container, div.comment, .shout');

    for (final shoutEl in shoutElements) {
      try {
        final cidMatch = RegExp(r'cid=(\d+)').firstMatch(shoutEl.outerHtml);
        final cid = int.tryParse(cidMatch?.group(1) ?? '') ?? 0;
        if (cid == 0) continue;

        final indentEl =
            shoutEl.querySelector('.comment-indentation, .comment-avatar');
        int indentation = 0;
        if (indentEl != null) {
          final widthAttr = indentEl.attributes['width'] ?? '0';
          indentation = (double.tryParse(widthAttr) ?? 0).toInt() ~/ 16;
        }

        final authorLink =
            shoutEl.querySelector('a.comment-username, a[href*="/user/"]');
        final author = authorLink != null
            ? (RegExp(r'/user/([^/]+)/')
                    .firstMatch(authorLink.attributes['href'] ?? '')
                    ?.group(1) ??
                '')
            : '';
        final displayAuthor = authorLink?.text.trim() ?? '';

        final dateEl = shoutEl.querySelector('span.popup_date, span.date');
        final naturalDatetime = dateEl?.text.trim() ?? '';
        final datetimeAttr = dateEl?.attributes['title'] ?? '';
        final datetime = DateTime.tryParse(datetimeAttr) ?? DateTime.now();

        final messageEl =
            shoutEl.querySelector('div.comment-text, .shout-text');
        final htmlMessage = messageEl?.innerHtml ?? '';

        shouts.add(FAVisiblePageComment(
          cid: cid,
          indentation: indentation,
          author: author,
          displayAuthor: displayAuthor,
          datetime: datetime,
          naturalDatetime: naturalDatetime,
          htmlMessage: htmlMessage,
        ));
      } catch (_) {
        // Skip
      }
    }

    // Target shout from URL
    int? targetShoutId;
    final hashMatch = RegExp(r'shout-(\d+)').firstMatch(url.fragment);
    if (hashMatch != null) {
      targetShoutId = int.tryParse(hashMatch.group(1)!);
    }

    // Watch data
    FAWatchData? watchData;
    final watchLink =
        navHeader?.querySelector('userpage-nav-interface-buttons a.button') ??
            document.querySelector('a[href*="/watch/"], a[href*="/unwatch/"]');
    final href = watchLink?.attributes['href'] ?? '';
    if (href.isNotEmpty) {
      watchData = FAWatchData(
        watchUrl: Uri.parse(href.startsWith('http')
            ? href
            : 'https://www.furaffinity.net$href'),
      );
    }

    return FAUserPage(
      name: name,
      displayName: displayName,
      bannerUrl: bannerUrl,
      htmlDescription: htmlDescription,
      shouts: shouts,
      targetShoutId: targetShoutId,
      watchData: watchData,
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
}
