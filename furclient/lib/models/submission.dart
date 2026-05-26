import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../services/fa_urls.dart';

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
  final String url;

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
    required this.url,
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
        'url': url,
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
        url: json['url'] as String? ?? '',
      );

  static List<Submission> parseSubmissionsPage(String htmlString) {
    final document = html_parser.parse(htmlString);
    final submissions = <Submission>[];

    final sidElements = document.querySelectorAll('div[id^="sid-"]');
    for (final el in sidElements) {
      final id = (el.id).replaceFirst('sid-', '');
      if (id.isEmpty) continue;

      final link = el.querySelector('a[href*="/view/"]');
      final title = link?.attributes['title'] ?? link?.text.trim() ?? 'Untitled';
      final href = link?.attributes['href'] ?? '';

      final authorLink = el.querySelector('a[href*="/user/"]');
      final author = authorLink?.text.trim() ?? 'Unknown';

      final img = el.querySelector('img[alt]');
      final imageUrl = img?.attributes['src'] ?? '';

      final statsContainer =
          el.querySelector('.stats-container') ?? el.querySelector('.grid-info');
      final statsText = statsContainer?.text ?? '';
      final viewsMatch = RegExp(r'(\d+)\s+views?', caseSensitive: false)
          .firstMatch(statsText);
      final favesMatch = RegExp(r'(\d+)\s*[♥❤]').firstMatch(statsText);

      final tagsEl = el.querySelector('.tags');
      final tagsText = tagsEl?.text ?? '';
      final tags = tagsText
          .split(',')
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();

      final isNsfw = el.querySelector('[data-rating="adult"]') != null ||
          el.querySelector('[data-rating="mature"]') != null;

      submissions.add(Submission(
        id: id,
        title: title,
        author: author,
        category: 'Digital',
        imageUrl: imageUrl,
        views: int.tryParse(viewsMatch?.group(1) ?? '0') ?? 0,
        faves: int.tryParse(favesMatch?.group(1) ?? '0') ?? 0,
        commentsCount: 0,
        description: '',
        tags: tags,
        date: DateTime.now().toIso8601String(),
        isNsfw: isNsfw,
        url: 'https://www.furaffinity.net$href',
      ));
    }

    return submissions;
  }

  static Submission? parseSubmissionDetails(String htmlString, String submissionId) {
    final document = html_parser.parse(htmlString);

    final titleEl = document.querySelector('div.information h2');
    final title = titleEl?.text.trim() ?? 'Untitled';

    final authorEl = document.querySelector('a[href*="/user/"]');
    final author = authorEl?.text.trim() ?? 'Unknown';

    final descEl = document.querySelector('div[class*="description"]');
    final description = descEl?.text.trim() ?? '';

    final imageUrl = document
            .querySelector('img[alt="Submission"]')
            ?.attributes['src'] ??
        document.querySelector('img#submissionImg')?.attributes['src'] ??
        '';

    final views = _parseDtValue(document, 'Views');
    final faves = _parseDtValue(document, 'Favorites');
    final commentsCount = _parseDtValue(document, 'Comments');

    final tagsEl = document.querySelector('section.tags');
    final tagsText = tagsEl?.text ?? '';
    final tags = tagsText
        .split(',')
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toList();

    final isNsfw =
        document.querySelector('[data-rating="adult"]') != null ||
            document.querySelector('[data-rating="mature"]') != null;

    final dateEl = _findDtSibling(document, 'Posted');
    final date = dateEl?.text.trim() ?? DateTime.now().toIso8601String();

    return Submission(
      id: submissionId,
      title: title,
      author: author,
      category: 'Digital',
      imageUrl: imageUrl,
      views: views,
      faves: faves,
      commentsCount: commentsCount,
      description: description,
      tags: tags,
      date: date,
      isNsfw: isNsfw,
      url: 'https://www.furaffinity.net/view/$submissionId/',
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

  static List<Submission> parseSearchResults(String htmlString) {
    return parseSubmissionsPage(htmlString);
  }
}
