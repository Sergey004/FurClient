import 'dart:convert';
import '../pages/fa_urls.dart';
import '../session/http_data_source.dart';
import '../session/http_data_source_impl.dart';

/// Inlines CSS `<link>` tags with actual CSS content for self-contained HTML.
///
/// Downloads FA theme CSS files and caches them in memory for 24 hours.
class CSSInliner {
  final Map<String, _CachedCSS> _cache = {};
  final HTTPDataSource _dataSource;
  final Duration _cacheExpiry;

  CSSInliner({
    HTTPDataSource? dataSource,
    Duration? cacheExpiry,
  })  : _dataSource = dataSource ?? HttpDataSourceImpl(),
        _cacheExpiry = cacheExpiry ?? const Duration(hours: 24);

  /// Inline CSS link tags in the given HTML string.
  ///
  /// Replaces `<link href="...ui_theme_*.css">` tags with `<style>` blocks
  /// containing the actual CSS content.
  Future<String> inlineCSS(String html) async {
    // Find all CSS link tags
    final linkPattern = RegExp(
      r'<link\s+[^>]*href="([^"]*ui_theme_[^"]*\.css)"[^>]*/?\s*>',
      caseSensitive: false,
    );

    String result = html;
    for (final match in linkPattern.allMatches(html)) {
      final cssUrl = match.group(1) ?? '';
      final cssContent = await _fetchCSS(cssUrl);
      if (cssContent != null) {
        result = result.replaceAll(match.group(0)!,
            '<style type="text/css">$cssContent</style>');
      }
    }

    return result;
  }

  Future<String?> _fetchCSS(String cssUrl) async {
    final fullUrl = Uri.parse(
        cssUrl.startsWith('http') ? cssUrl : 'https://www.furaffinity.net$cssUrl');

    // Check cache
    final cached = _cache[fullUrl.toString()];
    if (cached != null && !cached.isExpired) {
      return cached.content;
    }

    try {
      final data = await _dataSource.httpGet(url: fullUrl);
      final css = utf8.decode(data);

      _cache[fullUrl.toString()] = _CachedCSS(
        content: css,
        expiresAt: DateTime.now().add(_cacheExpiry),
      );

      return css;
    } catch (_) {
      return null;
    }
  }

  /// Clear the CSS cache.
  void clearCache() {
    _cache.clear();
  }
}

class _CachedCSS {
  final String content;
  final DateTime expiresAt;

  _CachedCSS({required this.content, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// HTML utility extensions for preparing FA HTML content.
extension FAHtmlUtils on String {
  /// Fix relative links to absolute FA URLs.
  String fixingLinks() {
    String result = this;
    result = result.replaceAllMapped(
      RegExp(r"""(href|src)=["'](/[^"']*)["']"""),
      (match) {
        final attr = match.group(1)!;
        final path = match.group(2)!;
        return '$attr="https://www.furaffinity.net$path"';
      },
    );
    result = result.replaceAllMapped(
      RegExp(r"""(href|src)=["']//([^"']*)["']"""),
      (match) {
        final attr = match.group(1)!;
        final url = match.group(2)!;
        return '$attr="https://$url"';
      },
    );
    return result;
  }

  /// Wrap HTML fragment in a self-contained document with CSS links.
  String selfContainedFAHtmlSubmission({FATheme theme = FATheme.light}) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="${FAURLs.themeCssUrl(theme)}">
</head>
<body>
  $this
</body>
</html>''';
  }

  /// Wrap comment HTML in a self-contained document.
  String selfContainedFAHtmlComment({FATheme theme = FATheme.light}) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="${FAURLs.themeCssUrl(theme)}">
  <style>
    body { padding: 0; margin: 0; }
    .comment-text { overflow: hidden; }
  </style>
</head>
<body>
  <div class="comment-text">$this</div>
</body>
</html>''';
  }

  /// Wrap user description HTML in a self-contained document.
  String selfContainedFAHtmlUserDescription({FATheme theme = FATheme.light}) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="${FAURLs.themeCssUrl(theme)}">
</head>
<body>
  <div class="user-description">$this</div>
</body>
</html>''';
  }

  /// Switch CSS theme in the HTML.
  String usingTheme(FATheme theme) {
    return replaceAllMapped(
      RegExp(r'ui_theme_(light|dark)\.css'),
      (match) => 'ui_theme_${theme == FATheme.dark ? "dark" : "light"}.css',
    );
  }
}
