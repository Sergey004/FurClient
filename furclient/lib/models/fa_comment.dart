import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;

class FAComment {
  final String id;
  final String author;
  final String avatarUrl;
  final String text;
  final String time;
  final int indentLevel;

  FAComment({
    required this.id,
    required this.author,
    required this.avatarUrl,
    required this.text,
    required this.time,
    this.indentLevel = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'avatarUrl': avatarUrl,
        'text': text,
        'time': time,
      };

  factory FAComment.fromJson(Map<String, dynamic> json) => FAComment(
        id: json['id'] as String,
        author: json['author'] as String,
        avatarUrl: json['avatarUrl'] as String? ?? '',
        text: json['text'] as String? ?? '',
        time: json['time'] as String? ?? '',
      );

  /// Parse comments — 1:1 copy of fa_kit logic, mapped to FAComment model.
  static List<FAComment> parseComments(String htmlString) {
    final document = html_parser.parse(htmlString);
    final comments = <FAComment>[];
    final commentElements = document.querySelectorAll(
        'div.comment-container, div.comment, li.comment');

    debugPrint('=== parseComments: found ${commentElements.length} comment elements');

    for (final commentEl in commentElements) {
      try {
        // Skip hidden comments
        final hiddenText = commentEl.querySelector('.comment-hidden, .hidden-comment');
        if (hiddenText != null) continue;

        // cid from outerHtml
        final cidMatch = RegExp(r'cid=(\d+)').firstMatch(commentEl.outerHtml);
        final cid = int.tryParse(cidMatch?.group(1) ?? '') ?? 0;

        // Indentation
        final indentEl = commentEl.querySelector('.comment-indentation, .comment-avatar');
        int indentation = 0;
        if (indentEl != null) {
          final widthAttr = indentEl.attributes['width'] ??
              indentEl.attributes['data-indentation'] ?? '0';
          indentation = (double.tryParse(widthAttr) ?? 0).toInt() ~/ 16;
        }

        // Author username
        final authorLink = commentEl.querySelector('a.comment-username, a[href*="/user/"]');
        final author = authorLink != null
            ? (RegExp(r'/user/([^/]+)/').firstMatch(
                authorLink.attributes['href'] ?? '')?.group(1) ?? '')
            : '';

        // Date
        final dateEl = commentEl.querySelector('span.comment-date, span.popup_date');
        final time = dateEl?.attributes['title'] ??
            dateEl?.attributes['datetime'] ??
            dateEl?.text.trim() ?? '';

        // Comment text
        final messageEl = commentEl.querySelector('div.comment-text, div.comment_message');
        final text = messageEl?.text.trim() ?? '';

        if (text.isNotEmpty || cid > 0) {
          comments.add(FAComment(
            id: cid > 0 ? '$cid' : '',
            author: author.isNotEmpty ? author : 'Anonymous',
            avatarUrl: '',
            text: text,
            time: time,
            indentLevel: indentation,
          ));
        }
      } catch (e) {
        debugPrint('=== parseComments skip: $e');
      }
    }

    debugPrint('=== parseComments: parsed ${comments.length} comments');
    return comments;
  }
}
