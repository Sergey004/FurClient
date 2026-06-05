import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'fa_comment.dart';

class FAUserStats {
  final int views;
  final int submissions;
  final int favorites;
  final int comments;
  final int journals;
  final int watchers;

  FAUserStats({
    required this.views,
    required this.submissions,
    required this.favorites,
    required this.comments,
    required this.journals,
    this.watchers = 0,
  });

  Map<String, dynamic> toJson() => {
        'views': views,
        'submissions': submissions,
        'favorites': favorites,
        'comments': comments,
        'journals': journals,
        'watchers': watchers,
      };

  factory FAUserStats.fromJson(Map<String, dynamic> json) => FAUserStats(
        views: json['views'] as int? ?? 0,
        submissions: json['submissions'] as int? ?? 0,
        favorites: json['favorites'] as int? ?? 0,
        comments: json['comments'] as int? ?? 0,
        journals: json['journals'] as int? ?? 0,
        watchers: json['watchers'] as int? ?? 0,
      );
}

/// A single commission slot from the user's profile page.
class FACommissionSlot {
  final String type;       // e.g. "Full Color", "Sketch", "Icon"
  final String price;      // e.g. "$50", "Price varies"
  final String details;    // additional info or empty

  FACommissionSlot({
    required this.type,
    required this.price,
    this.details = '',
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'price': price,
        'details': details,
      };

  factory FACommissionSlot.fromJson(Map<String, dynamic> json) => FACommissionSlot(
        type: json['type'] as String? ?? '',
        price: json['price'] as String? ?? '',
        details: json['details'] as String? ?? '',
      );
}

/// Commission information from a user's profile.
class FACommissionInfo {
  final String status;               // "Open", "Closed", "Trades Only", etc.
  final List<FACommissionSlot> slots;
  final String tosUrl;              // link to Terms of Service journal/page
  final String notes;               // free-form notes from commission section

  const FACommissionInfo({
    this.status = '',
    this.slots = const [],
    this.tosUrl = '',
    this.notes = '',
  });

  bool get isOpen => status.toLowerCase().contains('open');
  bool get hasInfo => status.isNotEmpty || slots.isNotEmpty || notes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'status': status,
        'slots': slots.map((s) => s.toJson()).toList(),
        'tosUrl': tosUrl,
        'notes': notes,
      };

