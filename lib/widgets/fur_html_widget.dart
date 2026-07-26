import 'package:flutter/material.dart';
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:extended_image/extended_image.dart';
import '../utils/fa_image_proxy.dart';

/// Minimal FA-HTML widget — renders `<br>`, `<a href>`, `<img src>`, `<i>`,
/// `<b>`, `<strong>`, `<em>`, and custom FA `<comment-container>` as
/// "Comment hidden" text.
///
/// Mirrors the FurAffinityApp Swift approach where
/// `NSAttributedString(data:.html)` converts the full HTML tree to attributed
/// text.  On Flutter we build a [Text.rich] tree of [InlineSpan]s, placing FA
/// images via [WidgetSpan] + [ExtendedImage].
class FurHtmlWidget extends StatelessWidget {
  final String html;
  final TextStyle? style;
  final double imageSize;

  const FurHtmlWidget(this.html, {super.key, this.style, this.imageSize = 20});

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final root = _buildRichText(context, baseStyle);
    return Text.rich(root, softWrap: true);
  }

  TextSpan _buildRichText(BuildContext context, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    try {
      _parseHtml(context, baseStyle, spans);
    } catch (_) {
      final plain = html
          .replaceAll(RegExp(r'<br\s*/?>'), '\n')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
      spans.add(TextSpan(text: plain, style: baseStyle));
    }
    if (spans.isEmpty) return TextSpan(text: '', style: baseStyle);
    return TextSpan(children: spans);
  }

  void _parseHtml(
    BuildContext context,
    TextStyle baseStyle,
    List<InlineSpan> out,
  ) {
    try {
      final doc = parser.HtmlParser.parseFragment(html);
      _walkNodes(context, doc.nodes, baseStyle, out);
    } catch (_) {
      final raw = html
          .replaceAll(RegExp(r'<br\s*/?>'), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .trim();
      out.add(TextSpan(text: raw, style: baseStyle));
    }
  }

  void _walkNodes(
    BuildContext context,
    List<dom.Node> nodes,
    TextStyle style,
    List<InlineSpan> out,
  ) {
    for (final node in nodes) {
      if (node is dom.Element) {
        final tag = node.localName!.toLowerCase();
        switch (tag) {
          case 'br':
            out.add(TextSpan(text: '\n', style: style));
            break;
          case 'i':
          case 'em':
            _walkNodes(
              context,
              node.nodes,
              style.merge(const TextStyle(fontStyle: FontStyle.italic)),
              out,
            );
            break;
          case 'b':
          case 'strong':
            _walkNodes(
              context,
              node.nodes,
              style.merge(const TextStyle(fontWeight: FontWeight.bold)),
              out,
            );
            break;
          case 'a':
            _parseAnchor(context, node, style, out);
            break;
          case 'img':
            _parseImage(out, node);
            break;
          case 'comment-container':
            out.add(
              TextSpan(
                text: 'Comment hidden by its owner',
                style: style.merge(
                  const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            );
            break;
          default:
            _walkNodes(context, node.nodes, style, out);
        }
      } else if (node is dom.Text) {
        final data = node.text;
        if (data.isNotEmpty) {
          out.add(TextSpan(text: data, style: style));
        }
      }
    }
  }

  void _parseAnchor(
    BuildContext context,
    dom.Element node,
    TextStyle style,
    List<InlineSpan> out,
  ) {
    final href = node.attributes['href'] ?? '';
    final aStyle = style.merge(
      const TextStyle(
        color: Color(0xFF8AB4F8),
        decoration: TextDecoration.underline,
      ),
    );
    final aSpans = <InlineSpan>[];
    _walkNodes(context, node.nodes, aStyle, aSpans);
    if (href.isNotEmpty) {
      out.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: 14,
          child: GestureDetector(
            onTap: () {
              debugPrint('FurHtmlWidget: link tapped: $href');
            },
            child: Text.rich(TextSpan(children: aSpans)),
          ),
        ),
      );
    } else {
      out.addAll(aSpans);
    }
  }

  void _parseImage(
    BuildContext context,
    dom.Element node,
    List<InlineSpan> out,
  ) {
    var src = node.attributes['src'] ?? '';
    if (src.isEmpty) return;
    if (src.startsWith('//')) src = 'https:$src';
    final targetUrl = FAImageProxy.proxyUrl(src);
    out.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: SizedBox(
          width: imageSize,
          height: imageSize,
          child: ExtendedImage.network(
            targetUrl,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.contain,
            cache: true,
          ),
        ),
      ),
    );
  }
}
