import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'fa_page.dart';

/// A single submission in a submissions list page.
class FASubmissionsPageItem {
  final int sid;
  final Uri url;
  final Uri thumbnailUrl;
  final double thumbnailWidthOnHeightRatio;
  final String title;
  final String author;
  final String displayAuthor;

  FASubmissionsPageItem({
    required this.sid,
    required this.url,
    required this.thumbnailUrl,
    required this.thumbnailWidthOnHeightRatio,
    required this.title,
    required this.author,
    required this.displayAuthor,
  });
}

/// Parsed submissions list page (browse/gallery views).
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
  static FASubmissionsPage parse(String html, Uri url) {
    final document = parser.parse(html);

    final submissions = <FASubmissionsPageItem?>[];
    final figureElements = document.querySelectorAll('figure');

    for (final figure in figureElements) {
      try {
        final link = figure.querySelector('a');
        if (link == null) continue;
        final href = link.attributes['href'] ?? '';

        final sidMatch = RegExp(r'/view/(\d+)/').firstMatch(href);
        if (sidMatch == null) continue;
        final sid = int.parse(sidMatch.group(1)!);

        final submissionUrl = Uri.parse(href.startsWith('http')
            ? href
            : 'https://www.furaffinity.net$href');

        final img = link.querySelector('img');
        if (img == null) continue;
        final src = img.attributes['src'] ?? img.attributes['data-src'] ?? '';
        final thumbnailUrl = Uri.parse(src.startsWith('//')
            ? 'https:$src'
            : src.startsWith('http')
                ? src
                : 'https://www.furaffinity.net$src');

        final imgWidth = double.tryParse(img.attributes['width'] ?? '1') ?? 1;
        final imgHeight = double.tryParse(img.attributes['height'] ?? '1') ?? 1;
        final ratio = imgHeight > 0 ? imgWidth / imgHeight : 1.0;

        final title = img.attributes['alt'] ?? img.attributes['title'] ?? '';
        final author = _extractAuthorFromFigure(figure) ?? '';
        final displayAuthor = _extractDisplayAuthorFromFigure(figure) ?? author;

        submissions.add(FASubmissionsPageItem(
          sid: sid,
          url: submissionUrl,
          thumbnailUrl: thumbnailUrl,
          thumbnailWidthOnHeightRatio: ratio,
          title: title,
          author: author,
          displayAuthor: displayAuthor,
        ));
      } catch (_) {
        submissions.add(null);
      }
    }

    // Parse pagination links
    Uri? nextPageUrl;
    Uri? previousPageUrl;
    final pagination = document.querySelector('div.pagination');
    if (pagination != null) {
      final nextLink = pagination.querySelector('a.next');
      if (nextLink != null) {
        final href = nextLink.attributes['href'] ?? '';
        if (href.isNotEmpty) {
          nextPageUrl = Uri.parse(href.startsWith('http')
              ? href
              : 'https://www.furaffinity.net$href');
        }
      }
      final prevLink = pagination.querySelector('a.prev, a.previous');
      if (prevLink != null) {
        final href = prevLink.attributes['href'] ?? '';
        if (href.isNotEmpty) {
          previousPageUrl = Uri.parse(href.startsWith('http')
              ? href
              : 'https://www.furaffinity.net$href');
        }
      }
    }

    return FASubmissionsPage(
      submissions: submissions,
      nextPageUrl: nextPageUrl,
      previousPageUrl: previousPageUrl,
    );
  }

  static String? _extractAuthorFromFigure(dom.Element figure) {
    final authorLink = figure.querySelector('a[href*="/user/"]');
    if (authorLink != null) {
      final href = authorLink.attributes['href'] ?? '';
      final match = RegExp(r'/user/([^/]+)/').firstMatch(href);
      return match?.group(1);
    }
    return null;
  }

  static String? _extractDisplayAuthorFromFigure(dom.Element figure) {
    final authorLink = figure.querySelector('a[href*="/user/"]');
    if (authorLink != null) {
      return authorLink.text.trim();
    }
    return null;
  }
}
