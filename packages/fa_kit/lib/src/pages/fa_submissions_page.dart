import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'fa_page.dart';
import 'fa_submission_page.dart' show Rating;
import 'fa_urls.dart';

/// A single submission in a submissions list page (browse/gallery/feed).
///
/// Mirrors `FASubmissionsPage.Submission` in
/// FASubmissionsPage.swift:12-32.
class FASubmissionsPageItem {
  final int sid;
  final Uri url;
  final Uri thumbnailUrl;
  final double thumbnailWidthOnHeightRatio;
  final String title;
  final String author;
  final String displayAuthor;
  final Rating rating;

  FASubmissionsPageItem({
    required this.sid,
    required this.url,
    required this.thumbnailUrl,
    required this.thumbnailWidthOnHeightRatio,
    required this.title,
    required this.author,
    required this.displayAuthor,
    required this.rating,
  });
}

/// Parsed submissions list page (browse / gallery / favorites / scraps / feed).
///
/// Mirrors `FASubmissionsPage` in FASubmissionsPage.swift:11-75.
class FASubmissionsPage implements FAPage {
  final List<FASubmissionsPageItem?> submissions;
  final Uri? nextPageUrl;
  final Uri? previousPageUrl;

  FASubmissionsPage({
    required this.submissions,
    this.nextPageUrl,
    this.previousPageUrl,
  });

  /// Parse the submissions list page HTML.
  ///
  /// Mirrors `FASubmissionsPage.init(data:url:)` in
  /// FASubmissionsPage.swift:40-75.
  static FASubmissionsPage parse(String html, Uri url) {
    final document = parser.parse(html);

    // ── Submission figures ────────────────────────────────────────
    // figure[id^="sid-"]
    final figureElements = document.querySelectorAll('figure[id^="sid-"]');
    final submissions =
        figureElements.map((figure) => _parseFigure(figure)).toList();

    // ── Pagination links ──────────────────────────────────────────
    // Look for Prev / Next buttons in the page body.
    // FA uses various containers (div.aligncenter, pagination) — search all
    // <a> elements for the "Prev" / "Next" text.
    Uri? nextPageUrl;
    Uri? previousPageUrl;

    final allButtons = document.querySelectorAll('a');
    for (final btn in allButtons) {
      final text = btn.text.trim();
      final href = btn.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      if (text.startsWith('Prev') && previousPageUrl == null) {
        previousPageUrl = Uri.parse(
            href.startsWith('http') ? href : '${FAURLs.baseUrl}$href');
      } else if (text.startsWith('Next') && nextPageUrl == null) {
        nextPageUrl = Uri.parse(
            href.startsWith('http') ? href : '${FAURLs.baseUrl}$href');
      }
    }

    return FASubmissionsPage(
      submissions: submissions,
      nextPageUrl: nextPageUrl,
      previousPageUrl: previousPageUrl,
    );
  }
}

/// Parse a single `<figure id="sid-N">` submission thumbnail.
///
/// Mirrors `FASubmissionsPage.Submission.init(_:)` in
/// FASubmissionsPage.swift:77-109.
FASubmissionsPageItem? _parseFigure(dom.Element figure) {
  try {
    final idAttr = figure.attributes['id'] ?? '';
    if (!idAttr.startsWith('sid-')) return null;
    final sid = int.tryParse(idAttr.substring(4));
    if (sid == null) return null;

    final url = Uri.parse('${FAURLs.baseUrl}/view/$sid/');

    // Thumbnail: figure b u a img
    final thumbImg = figure.querySelector('b u a img') ??
        figure.querySelector('a[href*="/view/"] img');
    if (thumbImg == null) return null;
    final thumbSrc = thumbImg.attributes['src'] ?? '';
    if (thumbSrc.isEmpty) return null;
    final thumbnailUrl =
        Uri.parse(thumbSrc.startsWith('//') ? 'https:$thumbSrc' : thumbSrc);

    // Width / height ratio
    final thumbWidthStr = thumbImg.attributes['data-width'] ?? '1';
    final thumbHeightStr = thumbImg.attributes['data-height'] ?? '1';
    final thumbWidth = double.tryParse(thumbWidthStr) ?? 1.0;
    final thumbHeight = double.tryParse(thumbHeightStr) ?? 1.0;
    final ratio = thumbHeight > 0 ? thumbWidth / thumbHeight : 1.0;

    // figcaption p a — first = title, second = author
    final captionLinks = figure.querySelectorAll('figcaption p a');
    if (captionLinks.length < 2) return null;

    final title = captionLinks[0].text.trim();

    final authorHref = captionLinks[1].attributes['href'] ?? '';
    final authorMatch = RegExp(r'/user/(.+)/').firstMatch(authorHref);
    final author = authorMatch?.group(1) ?? '';
    final displayAuthor = captionLinks[1].text.trim();

    // Rating from <figure> class (r-general / r-mature / r-adult).
    final rating =
        Rating.fromFigureClass(figure.attributes['class']) ?? Rating.general;

    return FASubmissionsPageItem(
      sid: sid,
      url: url,
      thumbnailUrl: thumbnailUrl,
      thumbnailWidthOnHeightRatio: ratio,
      title: title,
      author: author,
      displayAuthor: displayAuthor,
      rating: rating,
    );
  } catch (_) {
    return null;
  }
}
