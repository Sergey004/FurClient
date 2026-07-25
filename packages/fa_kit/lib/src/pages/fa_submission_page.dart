import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'fa_page.dart';
import 'fa_urls.dart';
import '../utils/fa_date_parser.dart';

/// Rating of a submission.
///
/// Mirrors the `Rating` enum in FASubmissionPage.swift:11-42.
enum Rating {
  general,
  mature,
  adult;

  /// Parse from a FA rating string ("General", "Mature", "Adult").
  static Rating? fromString(String? raw) {
    if (raw == null) return null;
    switch (raw.trim().toLowerCase()) {
      case 'general':
        return Rating.general;
      case 'mature':
        return Rating.mature;
      case 'adult':
        return Rating.adult;
      default:
        return null;
    }
  }

  /// Parse from a `<figure>` CSS class list — e.g. "r-general t-image".
  static Rating? fromFigureClass(String? classAttribute) {
    if (classAttribute == null) return null;
    for (final token in classAttribute.split(' ')) {
      switch (token) {
        case 'r-general':
          return Rating.general;
        case 'r-mature':
          return Rating.mature;
        case 'r-adult':
          return Rating.adult;
      }
    }
    return null;
  }
}

/// Metadata for a submission.
class FASubmissionPageMetadata {
  final String title;
  final String author;
  final String displayAuthor;
  final DateTime? datetime;
  final String naturalDatetime;
  final int viewCount;
  final int commentCount;
  final int favoriteCount;
  final Rating rating;
  final String category;
  final String theme;
  final String species;
  final String resolution;
  final String fileSize;
  final List<String> keywords;
  final List<FAFolder> folders;

  FASubmissionPageMetadata({
    required this.title,
    required this.author,
    required this.displayAuthor,
    required this.datetime,
    required this.naturalDatetime,
    required this.viewCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.rating,
    required this.category,
    required this.theme,
    required this.species,
    required this.resolution,
    required this.fileSize,
    required this.keywords,
    required this.folders,
  });
}

/// Parsed submission detail page.
class FASubmissionPage implements FAPage {
  final Uri previewImageUrl;
  final Uri? fullResolutionMediaUrl;
  final double widthOnHeightRatio;
  final FASubmissionPageMetadata metadata;
  final String htmlDescription;
  final bool isFavorite;
  final Uri? favoriteUrl;
  final List<FAPageComment> comments;
  final int? targetCommentId;
  final bool acceptsNewComments;

  FASubmissionPage({
    required this.previewImageUrl,
    this.fullResolutionMediaUrl,
    required this.widthOnHeightRatio,
    required this.metadata,
    required this.htmlDescription,
    required this.isFavorite,
    this.favoriteUrl,
    required this.comments,
    this.targetCommentId,
    required this.acceptsNewComments,
  });

