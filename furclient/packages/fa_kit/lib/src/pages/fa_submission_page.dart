import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'fa_page.dart';
import 'fa_pages_error.dart';

/// Metadata for a submission.
class FASubmissionPageMetadata {
  final String title;
  final String author;
  final String displayAuthor;
  final DateTime datetime;
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
  static FASubmissionPage parse(String html, Uri url) {
    final document = parser.parse(html);

    // Parse metadata from the info section
    final metadata = _parseMetadata(document, url);

    // Parse preview image
    final previewImg = document.querySelector('#submissionImg') ??
        document.querySelector('.submission-img-container img') ??
        document.querySelector('img[data-preview]');
    Uri previewImageUrl = Uri.parse('https://www.furaffinity.net/');
    double widthOnHeightRatio = 1.0;
    if (previewImg != null) {
      final src = previewImg.attributes['src'] ?? '';
      previewImageUrl = Uri.parse(src.startsWith('//')
          ? 'https:$src'
          : src.startsWith('http')
              ? src
              : 'https://www.furaffinity.net$src');
      final w = double.tryParse(previewImg.attributes['width'] ?? '1') ?? 1;
      final h = double.tryParse(previewImg.attributes['height'] ?? '1') ?? 1;
      widthOnHeightRatio = h > 0 ? w / h : 1.0;
    }

    // Parse full resolution download link
    Uri? fullResUrl;
    final downloadLink = document.querySelector('a[href*="/download/"]');
    if (downloadLink != null) {
      final href = downloadLink.attributes['href'] ?? '';
      if (href.isNotEmpty) {
        fullResUrl = Uri.parse(href.startsWith('http')
            ? href
            : 'https://www.furaffinity.net$href');
      }
    }

    // Parse description
    final descElement = document.querySelector('div#submission-description') ??
        document.querySelector('.submission-description') ??
        document.querySelector('div.description');
    String htmlDescription = descElement?.innerHtml ?? '';

    // Parse favorite status
    bool isFavorite = false;
    Uri? favoriteUrl;
    final favButton = document.querySelector('a.favorite-button') ??
        document.querySelector('a[title="Favorite"]') ??
        document.querySelector('button.favorite-button') ??
        document.querySelector('a[href*="/favorites/"]');
    if (favButton != null) {
      final href = favButton.attributes['href'] ?? '';
      if (href.isNotEmpty) {
        favoriteUrl = Uri.parse(href.startsWith('http')
            ? href
            : 'https://www.furaffinity.net$href');
        // If the link contains "remove", it's currently favorited
        isFavorite = href.contains('/remove/') || href.contains('unfav');
      }
    }

    // Parse comments
    final comments = _parseComments(document);

    // Parse comment target from URL hash
    int? targetCommentId;
    final hashMatch = RegExp(r'cid(\d+)').firstMatch(url.fragment);
    if (hashMatch != null) {
      targetCommentId = int.tryParse(hashMatch.group(1)!);
    }

    // Check if comments are accepted
    final commentForm = document.querySelector('form[action*="reply"]');
    final acceptsNewComments = commentForm != null;

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

  static FASubmissionPageMetadata _parseMetadata(dom.Document document, Uri url) {
    String title = '';
    String author = '';
    String displayAuthor = '';
    DateTime datetime = DateTime.now();
    String naturalDatetime = '';
    int viewCount = 0;
    int commentCount = 0;
    int favoriteCount = 0;
    Rating rating = Rating.general;
    String category = '';
    String theme = '';
    String species = '';
    String resolution = '';
    String fileSize = '';
    final keywords = <String>[];
    final folders = <FAFolder>[];

    // Title
    final titleEl = document.querySelector('h2.title') ??
        document.querySelector('h2') ??
        document.querySelector('div.submission-title');
    if (titleEl != null) {
      title = titleEl.text.trim();
    }

    // Author
    final authorLink = document.querySelector('a[href*="/user/"]');
    if (authorLink != null) {
      final href = authorLink.attributes['href'] ?? '';
      final match = RegExp(r'/user/([^/]+)/').firstMatch(href);
      author = match?.group(1) ?? '';
      displayAuthor = authorLink.text.trim();
    }

    // Stats (views, comments, favorites)
    final statsContainer = document.querySelector('div.stats') ??
        document.querySelector('section.stats') ??
        document.querySelector('.submission-stats');
    if (statsContainer != null) {
      final statsText = statsContainer.text;
      final viewsMatch = RegExp(r'Views:\s*(\d+)').firstMatch(statsText);
      final commentsMatch = RegExp(r'Comments:\s*(\d+)').firstMatch(statsText);
      final favsMatch = RegExp(r'Favorites:\s*(\d+)').firstMatch(statsText);
      viewCount = int.tryParse(viewsMatch?.group(1) ?? '0') ?? 0;
      commentCount = int.tryParse(commentsMatch?.group(1) ?? '0') ?? 0;
      favoriteCount = int.tryParse(favsMatch?.group(1) ?? '0') ?? 0;
    }

    // Rating
    final ratingEl = document.querySelector('span.rating') ??
        document.querySelector('div.rating-box');
    if (ratingEl != null) {
      rating = Rating.fromString(ratingEl.text.trim());
    }

    // Date/time
    final dateEl = document.querySelector('span.popup_date') ??
        document.querySelector('span.date') ??
        document.querySelector('time');
    if (dateEl != null) {
      naturalDatetime = dateEl.text.trim();
      final ts = dateEl.attributes['title'] ?? dateEl.attributes['datetime'] ?? '';
      if (ts.isNotEmpty) {
        datetime = DateTime.tryParse(ts) ?? DateTime.now();
      }
    }

    // Keywords / tags
    final tagElements = document.querySelectorAll('a.tags-link, a.keyword, a[href*="/search/"]');
    for (final tag in tagElements) {
      keywords.add(tag.text.trim());
    }

    // Folders
    final folderElements = document.querySelectorAll('a[href*="/folder/"]');
    for (final folder in folderElements) {
      final href = folder.attributes['href'] ?? '';
      folders.add(FAFolder(
        title: folder.text.trim(),
        url: Uri.parse(href.startsWith('http') ? href : 'https://www.furaffinity.net$href'),
        isActive: folder.classes.contains('active'),
        id: href,
      ));
    }

    return FASubmissionPageMetadata(
      title: title,
      author: author,
      displayAuthor: displayAuthor,
      datetime: datetime,
      naturalDatetime: naturalDatetime,
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

  static List<FAPageComment> _parseComments(dom.Document document) {
    final comments = <FAPageComment>[];
    final commentElements = document.querySelectorAll(
        'div.comment-container, div.comment, li.comment');

    for (final commentEl in commentElements) {
      try {
        // Check if hidden
        final hiddenText = commentEl.querySelector('.comment-hidden, .hidden-comment');
        if (hiddenText != null) {
          final cidMatch = RegExp(r'cid=(\d+)').firstMatch(
              commentEl.outerHtml);
          final cid = int.tryParse(cidMatch?.group(1) ?? '') ?? 0;
          comments.add(FAHiddenPageComment(
            cid: cid,
            indentation: 0,
            htmlMessage: hiddenText.text.trim(),
          ));
          continue;
        }

        // Parse visible comment
        final cidMatch = RegExp(r'cid=(\d+)').firstMatch(commentEl.outerHtml);
        final cid = int.tryParse(cidMatch?.group(1) ?? '') ?? 0;

        final indentEl = commentEl.querySelector('.comment-indentation, .comment-avatar');
        int indentation = 0;
        if (indentEl != null) {
          final widthAttr = indentEl.attributes['width'] ??
              indentEl.attributes['data-indentation'] ?? '0';
          indentation = (double.tryParse(widthAttr) ?? 0).toInt() ~/ 16; // 16px per indent
        }

        final authorLink = commentEl.querySelector('a.comment-username, a[href*="/user/"]');
        final author = authorLink != null
            ? (RegExp(r'/user/([^/]+)/').firstMatch(
                authorLink.attributes['href'] ?? '')?.group(1) ?? '')
            : '';
        final displayAuthor = authorLink?.text.trim() ?? '';

        final dateEl = commentEl.querySelector('span.comment-date, span.popup_date');
        final naturalDatetime = dateEl?.text.trim() ?? '';
        final datetimeAttr = dateEl?.attributes['title'] ?? dateEl?.attributes['datetime'] ?? '';
        final datetime = DateTime.tryParse(datetimeAttr) ?? DateTime.now();

        final messageEl = commentEl.querySelector('div.comment-text, div.comment_message');
        final htmlMessage = messageEl?.innerHtml ?? '';

        comments.add(FAVisiblePageComment(
          cid: cid,
          indentation: indentation,
          author: author,
          displayAuthor: displayAuthor,
          datetime: datetime,
          naturalDatetime: naturalDatetime,
          htmlMessage: htmlMessage,
        ));
      } catch (_) {
        // Skip malformed comments
      }
    }

    return comments;
  }
}
