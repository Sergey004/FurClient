import 'dart:convert';
import 'dart:typed_data';
import '../pages/fa_urls.dart';
import '../session/http_data_source.dart';
import '../session/http_data_source_impl.dart';

// FATheme определён в fa_urls.dart

/// Inlines CSS `<link>` tags with actual CSS content for self-contained HTML.
class CSSInliner {
  final Map<String, _CachedCSS> _cache = {};
  final HTTPDataSource _dataSource;
  final Duration _cacheExpiry;

  CSSInliner({
    HTTPDataSource? dataSource,
    Duration? cacheExpiry,
  })  : _dataSource = dataSource ?? HttpDataSourceImpl(),
        _cacheExpiry = cacheExpiry ?? const Duration(hours: 24);

  Future<String> inlineCSS(String html) async {
    final linkPattern = RegExp(
      r'<link\s+[^>]*href="([^"]*ui_theme_[^"]*\.css)"[^>]*/?>',
      caseSensitive: false,
    );

    String result = html;
    for (final match in linkPattern.allMatches(html)) {
      final cssUrl = match.group(1) ?? '';
      final cssContent = await _fetchCSS(cssUrl);
      if (cssContent != null) {
        result = result.replaceAll(
          match.group(0)!,
          '<style type="text/css">$cssContent</style>',
        );
      }
    }
    return result;
  }

  Future<String?> _fetchCSS(String cssUrl) async {
    final fullUrl = Uri.parse(
      cssUrl.startsWith('http')
          ? cssUrl
          : 'https://www.furaffinity.net$cssUrl',
    );

    final cached = _cache[fullUrl.toString()];
    if (cached != null && !cached.isExpired) return cached.content;

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

  void clearCache() => _cache.clear();
}

class _CachedCSS {
  final String content;
  final DateTime expiresAt;
  _CachedCSS({required this.content, required this.expiresAt});
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// HTML utility extensions for FA HTML content.
extension FAHtmlUtils on String {
  /// Fix relative links to absolute FA URLs.
  String fixingLinks() {
    String result = this;
    result = result.replaceAllMapped(
      RegExp(r'''(href|src)=["'](/[^"']*)["']'''),
      (m) => '${m.group(1)}="https://www.furaffinity.net${m.group(2)}"',
    );
    result = result.replaceAllMapped(
      RegExp(r'''(href|src)=["']//([^"']*)["']'''),
      (m) => '${m.group(1)}="https://${m.group(2)}"',
    );
    return result;
  }

  String selfContainedFAHtmlSubmission({FATheme theme = FATheme.light}) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="${FAURLs.themeCssUrl(theme)}">
</head>
<body>$this</body>
</html>''';
  }

  String selfContainedFAHtmlComment({FATheme theme = FATheme.light}) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="${FAURLs.themeCssUrl(theme)}">
  <style>body{padding:0;margin:0}.comment-text{overflow:hidden}</style>
</head>
<body><div class="comment-text">$this</div></body>
</html>''';
  }

  String selfContainedFAHtmlUserDescription({FATheme theme = FATheme.light}) {
    return '''<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="${FAURLs.themeCssUrl(theme)}">
</head>
<body><div class="user-description">$this</div></body>
</html>''';
  }

  String usingTheme(FATheme theme) {
    return replaceAllMapped(
      RegExp(r'ui_theme_(light|dark)\.css'),
      (_) => 'ui_theme_${theme == FATheme.dark ? "dark" : "light"}.css',
    );
  }
}