  factory FACommissionInfo.fromJson(Map<String, dynamic> json) => FACommissionInfo(
        status: json['status'] as String? ?? '',
        slots: (json['slots'] as List<dynamic>?)
                ?.map((s) => FACommissionSlot.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        tosUrl: json['tosUrl'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
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
  final FACommissionInfo commissions;
  final String profileUrl;
  final List<FAComment> shouts;

  FAUser({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.description,
    required this.stats,
    required this.isWatching,
    required this.watchUrl,
    this.commissions = const FACommissionInfo(),
    this.profileUrl = '',
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
        'commissions': commissions.toJson(),
        'shouts': shouts.map((s) => s.toJson()).toList(),
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
        commissions: json['commissions'] is Map<String, dynamic>
            ? FACommissionInfo.fromJson(json['commissions'] as Map<String, dynamic>)
            : FACommissionInfo(),
      );

  /// Build the best avatar URL for a username.
  /// FA serves avatars from multiple CDN paths. We try the page-parsed URL
  /// first; if not found, construct from known CDN patterns.
  ///
  static String buildAvatarUrl(String username, {String? pageAvatarUrl}) {
    if (pageAvatarUrl != null && pageAvatarUrl.isNotEmpty) {
      return pageAvatarUrl;
    }
    // FA CDN — all avatars served as .gif (static PNG/JPEG use GIF URL too)
    return 'https://a.furaffinity.net/$username.gif';
  }

  /// Parse user profile page HTML.
  /// Uses FAKit-style selectors for basic fields + multi-strategy stat parsing
  /// + commission info parsing.
  static FAUser? parseUserPage(String htmlString, String username) {
    final document = html_parser.parse(htmlString);

    // ── Display name (FAKit selectors) ───────────────────────────────
    String displayName = username;
    final nameEl =
        document.querySelector('h2.username, .username, h2');
    if (nameEl != null && nameEl.text.trim().isNotEmpty) {
      displayName = nameEl.text.trim();
    } else {
      final userLink = document.querySelector('a[href*="/user/$username/"]');
      displayName = userLink?.text.trim() ?? username;
    }

    // ── Avatar (multi-strategy) ───────────────────────────────────────
    // FA has changed avatar hosting multiple times.
    // Strategy 1: Known avatar selectors (modern + classic FA layouts)
    // Strategy 2: Look for any image near the username in profile info area
    // Strategy 3: Scan all images on the page for FA avatar CDN URLs
    // Strategy 4: Fallback to legacy a.furaffinity.net/{user}.gif
    String avatarUrl = _parseAvatar(document, username);

    // ── Banner (FAKit selectors) ────────────────────────────────────────
    String bannerUrl = '';
    for (final sel in [
      'div.user-banner img',
      '.banner img',
      'div[class*="banner"] img',
    ]) {
      final el = document.querySelector(sel);
      if (el != null) {
        bannerUrl = _resolveUrl(el.attributes['src'] ?? '');
        if (bannerUrl.isNotEmpty) break;
      }
    }

    // ── Description (FAKit selectors) ─────────────────────────────────
    String description = '';
    for (final sel in [
      'div.user-description',
      '.profile-description',
      '#user-description',
      'div[class*="description"]',
    ]) {
      final el = document.querySelector(sel);
      if (el != null) {
        description = el.text.trim();
        if (description.isNotEmpty) break;
      }
    }

    // ── Stats (multi-strategy) ────────────────────────────────────────
    final views = _parseStat(document, 'Views');
    final submissions = _parseStat(document, 'Submissions');
    final favorites = _parseStat(document, 'Favorites');
    final comments = _parseStat(document, 'Comments Received');
    final journals = _parseStat(document, 'Journals');
    final watchers = _parseStat(document, 'Watchers');

    // ── Watch button ──────────────────────────────────────────────────
    final watchButton = document.querySelector(
        'a[href*="/watch/"], a[href*="/unwatch/"]');
    final watchHref = watchButton?.attributes['href'] ?? '';
    final isWatching = watchHref.contains('/unwatch/');

    // ── Commission info ─────────────────────────────────────────────
    final commissions = _parseCommissions(document);

    // ── Shouts (profile comments) ──────────────────────────────────
    final shouts = _parseShouts(document, htmlString);

    debugPrint('=== parseUserPage: user=$username, display=$displayName');
    debugPrint('=== parseUserPage: avatar=$avatarUrl');
    debugPrint('=== parseUserPage: banner=${bannerUrl.isNotEmpty}');
    debugPrint('=== parseUserPage: desc=${description.length} chars');
    debugPrint(
        '=== parseUserPage: stats: V=$views S=$submissions F=$favorites C=$comments J=$journals W=$watchers');
    debugPrint('=== parseUserPage: watching=$isWatching');
    debugPrint('=== parseUserPage: commissions.status=${commissions.status}, slots=${commissions.slots.length}');
    debugPrint('=== parseUserPage: shouts=${shouts.length}');

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
        watchers: watchers,
      ),
      isWatching: isWatching,
      watchUrl: watchHref.isNotEmpty
          ? 'https://www.furaffinity.net$watchHref'
          : '',
      commissions: commissions,
      profileUrl: 'https://www.furaffinity.net/user/$username/',
      shouts: shouts,
    );
  }

  // ── Avatar Parsing ────────────────────────────────────────────────────

  /// Parse avatar URL from user profile HTML.
  ///
  /// FA user pages contain MANY avatar images (shouts/guestbook comments at
  /// the bottom each have their own avatar). We must ONLY look in the profile
  /// header area, never in the shouts section.
  ///
  /// Strategy 1: Specific profile-header selectors
  /// Strategy 2: Find img with username in its URL path (FA CDN pattern)
  /// Strategy 3: Profile area images (excluding shout containers)
  /// Fallback: Constructed CDN URL (always works)
  static String _parseAvatar(dom.Document document, String username) {
    // ── Remove shout/comment sections so they can't interfere ──
    // FA uses div.comment-container, div.shout-container, section.comment-area
    document.querySelectorAll(
      'div.comment-container, div.shout-container, '
      'section.comment-area, div.shouts, #shouts, '
      'div[class*="comment-list"], div[class*="shout-list"]'
    ).forEach((el) => el.remove());

    // ── Strategy 1: Known profile-header avatar selectors ──
    const avatarSelectors = [
      'img[alt="Avatar"]',
      'img.user-avatar',
      'img.avatar',
      'section.profile-user-info img',
      'div.profile-user-info img',
      'td.avatar img',
      'div.userpage-avatar img',
      'img[class*="avatar"]',
    ];

    for (final sel in avatarSelectors) {
      final el = document.querySelector(sel);
      if (el != null) {
        final src = _resolveUrl(el.attributes['src'] ?? '');
        if (src.isNotEmpty && _isAvatarLike(src)) {
          return src;
        }
      }
    }

    // ── Strategy 2: Find img whose URL contains the username ──
    // FA CDN avatar URLs contain the username:
    //   a.furaffinity.net/20250102/username.gif
    //   a.furaffinity.net/username.gif
    final allImgs = document.querySelectorAll('img');
    for (final img in allImgs) {
      final src = _resolveUrl(img.attributes['src'] ?? '');
      if (src.isNotEmpty &&
          src.toLowerCase().contains('/$username') &&
          !src.contains('ref=') &&
          !_isBannerImage(img)) {
        return src;
      }
    }

    // ── Strategy 3: First CDN image in profile area ──
    final profileAreas = document.querySelectorAll(
      'div[class*="profile"], '
      'section[class*="profile"], '
      'table.user-page-table, '
      'table[class*="user"]'
    );
    for (final area in profileAreas) {
      final imgs = area.querySelectorAll('img');
      for (final img in imgs) {
        final src = _resolveUrl(img.attributes['src'] ?? '');
        if (src.isNotEmpty && _isAvatarLike(src) && !_isBannerImage(img)) {
          return src;
        }
      }
    }

    // ── Fallback: Constructed CDN URL ──
    debugPrint('=== parseUserPage: avatar fallback to GIF for $username');
    return 'https://a.furaffinity.net/$username.gif';
  }

  /// Check if a URL looks like a user avatar (FA CDN domains).
  static bool _isAvatarLike(String url) {
    return url.contains('a.furaffinity.net') ||
        url.contains('t.furaffinity.net') ||
        url.contains('d.furaffinity.net');
  }

  /// Check if an image element is a banner (large, inside a banner container).
  static bool _isBannerImage(dom.Element img) {
    // If the image or its parent is a banner container, skip it
    if (img.classes.contains('banner') ||
        img.classes.contains('user-banner')) {
      return true;
    }
    final parent = img.parent;
    if (parent != null &&
        (parent.classes.contains('banner') ||
            parent.classes.contains('user-banner'))) {
      return true;
    }
    // Banner images are typically very wide — check for large dimensions
    final w = int.tryParse(img.attributes['width'] ?? '') ?? 0;
    final h = int.tryParse(img.attributes['height'] ?? '') ?? 0;
    // Avatars are roughly square; banners are wide
    if (w > 0 && h > 0 && (w / h) > 3) {
      return true;
    }
    return false;
  }

  /// Resolve a potentially relative URL to an absolute FA URL.
  static String _resolveUrl(String src) {
    if (src.isEmpty) return '';
    if (src.startsWith('//')) return 'https:$src';
    if (src.startsWith('http')) return src;
    if (src.startsWith('/')) return 'https://www.furaffinity.net$src';
    return src;
  }

  // ── Commission Parsing ────────────────────────────────────────────────

  /// Parse commission information from user profile page.
  /// FA user pages typically have a commission section with:
  /// - Status (Open / Closed / Trades Only / etc.)
  /// - Slots table (type, price, details)
  /// - Link to Terms of Service
  static FACommissionInfo _parseCommissions(dom.Document document) {
    String status = '';
    final slots = <FACommissionSlot>[];
    String tosUrl = '';
    String notes = '';

    // ── Find the commission section ──
    // FA may use several container patterns for commission info
    dom.Element? commissionSection;
    for (final sel in [
      // Modern FA: section with id or class
      '#commission-info',
      'section.commission',
      'div.commission-info',
      'div[class*="commission"]',
      // Classic FA: table-based layout — look for heading
    ]) {
      commissionSection = document.querySelector(sel);
      if (commissionSection != null) break;
    }

    // Fallback: find any heading containing "commission" and grab its parent section
    if (commissionSection == null) {
      final headings = document.querySelectorAll('h2, h3, h4, dt, th');
      for (final h in headings) {
        final text = h.text.toLowerCase();
        if (text.contains('commission')) {
          // Walk up to find a container div/section/table
          dom.Element? container = h.parent;
          while (container != null) {
            final tag = container.localName;
            if (tag == 'div' || tag == 'section' || tag == 'table' || tag == 'tbody') {
              commissionSection = container;
              break;
            }
            container = container.parent;
          }
          break;
        }
      }
    }

    if (commissionSection == null) {
      return const FACommissionInfo();
    }

    // ── Parse commission status ──
    // Status is usually the first text or a highlighted element
    final sectionText = commissionSection.text.toLowerCase();
    if (sectionText.contains('closed') && !sectionText.contains('not closed')) {
      status = 'Closed';
    } else if (sectionText.contains('open')) {
      status = 'Open';
    } else if (sectionText.contains('trade')) {
      status = 'Trades Only';
    } else if (sectionText.contains('semi-open')) {
      status = 'Semi-Open';
    } else if (sectionText.contains('full') || sectionText.contains('waitlist')) {
      status = 'Full';
    }

    // Also check for explicit status elements
    for (final sel in [
      '.commission-status',
      'span.commission-status',
      'div.commission-status',
      '.status',
    ]) {
      final statusEl = commissionSection.querySelector(sel);
      if (statusEl != null && statusEl.text.trim().isNotEmpty) {
        status = statusEl.text.trim();
        break;
      }
    }

    // ── Parse commission slots table ──
    // FA typically uses a table for commission types/prices
    // <table> with rows like: Type | Price | Description
    final tables = commissionSection.querySelectorAll('table');
    for (final table in tables) {
      final rows = table.querySelectorAll('tr');
      for (int i = 1; i < rows.length; i++) {
        // Skip header row (i=0)
        final cells = rows[i].querySelectorAll('td, th');
        if (cells.length < 2) continue;

        final type = cells[0].text.trim();
        final price = cells.length > 1 ? cells[1].text.trim() : '';
        final details = cells.length > 2 ? cells[2].text.trim() : '';

        if (type.isNotEmpty) {
          slots.add(FACommissionSlot(
            type: type,
            price: price,
            details: details,
          ));
        }
      }
      if (slots.isNotEmpty) break; // Use first table with data
    }

    // Also try list-based commission info (<ul>/<li>)
    if (slots.isEmpty) {
      final listItems = commissionSection.querySelectorAll('li, dd');
      for (final li in listItems) {
        final text = li.text.trim();
        // Pattern: "Type - $Price" or "Type: $Price"
        final dashMatch = RegExp(r'^(.+?)\s*[-–—]\s*(?:\$?)\s*(.+)$').firstMatch(text);
        final colonMatch = RegExp(r'^(.+?)\s*:\s*(?:\$?)\s*(.+)$').firstMatch(text);
        final match = dashMatch ?? colonMatch;
        if (match != null) {
          slots.add(FACommissionSlot(
            type: match.group(1)!.trim(),
            price: match.group(2)!.trim(),
          ));
        }
      }
    }

    // ── Parse TOS link ──
    for (final a in commissionSection.querySelectorAll('a')) {
      final href = a.attributes['href'] ?? '';
      final text = a.text.toLowerCase();
      if (text.contains('tos') ||
          text.contains('terms') ||
          text.contains('terms of service') ||
          href.contains('tos') ||
          href.contains('terms')) {
        tosUrl = _resolveUrl(href);
        break;
      }
    }

    // ── Notes: grab remaining text that isn't status/slots ──
    // Remove tables from the section text to get pure notes
    final clone = commissionSection.clone(true);
    for (final t in clone.querySelectorAll('table')) {
      t.remove();
    }
    notes = clone.text.trim();
    // Remove status text from notes
    if (status.isNotEmpty) {
      notes = notes.replaceAll(RegExp(RegExp.escape(status), caseSensitive: false), '');
    }
    notes = notes.replaceAll(RegExp(r'\s+'), ' ').trim();

    debugPrint(
        '=== parseCommissions: status=$status, slots=${slots.length}, tos=$tosUrl, notes=${notes.length}');

    return FACommissionInfo(
      status: status,
      slots: slots,
      tosUrl: tosUrl,
      notes: notes,
    );
  }

  // ── Stat Parsing ─────────────────────────────────────────────────────

  /// Parse a stat value using multiple strategies.
  static int _parseStat(dom.Document document, String label) {
    final result1 = _parseDtStat(document, label);
    if (result1 > 0) return result1;

    final result2 = _parseTdStat(document, label);
    if (result2 > 0) return result2;

    final result3 = _parseRegexStat(document, label);
    if (result3 > 0) return result3;

    return 0;
  }

  /// Strategy 1: `<dt>Label</dt><dd>Value</dd>` pairs.
  static int _parseDtStat(dom.Document document, String label) {
    final dts = document.querySelectorAll('dt');
    for (final dt in dts) {
      final text = dt.text.trim();
      if (text == label ||
          text.startsWith(label) ||
          text.contains(label)) {
        final next = dt.nextElementSibling;
        if (next != null && next.localName == 'dd') {
          final val = _parseInt(next.text);
          if (val > 0) return val;
        }
      }
    }
    return 0;
  }

  /// Strategy 2: table cells — `<td>Views:</td><td>12,345</td>`.
  static int _parseTdStat(dom.Document document, String label) {
    final cells = document.querySelectorAll('td');
    for (int i = 0; i < cells.length - 1; i++) {
      final text = cells[i].text.trim();
      if (text.startsWith(label) || text.contains(label)) {
        final val = _parseInt(cells[i + 1].text);
        if (val > 0) return val;
      }
    }
    return 0;
  }

  /// Strategy 3: Regex on full body text — "Views: 12,345" or "Views 12,345".
  static int _parseRegexStat(dom.Document document, String label) {
    final bodyText = document.body?.text ?? '';
    final escaped = RegExp.escape(label);
    final pattern = RegExp(
      '$escaped[\\s:]*([\\d][\\d,]*)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(bodyText);
    if (match != null) {
      return _parseInt(match.group(1) ?? '');
    }
    return 0;
  }

  /// Parse an integer from text, stripping commas, spaces and NBSP.
  static int _parseInt(String text) {
    final cleaned = text.trim()
        .replaceAll(',', '')
        .replaceAll(' ', '')
        .replaceAll('\u00A0', '');
    return int.tryParse(cleaned) ?? 0;
  }

  // ── Shouts Parsing ───────────────────────────────────────────────────

  /// Parse shouts (profile comments) from user profile page HTML.
  /// FAKit selectors: div.shout-container, div.comment, .shout
  /// Shouts are flat (no threading), so we use indentLevel = 0 for all.
  static List<FAComment> _parseShouts(dom.Document document, String htmlString) {
    final shouts = <FAComment>[];

    // Find the shouts section — try multiple selectors
    dom.Element? shoutsSection;
    for (final sel in [
      '#shouts',
      'div.shouts',
      'section.shouts',
      'div.shout-container',
      '.shout-section',
      'div[class*="shout"]',
    ]) {
      shoutsSection = document.querySelector(sel);
      if (shoutsSection != null) break;
    }

    if (shoutsSection == null) {
      // Fallback: find heading with "shout" and grab parent section
      final headings = document.querySelectorAll('h2, h3, h4');
      for (final h in headings) {
        if (h.text.toLowerCase().contains('shout') ||
            h.text.toLowerCase().contains('comment')) {
          dom.Element? container = h.parent;
          while (container != null) {
            final tag = container.localName;
            if (tag == 'div' || tag == 'section') {
              shoutsSection = container;
              break;
            }
            container = container.parent;
          }
          break;
        }
      }
    }

    if (shoutsSection == null) return shouts;

    // Find individual shout elements
    final shoutElements = shoutsSection.querySelectorAll(
      'div.comment-container, '
      'div.shout-container, '
      'div.comment, '
      'li.comment, '
      '.shout',
    );

    for (final el in shoutElements) {
      try {
        // Skip hidden comments
        if (el.querySelector('.comment-hidden, .hidden-comment') != null) {
          continue;
        }

        // cid from outerHtml
        final cidMatch = RegExp(r'cid[=-](\d+)').firstMatch(el.outerHtml);
        final cid = int.tryParse(cidMatch?.group(1) ?? '') ?? 0;

        // Author
        String author = '';
        final authorLink = el.querySelector(
            'a.comment-username, a.link-username, a[href*="/user/"]');
        if (authorLink != null) {
          author = RegExp(r'/user/([^/?#]+)/')
                  .firstMatch(authorLink.attributes['href'] ?? '')
                  ?.group(1) ??
              authorLink.text.trim();
        }

        // Avatar
        final avatarImg = el.querySelector(
            '.comment-avatar img, .comment-avatar-col img, td.avatar img') ??
            el.querySelector('img.avatar, img[class*="avatar"]');
        final avatarUrl = _resolveUrl(avatarImg?.attributes['src'] ?? '');

        // Date
        final dateEl = el.querySelector(
            'span.comment-date, span.popup_date, span.posted_date, '
            'span.date, time');
        final time = dateEl?.attributes['title'] ??
            dateEl?.attributes['datetime'] ??
            dateEl?.text.trim() ??
            '';

        // Text
        String text = '';
        final messageEl = el.querySelector(
            'div.comment-text, div.comment_message, div.comment-content, '
            'div.comment-body, .shout-text');
        if (messageEl != null) {
          text = messageEl.text.trim();
        }
        if (text.isEmpty) {
          text = el.text.trim();
          // Remove author and date from the raw text
          if (author.isNotEmpty) {
            text = text.replaceAll(author, '');
          }
          if (time.isNotEmpty) {
            text = text.replaceAll(time, '');
          }
          text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        }

        if (text.isNotEmpty || cid > 0) {
          shouts.add(FAComment(
            id: cid > 0 ? '$cid' : '',
            author: author.isNotEmpty ? author : 'Anonymous',
            avatarUrl: avatarUrl,
            text: text,
            time: time,
            indentLevel: 0, // Shouts are always flat
          ));
        }
      } catch (e) {
        debugPrint('=== parseShouts skip: $e');
      }
    }

    return shouts;
  }
}
