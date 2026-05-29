import 'package:html/parser.dart' as parser;
import 'fa_page.dart';
import 'fa_submissions_page.dart';

/// Parsed user gallery/scraps page.
class FAUserGalleryLikePage implements FAPage {
  final List<FASubmissionsPageItem?> previews;
  final String displayAuthor;
  final Uri? nextPageUrl;
  final List<FAFolderGroup> folderGroups;

  FAUserGalleryLikePage({
    required this.previews,
    required this.displayAuthor,
    this.nextPageUrl,
    required this.folderGroups,
  });

  /// Parse the user gallery page HTML.
  static FAUserGalleryLikePage parse(String html, Uri url) {
    final document = parser.parse(html);

    // Display author from page
    String displayAuthor = '';
    final authorEl = document.querySelector('h2, .section-title, .gallery-header');
    if (authorEl != null) {
      displayAuthor = authorEl.text.trim();
    }

    // Parse submissions (reuse submissions page parsing)
    final previews = <FASubmissionsPageItem?>[];
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
        final authorLink = figure.querySelector('a[href*="/user/"]');
        String author = '';
        if (authorLink != null) {
          final match = RegExp(r'/user/([^/]+)/')
              .firstMatch(authorLink.attributes['href'] ?? '');
          author = match?.group(1) ?? '';
        }

        previews.add(FASubmissionsPageItem(
          sid: sid,
          url: submissionUrl,
          thumbnailUrl: thumbnailUrl,
          thumbnailWidthOnHeightRatio: ratio,
          title: title,
          author: author,
          displayAuthor: authorLink?.text.trim() ?? author,
        ));
      } catch (_) {
        previews.add(null);
      }
    }

    // Parse folder groups
    final folderGroups = <FAFolderGroup>[];
    final folderContainers = document.querySelectorAll('div.folder-group, .gallery-folder-group');
    for (final container in folderContainers) {
      final groupTitle = container.querySelector('h3, .folder-title')?.text.trim();
      final folders = <FAFolder>[];
      final folderLinks = container.querySelectorAll('a[href*="/folder/"]');
      for (final folderLink in folderLinks) {
        final href = folderLink.attributes['href'] ?? '';
        folders.add(FAFolder(
          title: folderLink.text.trim(),
          url: Uri.parse(href.startsWith('http') ? href : 'https://www.furaffinity.net$href'),
          isActive: folderLink.classes.contains('active'),
          id: href,
        ));
      }
      folderGroups.add(FAFolderGroup(
        title: groupTitle,
        folders: folders,
        id: 'group_${folderGroups.length}',
      ));
    }

    // Pagination
    Uri? nextPageUrl;
    final nextLink = document.querySelector('a.next, a.button-right');
    if (nextLink != null) {
      final href = nextLink.attributes['href'] ?? '';
      if (href.isNotEmpty) {
        nextPageUrl = Uri.parse(href.startsWith('http')
            ? href
            : 'https://www.furaffinity.net$href');
      }
    }

    return FAUserGalleryLikePage(
      previews: previews,
      displayAuthor: displayAuthor,
      nextPageUrl: nextPageUrl,
      folderGroups: folderGroups,
    );
  }
}
