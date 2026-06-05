import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

import '../services/fa_urls.dart';

/// Strips commas, spaces and NBSP from a number string, then parses it.
/// FA renders numbers like "12,345" or "1&nbsp;234" which int.parse can't handle.
int _parseInt(String raw) {
  final cleaned = raw
      .replaceAll(',', '')
      .replaceAll(' ', '')
      .replaceAll('\u00A0', '')
      .trim();
  return int.tryParse(cleaned) ?? 0;
}

class Submission {
  final String id;
  final String title;
  final String author;
  final String category;
  final String imageUrl;
  final int views;
  final int faves;
  final int commentsCount;
  final String description;
  final List<String> tags;
  final String date;
  final bool isNsfw;
  final String rating; // 'general', 'mature', 'adult'
  final String url;
  final bool isFavorite;
  final String favoriteUrl;

  String get thumbnailUrl => imageUrl;
  String get fullImageUrl => imageUrl;
  String get authorAvatar => FAUrls.avatar(author);

  Submission({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.imageUrl,
    required this.views,
    required this.faves,
    required this.commentsCount,
    required this.description,
    required this.tags,
    required this.date,
    required this.isNsfw,
    this.rating = 'general',
    required this.url,
    this.isFavorite = false,
    this.favoriteUrl = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'category': category,
        'imageUrl': imageUrl,
        'views': views,
        'faves': faves,
        'commentsCount': commentsCount,
        'description': description,
        'tags': tags,
        'date': date,
        'isNsfw': isNsfw,
        'rating': rating,
        'url': url,
        'isFavorite': isFavorite,
        'favoriteUrl': favoriteUrl,
      };

  factory Submission.fromJson(Map<String, dynamic> json) => Submission(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        category: json['category'] as String? ?? 'Digital',
        imageUrl: json['imageUrl'] as String? ?? '',
        views: json['views'] as int? ?? 0,
        faves: json['faves'] as int? ?? 0,
        commentsCount: json['commentsCount'] as int? ?? 0,
        description: json['description'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        date: json['date'] as String? ?? '',
        isNsfw: json['isNsfw'] as bool? ?? false,
        rating: json['rating'] as String? ?? 'general',
        url: json['url'] as String? ?? '',
        isFavorite: json['isFavorite'] as bool? ?? false,
        favoriteUrl: json['favoriteUrl'] as String? ?? '',
      );

  static List<Submission> parseSubmissionsPage(String htmlString) {
    final document = html_parser.parse(htmlString);
    final submissions = <Submission>[];

    // iOS селектор из FASubmissionsPage.swift и FAUserGalleryLikePage.swift:
    // figure[id^="sid-"] внутри section.gallery-section или messagecenter
    final figures = document.querySelectorAll('figure[id^="sid-"]');

    for (final fig in figures) {
      final id = fig.id.replaceFirst('sid-', '');
      if (id.isEmpty) continue;

      // iOS: figure b u a img
      final img = fig.querySelector('b u a img') ?? fig.querySelector('img');
      var imageUrl = img?.attributes['src'] ?? '';
      if (imageUrl.startsWith('//')) imageUrl = 'https:$imageUrl';

      // iOS: figcaption p a — первый = title, второй = author
      final captionLinks = fig.querySelectorAll('figcaption p a');
      final title = captionLinks.isNotEmpty
          ? captionLinks[0].text.trim()
          : fig.attributes['title'] ?? 'Untitled';

      String author = 'Unknown';
      if (captionLinks.length >= 2) {
        final authorHref = captionLinks[1].attributes['href'] ?? '';
        final authorMatch = RegExp(r'/user/([^/]+)/').firstMatch(authorHref);
        author = authorMatch?.group(1) ?? captionLinks[1].text.trim();
      }

      final isAdult =
          fig.querySelector('[data-rating="adult"]') != null || fig.classes.contains('r-adult');
      final isMature =
          fig.querySelector('[data-rating="mature"]') != null || fig.classes.contains('r-mature');
      final isNsfw = isAdult || isMature;
      final rating = isAdult ? 'adult' : isMature ? 'mature' : 'general';

      submissions.add(Submission(
        id: id,
        title: title,
        author: author,
        category: 'Digital',
        imageUrl: imageUrl,
        views: 0,
        faves: 0,
        commentsCount: 0,
        description: '',
        tags: [],
        date: DateTime.now().toIso8601String(),
        isNsfw: isNsfw,
        rating: rating,
        url: 'https://www.furaffinity.net/view/$id/',
        isFavorite: false,
        favoriteUrl: '',
      ));
    }

    return submissions;
  }

  static Submission? parseSubmissionDetails(
      String htmlString, String submissionId) {
    final document = html_parser.parse(htmlString);

    // iOS: div.submission-area img#submissionImg — data-preview-src / data-fullview-src
    final imgEl = document.querySelector('div.submission-area img#submissionImg');
    var imageUrl = imgEl?.attributes['data-fullview-src'] ??
        imgEl?.attributes['data-preview-src'] ??
        imgEl?.attributes['src'] ??
        '';
    if (imageUrl.startsWith('//')) imageUrl = 'https:$imageUrl';

    // iOS: div.submission-title h2
    final titleEl = document.querySelector('div.submission-title h2');
    final title = titleEl?.text.trim() ?? 'Untitled';

    // iOS: span.c-usernameBlockSimple a
    final authorEl = document.querySelector('span.c-usernameBlockSimple a');
    String author = 'Unknown';
    if (authorEl != null) {
      final href = authorEl.attributes['href'] ?? '';
      final m = RegExp(r'/user/([^/]+)/').firstMatch(href);
      author = m?.group(1) ?? authorEl.text.trim();
    }

    // iOS: div.submission-description-text
    final descEl = document.querySelector('div.submission-description-text');
    final description = descEl?.text.trim() ?? '';

    // iOS: div[title="Views"] div, div[title="Favorites"] div, div[title="Comments"] div
    int views = 0, faves = 0, comments = 0;
    final viewsEl = document.querySelector('div[title="Views"] div');
    final favesEl = document.querySelector('div[title="Favorites"] div');
    final commentsEl = document.querySelector('div[title="Comments"] div');
    views = _parseInt(viewsEl?.text.trim() ?? '');
    faves = _parseInt(favesEl?.text.trim() ?? '');
    comments = _parseInt(commentsEl?.text.trim() ?? '');

    // iOS: span.tags span[data-tag-name]
    final tagEls = document.querySelectorAll('div.submission-tags div span.tags');
    final tags = tagEls
        .map((e) {
          final tagBlock = e.querySelector('[data-tag-name]');
          return tagBlock?.attributes['data-tag-name'] ?? e.text.trim();
        })
        .where((t) => t.isNotEmpty)
        .toList();

    // iOS: div[class*="c-contentRating"]
    final ratingEl = document.querySelector('[class*="c-contentRating"]');
    final ratingText = ratingEl?.text.trim() ?? '';
    final isNsfw = ratingText == 'Adult' || ratingText == 'Mature';
    final rating =
        ratingText == 'Adult' ? 'adult' : ratingText == 'Mature' ? 'mature' : 'general';

    // iOS: span.popup_date
    final dateEl = document.querySelector('span.popup_date');
    final date = dateEl?.attributes['title'] ?? dateEl?.text.trim() ?? '';

    // ── Parse favorite button: multi-strategy ──
    bool isFavorite = false;
    String favoriteUrl = '';

    // Strategy 1: Standard <a href="/fav/..."> or <a href="/unfav/..."> links
    final favLinks = document.querySelectorAll(
        'a[href*="/unfav/"], a[href*="/fav/"]');
    if (favLinks.isNotEmpty) {
      for (final link in favLinks) {
        final href = link.attributes['href'] ?? '';
        if (href.contains('/unfav/')) {
          isFavorite = true;
          favoriteUrl = href;
          break;
        } else if (href.contains('/fav/')) {
          isFavorite = false;
          favoriteUrl = href;
          break;
        }
      }
    }

    // Strategy 2: Form action (FA may use <form action="/fav/ID/">)
    if (favoriteUrl.isEmpty) {
      final favForms = document.querySelectorAll('form[action*="/fav/"], form[action*="/unfav/"]');
      if (favForms.isNotEmpty) {
        final action = favForms.first.attributes['action'] ?? '';
        if (action.contains('/unfav/')) {
          isFavorite = true;
          favoriteUrl = action;
        } else if (action.contains('/fav/')) {
          favoriteUrl = action;
        }
        // Look for hidden key input
        final keyInput = favForms.first.querySelector('input[name="key"]');
        if (keyInput != null && favoriteUrl.isNotEmpty) {
          final key = keyInput.attributes['value'] ?? '';
          if (key.isNotEmpty && !favoriteUrl.contains('key=')) {
            favoriteUrl += '?key=$key';
          }
        }
      }
    }

    // Strategy 3: Button data-action
    if (favoriteUrl.isEmpty) {
      final favBtns = document.querySelectorAll(
          'button[data-action="fav"], button[data-action="unfav"]');
      if (favBtns.isNotEmpty) {
        final action = favBtns.first.attributes['data-action'] ?? '';
        final sid =
            favBtns.first.attributes['data-id'] ?? submissionId;
        if (action == 'unfav') {
          isFavorite = true;
          favoriteUrl = '/unfav/$sid/';
        } else {
          favoriteUrl = '/fav/$sid/';
        }
      }
    }

    // Strategy 4: .favorite-button / .fav-button class
    if (favoriteUrl.isEmpty) {
      final favBtn =
          document.querySelector('a.favorite-button, a.fav-button, button.favorite-button');
      if (favBtn != null) {
        final href = favBtn.attributes['href'] ?? '';
        final onClick = favBtn.attributes['onclick'] ?? '';
        if (href.isNotEmpty) {
          isFavorite = href.contains('/unfav/') || href.contains('/remove/') || favBtn.classes.contains('active');
          favoriteUrl = href;
        } else if (onClick.isNotEmpty) {
          // Extract URL from onclick like: location.href='/fav/123456/'
          final onClickMatch = RegExp(r'''['"](/(?:un)?fav/\d+/?)['"]''').firstMatch(onClick);
          if (onClickMatch != null) {
            favoriteUrl = onClickMatch.group(1)!;
            isFavorite = favoriteUrl.contains('/unfav/');
          }
        }
      }
    }

    // Strategy 5: Last resort — construct URL from submission ID
    if (favoriteUrl.isEmpty && submissionId.isNotEmpty) {
      debugPrint('=== parseSubmissionDetails: no fav link found, constructing fallback URL');
      favoriteUrl = '/fav/$submissionId/';
    }

    debugPrint(
        '=== parseSubmissionDetails: favUrl=$favoriteUrl isFavorite=$isFavorite');

    return Submission(
      id: submissionId,
      title: title,
      author: author,
      category: 'Digital',
      imageUrl: imageUrl,
      views: views,
      faves: faves,
      commentsCount: comments,
      description: description,
      tags: tags,
      date: date,
      isNsfw: isNsfw,
      rating: rating,
      url: 'https://www.furaffinity.net/view/$submissionId/',
      isFavorite: isFavorite,
      favoriteUrl: favoriteUrl,
    );
  }

  static List<Submission> parseSearchResults(String htmlString) {
    return parseSubmissionsPage(htmlString);
  }
}