  /// Parse the submission detail page HTML.
  ///
  /// Mirrors `FASubmissionPage.init(data:url:)` in
  /// FASubmissionPage.swift:168-256.
  static FASubmissionPage parse(String html, Uri url) {
    final document = parser.parse(html);

    // ── Submission page content node ────────────────────────────────
    // body#pageid-submission div#main-window div#site-content div#submission_page
    //   div div.submission-page-content
    final submissionPageContentNode = document.querySelector(
        'body#pageid-submission div#main-window div#site-content div#submission_page div div.submission-page-content');
    final submissionMainContentNode =
        submissionPageContentNode?.querySelector('div#submission-main-content');

    // ── Preview image ────────────────────────────────────────────────
    // div.submission-area img#submissionImg → data-preview-src / data-fullview-src
    final submissionContentNode =
        submissionMainContentNode?.querySelector('div div.submission-content');
    final imgEl = submissionContentNode
        ?.querySelector('div.submission-area img#submissionImg');
    final previewSrc = imgEl?.attributes['data-preview-src'] ?? '';
    final fullViewSrc = imgEl?.attributes['data-fullview-src'] ?? '';
    Uri previewImageUrl = Uri.parse(FAURLs.baseUrl);
    Uri? fullResUrl;
    double widthOnHeightRatio = 1.0;
    if (previewSrc.isNotEmpty) {
      previewImageUrl = Uri.parse(
          previewSrc.startsWith('//') ? 'https:$previewSrc' : previewSrc);
    }
    if (fullViewSrc.isNotEmpty) {
      final full =
          fullViewSrc.startsWith('//') ? 'https:$fullViewSrc' : fullViewSrc;
      fullResUrl = Uri.parse(full);
    }

    // ── Favorite button ─────────────────────────────────────────────
    // div#submission-options a.button with text "+Fav" or "-Fav"
    bool isFavorite = false;
    Uri? favoriteUrl;
    final optionButtons = submissionContentNode?.querySelectorAll(
        'div.submission-content-inner div#submission-options a.button');
    if (optionButtons != null) {
      for (final btn in optionButtons) {
        final text = btn.text.trim();
        if (text == '+Fav' || text == '-Fav') {
          final href = btn.attributes['href'] ?? '';
          if (href.isNotEmpty) {
            favoriteUrl = Uri.parse(
                href.startsWith('http') ? href : '${FAURLs.baseUrl}$href');
            isFavorite = text == '-Fav';
          }
          break;
        }
      }
    }

    // ── Description (HTML) ──────────────────────────────────────────
    // div.submission-details ... div.submission-description-text
    final descEl = submissionMainContentNode?.querySelector(
        'div div.submission-details div section.submission-description div.section-body div.submission-description-text');
    final htmlDescription = descEl?.innerHtml.trim() ?? '';

    // ── Comments ────────────────────────────────────────────────────
    // div.comments-list div#comments-submission div.comment_container
    final commentNodes = submissionPageContentNode?.querySelectorAll(
            'div.comments-list div#comments-submission div.comment_container') ??
        [];
    final comments = commentNodes
        .map((node) => parsePageComment(node, CommentType.comment))
        .toList();

    // ── Target comment from URL ─────────────────────────────────────
    int? targetCommentId;
    final targetMatch = RegExp(r'www\.furaffinity\.net\/view\/\d+\/#cid:(\d+)$')
        .firstMatch(url.toString());
    if (targetMatch != null) {
      targetCommentId = int.tryParse(targetMatch.group(1) ?? '');
    }

    // ── Accepts new comments? ──────────────────────────────────────
    final responseBox = submissionPageContentNode
        ?.querySelector('div.comments-list div#responsebox');
    final responseText = responseBox?.text ?? '';
    final acceptsNewComments =
        !responseText.contains('Comment posting has been disabled');

    // ── Metadata ───────────────────────────────────────────────────
    final metadata = _parseMetadata(submissionMainContentNode, document);

    return FASubmissionPage(
      previewImageUrl: previewImageUrl,
      fullResolutionMediaUrl: fullResUrl,
      widthOnHeightRatio: widthOnHeightRatio,
      metadata: metadata,
      htmlDescription: htmlDescription,
      isFavorite: isFavorite,
      favoriteUrl: favoriteUrl,
      comments: comments,
      targetCommentId: targetCommentId,
      acceptsNewComments: acceptsNewComments,
    );
  }

