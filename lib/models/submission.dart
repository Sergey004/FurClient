import 'package:fa_kit/fa_kit.dart' as fa;

import '../services/fa_urls.dart';

class Submission {
  final String id;
  final String title;
  final String author;
  final String displayName;
  final String category;
  final String imageUrl;
  final int views;
  final int faves;
  final int commentsCount;
  final String description;
  final List<String> tags;
  final String date;
  final DateTime? sortDate;
  final String naturalDate;
  final bool isNsfw;
  final String rating;
  final String url;
  final bool isFlash;
  final String flashUrl;
  final bool isFavorite;
  final String favoriteUrl;

  String get thumbnailUrl => imageUrl;
  String get fullImageUrl => flashUrl.isNotEmpty ? flashUrl : imageUrl;
  String get authorAvatar => FAUrls.avatar(author);

  Submission({
    required this.id,
    required this.title,
    required this.author,
    this.displayName = '',
    required this.category,
    required this.imageUrl,
    required this.views,
    required this.faves,
    required this.commentsCount,
    required this.description,
    required this.tags,
    required this.date,
    this.sortDate,
    this.naturalDate = '',
    required this.isNsfw,
    this.rating = 'general',
    required this.url,
    this.isFlash = false,
    this.flashUrl = '',
    this.isFavorite = false,
    this.favoriteUrl = '',
  });

  Submission copyWith({
    bool? isFavorite,
    int? faves,
    String? favoriteUrl,
  }) =>
      Submission(
        id: id,
        title: title,
        author: author,
        displayName: displayName,
        category: category,
        imageUrl: imageUrl,
        views: views,
        faves: faves ?? this.faves,
        commentsCount: commentsCount,
        description: description,
        tags: tags,
        date: date,
        sortDate: sortDate,
        naturalDate: naturalDate,
        isNsfw: isNsfw,
        rating: rating,
        url: url,
        isFlash: isFlash,
        flashUrl: flashUrl,
        isFavorite: isFavorite ?? this.isFavorite,
        favoriteUrl: favoriteUrl ?? this.favoriteUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'displayName': displayName,
        'category': category,
        'imageUrl': imageUrl,
        'views': views,
        'faves': faves,
        'commentsCount': commentsCount,
        'description': description,
        'tags': tags,
        'date': date,
        'sortDate': sortDate?.toIso8601String(),
        'naturalDate': naturalDate,
        'isNsfw': isNsfw,
        'rating': rating,
        'url': url,
        'isFlash': isFlash,
        'flashUrl': flashUrl,
        'isFavorite': isFavorite,
        'favoriteUrl': favoriteUrl,
      };

  factory Submission.fromJson(Map<String, dynamic> json) => Submission(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        displayName: json['displayName'] as String? ?? '',
        category: json['category'] as String? ?? 'Digital',
        imageUrl: json['imageUrl'] as String? ?? '',
        views: json['views'] as int? ?? 0,
        faves: json['faves'] as int? ?? 0,
        commentsCount: json['commentsCount'] as int? ?? 0,
        description: json['description'] as String? ?? '',
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        date: json['date'] as String? ?? '',
        sortDate: json['sortDate'] != null
            ? DateTime.tryParse(json['sortDate'] as String)
            : null,
        naturalDate: json['naturalDate'] as String? ?? '',
        isNsfw: json['isNsfw'] as bool? ?? false,
        rating: json['rating'] as String? ?? 'general',
        url: json['url'] as String? ?? '',
        isFlash: json['isFlash'] as bool? ?? false,
        flashUrl: json['flashUrl'] as String? ?? '',
        isFavorite: json['isFavorite'] as bool? ?? false,
        favoriteUrl: json['favoriteUrl'] as String? ?? '',
      );

  /// Build from the FAKit submission page (detail view).
  factory Submission.fromFASubmissionPage(
      fa.FASubmissionPage page, String submissionId) {
    final m = page.metadata;
    return Submission(
      id: submissionId,
      title: m.title,
      author: m.author,
      displayName: m.displayAuthor,
      category: m.category.isNotEmpty ? m.category : 'Digital',
      imageUrl: page.fullResolutionMediaUrl?.toString() ??
          page.previewImageUrl.toString(),
      views: m.viewCount,
      faves: m.favoriteCount,
      commentsCount: m.commentCount,
      description: page.htmlDescription,
      tags: m.keywords,
      date: m.naturalDatetime,
      sortDate: m.datetime,
      naturalDate: m.naturalDatetime,
      isNsfw: m.rating == fa.Rating.adult || m.rating == fa.Rating.mature,
      rating: m.rating == fa.Rating.adult
          ? 'adult'
          : m.rating == fa.Rating.mature
              ? 'mature'
              : 'general',
      url: 'https://www.furaffinity.net/view/$submissionId/',
      isFavorite: page.isFavorite,
      favoriteUrl: page.favoriteUrl?.toString() ?? '',
    );
  }

  /// Build from the FAKit submissions list item (browse/gallery/feed preview).
  factory Submission.fromFASubmissionsPageItem(fa.FASubmissionsPageItem item) {
    final ratingStr = item.rating == fa.Rating.adult
        ? 'adult'
        : item.rating == fa.Rating.mature
            ? 'mature'
            : 'general';
    return Submission(
      id: item.sid.toString(),
      title: item.title,
      author: item.author,
      displayName: item.displayAuthor,
      category: 'Digital',
      imageUrl: item.thumbnailUrl.toString(),
      views: 0,
      faves: 0,
      commentsCount: 0,
      description: '',
      tags: [],
      date: '',
      sortDate: null,
      naturalDate: '',
      isNsfw: item.rating != fa.Rating.general,
      rating: ratingStr,
      url: item.url.toString(),
    );
  }

  // ── Legacy parsers (deprecated, kept only for backward compatibility) ──

  static List<Submission> parseSubmissionsPage(String htmlString) {
    final page = fa.FASubmissionsPage.parse(
        htmlString, Uri.parse('https://www.furaffinity.net'));
    return page.submissions
        .whereNotNull()
        .map((item) => Submission.fromFASubmissionsPageItem(item))
        .toList();
  }

  static Submission? parseSubmissionDetails(
      String htmlString, String submissionId) {
    final page = fa.FASubmissionPage.parse(htmlString,
        Uri.parse('https://www.furaffinity.net/view/$submissionId/'));
    return Submission.fromFASubmissionPage(page, submissionId);
  }

  static List<Submission> parseSearchResults(String htmlString) {
    return parseSubmissionsPage(htmlString);
  }
}

extension _NonNull<T> on Iterable<T?> {
  Iterable<T> whereNotNull() => where((e) => e != null).cast<T>();
}
