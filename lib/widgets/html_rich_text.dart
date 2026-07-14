import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:url_launcher/url_launcher.dart';

/// A simple HTML rich text renderer.
///
/// Renders a subset of HTML (bold, italic, underline, links, paragraphs,
/// lists, line breaks) as a [RichText]. Links are tappable and open in the
/// external browser via [url_launcher].
///
/// Implemented as a [StatefulWidget] so that the HTML is parsed once and the
/// [TapGestureRecognizer]s created for links are owned and disposed here —
/// avoiding the per-rebuild leak a [StatelessWidget] would cause.
class HtmlRichText extends StatefulWidget {
  final String html;
  final TextStyle defaultStyle;
  final TextStyle linkStyle;
  final int? maxLines;
  final TextOverflow overflow;

  const HtmlRichText({
    super.key,
    required this.html,
    this.defaultStyle = const TextStyle(fontSize: 14, height: 1.6),
    this.linkStyle = const TextStyle(
      fontSize: 14,
      height: 1.6,
      color: Color(0xFF64B5F6),
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFF64B5F6),
    ),
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  State<HtmlRichText> createState() => _HtmlRichTextState();
}

class _HtmlRichTextState extends State<HtmlRichText> {
  InlineSpan _root = const TextSpan(text: '');
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _rebuildSpans();
  }

  @override
  void didUpdateWidget(covariant HtmlRichText old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html ||
        old.defaultStyle != widget.defaultStyle ||
        old.linkStyle != widget.linkStyle) {
      _disposeRecognizers();
      _rebuildSpans();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _rebuildSpans() {
    final html = widget.html;
    if (html.trim().isEmpty) {
      _root = const TextSpan(text: '');
      return;
    }

    final spans = <InlineSpan>[];
    try {
      final document = html_parser.parse(html);
      final body = document.body;
      if (body != null) {
        _parseChildren(body, spans, widget.defaultStyle);
      }
    } catch (e) {
      // Fallback: render the raw text if parsing fails.
      spans.add(TextSpan(text: html, style: widget.defaultStyle));
    }

    _root = spans.isEmpty
        ? const TextSpan(text: '')
        : TextSpan(children: spans);
  }

  /// Walk the children of [node], composing [parentStyle] into inline styles
  /// so that nested formatting (e.g. `<b>x <i>y</i></b>`) is preserved.
  void _parseChildren(
      dom.Node node, List<InlineSpan> spans, TextStyle parentStyle) {
    for (final child in node.nodes) {
      _parseNode(child, spans, parentStyle);
    }
  }

  void _parseNode(
      dom.Node node, List<InlineSpan> spans, TextStyle parentStyle) {
    if (node is dom.Text) {
      final text = node.data;
      if (text.isNotEmpty) {
        // dom.Text.data is already entity-decoded by package:html — do NOT
        // decode again, or sequences like "&amp;amp;" get double-unescaped.
        spans.add(TextSpan(text: text, style: parentStyle));
      }
      return;
    }

    if (node is! dom.Element) return;

    switch (node.localName) {
      case 'br':
        spans.add(const TextSpan(text: '\n'));
        break;
      case 'b':
      case 'strong':
        _parseChildren(
            node, spans, parentStyle.copyWith(fontWeight: FontWeight.bold));
        break;
      case 'i':
      case 'em':
        _parseChildren(
            node, spans, parentStyle.copyWith(fontStyle: FontStyle.italic));
        break;
      case 'u':
        _parseChildren(node, spans,
            parentStyle.copyWith(decoration: TextDecoration.underline));
        break;
      case 'a':
        final linkText = node.text.trim();
        final href = node.attributes['href'] ?? '';
        final style = parentStyle.merge(widget.linkStyle);
        if (linkText.isNotEmpty && href.isNotEmpty) {
          final recognizer = TapGestureRecognizer()
            ..onTap = () => _openUrl(href);
          _recognizers.add(recognizer);
          spans.add(TextSpan(
            text: linkText,
            style: style,
            recognizer: recognizer,
          ));
        } else if (linkText.isNotEmpty) {
          spans.add(TextSpan(text: linkText, style: style));
        } else {
          _parseChildren(node, spans, style);
        }
        break;
      case 'p':
        _parseChildren(node, spans, parentStyle);
        spans.add(const TextSpan(text: '\n\n'));
        break;
      case 'div':
        _parseChildren(node, spans, parentStyle);
        spans.add(const TextSpan(text: '\n'));
        break;
      case 'span':
      case 'font':
        _parseChildren(node, spans, parentStyle);
        break;
      case 'ol':
        _parseList(node, spans, parentStyle, ordered: true);
        break;
      case 'ul':
        _parseList(node, spans, parentStyle, ordered: false);
        break;
      case 'li':
        spans.add(const TextSpan(text: '  • '));
        _parseChildren(node, spans, parentStyle);
        spans.add(const TextSpan(text: '\n'));
        break;
      case 'img':
        // Inline images are not supported in rich text; show alt text.
        final alt = node.attributes['alt'] ?? '';
        if (alt.isNotEmpty) {
          spans.add(TextSpan(text: '[$alt]', style: parentStyle));
        }
        break;
      case 'hr':
        spans.add(const TextSpan(text: '\n────────\n'));
        break;
      default:
        _parseChildren(node, spans, parentStyle);
        break;
    }
  }

  /// Render list items, prefixing ordered lists with a number and unordered
  /// lists with a bullet.
  void _parseList(
      dom.Element list, List<InlineSpan> spans, TextStyle parentStyle,
      {required bool ordered}) {
    var index = 1;
    for (final child in list.nodes) {
      if (child is dom.Element && child.localName == 'li') {
        final marker = ordered ? '  $index. ' : '  • ';
        spans.add(TextSpan(text: marker, style: parentStyle));
        _parseChildren(child, spans, parentStyle);
        spans.add(const TextSpan(text: '\n'));
        if (ordered) index++;
      } else if (child is dom.Element &&
          (child.localName == 'ul' || child.localName == 'ol')) {
        // Nested list — indent and recurse.
        _parseList(child, spans, parentStyle, ordered: child.localName == 'ol');
      } else {
        _parseNode(child, spans, parentStyle);
      }
    }
  }

  Future<void> _openUrl(String href) async {
    final uri = Uri.tryParse(href);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('=== HtmlRichText: failed to open $href: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_root case TextSpan(:final text, children: final children)
        when (text == null || text.isEmpty) &&
            (children == null || children.isEmpty)) {
      return const SizedBox.shrink();
    }
    return RichText(
      text: _root,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