  /// Parse metadata from the submission page.
  ///
  /// Mirrors `FASubmissionPage.Metadata.init(root:)` in
  /// FASubmissionPage.swift:258-330.
  static FASubmissionPageMetadata _parseMetadata(
      dom.Element? submissionMainContentNode, dom.Document root) {
    // ── Title ───────────────────────────────────────────────────────
    final titleEl =
        submissionMainContentNode?.querySelector('div div.submission-title h2');
    final title = titleEl?.text.trim() ?? '';

    // ── Author ──────────────────────────────────────────────────────
    // div.submission-description-artist → span.c-usernameBlockSimple a
    final descHeaderNode = submissionMainContentNode?.querySelector(
        'div div.submission-details div section.submission-description div.section-header.submission-description-header');
    final artistNode = descHeaderNode
        ?.querySelector('div.submission-description-artist')
        ?.querySelector('div span span.c-usernameBlockSimple a');
    String author = '';
    String displayAuthor = '';
    if (artistNode != null) {
      final href = artistNode.attributes['href'] ?? '';
      final match = RegExp(r'/user/(.+)/').firstMatch(href);
      author = match?.group(1) ?? '';
      // displayAuthor from span.c-usernameBlockSimple__displayName
      final displaySpan =
          artistNode.querySelector('span.c-usernameBlockSimple__displayName');
      displayAuthor = (displaySpan?.text.trim() ?? artistNode.text.trim());
    }

    // ── Date ───────────────────────────────────────────────────────
    final dateNode = descHeaderNode?.querySelector('div div span.popup_date');
    final dateResult = parseFADateNode(dateNode);

    // ── Stats (Views/Comments/Favorites) ───────────────────────────
    final statsNode = submissionMainContentNode
        ?.querySelector('div div div.submission-page-stats');
    int viewCount = 0;
    int commentCount = 0;
    int favoriteCount = 0;
    if (statsNode != null) {
      viewCount = int.tryParse(
              statsNode.querySelector('div[title="Views"] div')?.text.trim() ??
                  '') ??
          0;
      commentCount = int.tryParse(statsNode
                  .querySelector('div[title="Comments"] div')
                  ?.text
                  .trim() ??
              '') ??
          0;
      favoriteCount = int.tryParse(statsNode
                  .querySelector('div[title="Favorites"] div')
                  ?.text
                  .trim() ??
              '') ??
          0;
    }

    // ── Rating ─────────────────────────────────────────────────────
    final ratingEl = statsNode?.querySelector('div[class*="c-contentRating"]');
    final rating = Rating.fromString(ratingEl?.text) ?? Rating.general;

    // ── Content stats (category/theme/species/resolution/fileSize) ─
    final stats = _submissionContentStats(submissionMainContentNode);
    final category = stats['Category'] ?? '';
    final theme = stats['Theme'] ?? '';
    final species = stats['Species'] ?? '';
    final resolution = stats['Resolution'] ?? '';
    final fileSize = stats['File Size'] ?? '';

    // ── Keywords / tags ────────────────────────────────────────────
    final keywordNodes = submissionMainContentNode
            ?.querySelectorAll('div div.submission-tags div span.tags') ??
        [];
    final keywords = <String>[];
    for (final node in keywordNodes) {
      final tagBlock = node.querySelector('[data-tag-name]');
      if (tagBlock != null) {
        final tag = tagBlock.attributes['data-tag-name'];
        if (tag != null && tag.isNotEmpty) keywords.add(tag);
      } else {
        final tagInvalid = node.querySelector('.tag-invalid');
        if (tagInvalid != null) {
          final text = tagInvalid.text.trim();
          if (text.isNotEmpty) keywords.add(text);
        }
      }
    }

    // ── Folders ────────────────────────────────────────────────────
    final folderNodes = submissionMainContentNode?.querySelectorAll(
            'div div#submission-sidebar-lower div.submission-controls-lower div.folder-list-container div div.submission-folder a') ??
        [];
    final folders = <FAFolder>[];
    for (final node in folderNodes) {
      final href = node.attributes['href'] ?? '';
      final folderUrl =
          Uri.parse(href.startsWith('http') ? href : '${FAURLs.baseUrl}$href');
      folders.add(FAFolder(
        title: node.text.trim(),
        url: folderUrl,
        isActive: false,
        id: href,
      ));
    }

    return FASubmissionPageMetadata(
      title: title,
      author: author,
      displayAuthor: displayAuthor,
      datetime: dateResult.datetime,
      naturalDatetime: dateResult.naturalDatetime,
      viewCount: viewCount,
      commentCount: commentCount,
      favoriteCount: favoriteCount,
      rating: rating,
      category: category,
      theme: theme,
      species: species,
      resolution: resolution,
      fileSize: fileSize,
      keywords: keywords,
      folders: folders,
    );
  }

  /// Parse the `submission-content-stats` table into a `{category: value}` map.
  ///
  /// Mirrors `submissionContentStats(in:)` in FASubmissionPage.swift:143-157.
  static Map<String, String> _submissionContentStats(
      dom.Element? submissionMainContentNode) {
    final statsNode = submissionMainContentNode
        ?.querySelector('div div.submission-content-stats');
    if (statsNode == null) return {};
    final spans = statsNode.querySelectorAll('> span');
    if (spans.length < 2) return {};
    final categories =
        spans[0].querySelectorAll('> span').map((e) => e.text.trim()).toList();
    final values =
        spans[1].querySelectorAll('> span').map((e) => e.text.trim()).toList();
    if (categories.isEmpty || categories.length != values.length) return {};
    return Map.fromIterables(categories, values);
  }
}
