import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:extended_image/extended_image.dart';
import 'package:fa_kit/fa_kit.dart';
import '../utils/fa_image_proxy.dart';

/// FA-HTML widget — renders FA description/comment HTML via
/// `flutter_widget_from_html_core`, with FA CDN images proxied through
/// [FAImageProxy] (auth + cookies for CF-protected avatars/icons).
///
/// Mirrors the FurAffinityApp Swift approach where
/// `NSAttributedString(data:.html)` parses the full HTML through iOS WebKit.
/// Here `flutter_widget_from_html_core` parses HTML / CSS classes / inline
/// styles into a Flutter widget tree, handling:
/// - BBCode wrappers (`<code class="bbcode bbcode_center">`)
/// - `<sup>`/`<sub>`, `<u>`, `<s>`, `<strong>`, `<em>`
/// - `<span style="color:...">`
/// - `<hr>`, `<blockquote>`, `<h1>-<h6>`
/// - `<a href>` (with in-app navigation hook)
/// - `<img src>` — intercepted and routed through [FAImageProxy]
class FurHtmlWidget extends StatelessWidget {
  final String html;
  final TextStyle? style;
  final double? imageSize;

  /// Set to `true` for comments (smaller avatar icons), `false` for
  /// submission/journal descriptions (uses default image sizing).
  final bool compact;

  const FurHtmlWidget(
    this.html, {
    super.key,
    this.style,
    this.imageSize,
    this.compact = false,
  });

  static Uri _baseUrl = Uri.parse('https://www.furaffinity.net/');

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return HtmlWidget(
      html,
      baseUrl: _baseUrl,
      textStyle: baseStyle,
      // Build large bios/descriptions asynchronously so HTML parsing and
      // widget-tree construction do not block the first frame.
      buildAsync: true,
      enableCaching: true,
      onTapUrl: (url) => _handleLinkTap(context, url),
      factoryBuilder: () => _FAHtmlFactory(imageSize ?? (compact ? 20 : 50)),
    );
  }

  Future<bool> _handleLinkTap(BuildContext context, String url) async {
    debugPrint('FurHtmlWidget: link tapped: $url');
    try {
      final uri = Uri.parse(url);
      if (uri.host == 'www.furaffinity.net' || uri.host == 'furaffinity.net') {
        final target = FATarget.parse(uri);
        if (target != null) {
          Navigator.of(context).pushNamed(target.url.path);
          return true;
        }
      }
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('FurHtmlWidget: launch error: $e');
    }
    return true; // handled
  }
}

/// Custom [WidgetFactory] that intercepts `<img>` src URLs and reroutes them
/// through [FAImageProxy] to attach FA cookies for Cloudflare-protected CDN.
class _FAHtmlFactory extends WidgetFactory {
  final double imageSize;

  _FAHtmlFactory(this.imageSize);

  @override
  ImageProvider? imageProviderFromNetwork(String url) {
    if (_shouldProxy(url)) {
      final proxyUrl = FAImageProxy.proxyUrl(_normalizeSrc(url));
      return ExtendedNetworkImageProvider(proxyUrl, cache: true);
    }
    return super.imageProviderFromNetwork(url);
  }

  static bool _shouldProxy(String src) {
    try {
      final uri = Uri.parse(_normalizeSrc(src));
      return uri.host == 't.furaffinity.net' ||
          uri.host == 'd.furaffinity.net' ||
          uri.host == 'a.furaffinity.net' ||
          uri.host.endsWith('.furaffinity.net');
    } catch (_) {
      return false;
    }
  }

  static String _normalizeSrc(String src) {
    if (src.startsWith('//')) return 'https:$src';
    return src;
  }
}
