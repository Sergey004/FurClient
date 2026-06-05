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

  /// Parse comments with multi-strategy selector fallback.
  /// FA has changed HTML structure multiple times, so we try several
  /// strategies in order until we find comment elements.
  static List<FAComment> parseComments(String htmlString) {
    final document = html_parser.parse(htmlString);
    final comments = <FAComment>[];

    // ── Strategy 1: FAKit-style selectors (div.comment-container, etc.) ──
    var commentElements = document.querySelectorAll(
        'div.comment-container, div.comment, li.comment');

    // ── Strategy 2: section-based layout (FA modern redesign) ──
    if (commentElements.isEmpty) {
      debugPrint('=== parseComments: strategy 1 empty, trying section selectors');
      commentElements = document.querySelectorAll(
          'section.comment, section.comment-container, article.comment');
    }

    // ── Strategy 3: data attributes ──
    if (commentElements.isEmpty) {
      debugPrint('=== parseComments: strategy 2 empty, trying data attribute selectors');
      commentElements = document.querySelectorAll(
          '[data-comment-id], [data-cid], div[id^="cid-"], section[id^="cid-"]');
    }

    // ── Strategy 4: Broad class-based fallback ──
    if (commentElements.isEmpty) {
      debugPrint('=== parseComments: strategy 3 empty, trying broad class selectors');
      commentElements = document.querySelectorAll(
          'div[class*="comment_container"], '
          'div[class*="comment-"], '
          'div[class*="comment_"], '
          'tr.comment');
    }

    // ── Strategy 5: Last resort — find #comments section and grab direct children ──
    if (commentElements.isEmpty) {
      debugPrint('=== parseComments: strategy 4 empty, trying #comments section children');
      final commentsSection = document.querySelector('#comments') ??
          document.querySelector('section.comments') ??
          document.querySelector('.comments-section') ??
          document.querySelector('div.comments');
      if (commentsSection != null) {
        // Try to find any nested div that looks like a comment block
        commentElements = commentsSection.querySelectorAll(
            'div[id], section[id], div[class*="comment"]');
      }
    }

    debugPrint('=== parseComments: found ${commentElements.length} comment elements');

    // If still nothing, dump relevant HTML for debugging
    if (commentElements.isEmpty) {
      final htmlLower = htmlString.toLowerCase();
      final commentPos = htmlLower.indexOf('comment');
      if (commentPos > 0) {
        final start = commentPos > 300 ? commentPos - 300 : 0;
        final end = (commentPos + 3000 < htmlString.length)
            ? commentPos + 3000
            : htmlString.length;
        debugPrint('=== parseComments: NO elements found. HTML around "comment":');
        debugPrint('=== ${htmlString.substring(start, end)}');
      } else {
        debugPrint('=== parseComments: NO elements found. HTML length=${htmlString.length}');
      }
      return comments;
    }

    for (final commentEl in commentElements) {
      try {
        // Skip hidden comments
        final hiddenText =
            commentEl.querySelector('.comment-hidden, .hidden-comment');
        if (hiddenText != null) continue;

        // cid from outerHtml — look for cid=NNN pattern
        final cidMatch = RegExp(r'cid[=-](\d+)').firstMatch(commentEl.outerHtml);
        final cid = int.tryParse(cidMatch?.group(1) ?? '') ?? 0;

        // Also try id attribute directly
        final idAttr = commentEl.id; // e.g. "cid-123456"
        final idNum = idAttr.isNotEmpty
            ? int.tryParse(RegExp(r'\d+').firstMatch(idAttr)?.group(0) ?? '') ?? cid
            : cid;
        final finalCid = idNum > 0 ? idNum : cid;

        // Indentation
        final indentEl = commentEl.querySelector(
            '.comment-indentation, .comment-avatar, .comment-avatar-col, td.indentation');
        int indentation = 0;
        if (indentEl != null) {
          final widthAttr = indentEl.attributes['width'] ??
              indentEl.attributes['data-indentation'] ?? '0';
          indentation = (double.tryParse(widthAttr) ?? 0).toInt() ~/ 16;
        }
        // Also check margin-left on comment-content
        if (indentation == 0) {
          final contentEl = commentEl.querySelector(
              '.comment-content, .comment-body-col, .comment-body');
          if (contentEl != null) {
            final style = contentEl.attributes['style'] ?? '';
            final mlMatch = RegExp(r'margin-left:\s*(\d+)px').firstMatch(style);
            if (mlMatch != null) {
              indentation =
                  (double.tryParse(mlMatch.group(1) ?? '0') ?? 0).toInt() ~/ 16;
            }
          }
        }

        // Author username — multiple strategies
        String author = '';
        final authorLink = commentEl.querySelector(
            'a.comment-username, '
            'a.link-username, '
            'a[href*="/user/"]') ??
            commentEl.querySelector('a[href*="furaffinity.net/user/"]');
        if (authorLink != null) {
          author = RegExp(r'/user/([^/?#]+)/')
                  .firstMatch(authorLink.attributes['href'] ?? '')
                  ?.group(1) ??
              authorLink.text.trim();
        }

        // Avatar URL
        final avatarImg = commentEl.querySelector(
                '.comment-avatar img, .comment-avatar-col img, td.avatar img') ??
            commentEl.querySelector('img.avatar, img[class*="avatar"]');
        final avatarUrl = avatarImg?.attributes['src'] ?? '';

        // Date
        final dateEl = commentEl.querySelector(
            'span.comment-date, '
            'span.popup_date, '
            'span.posted_date, '
            'span.date, '
            'time');
        final time = dateEl?.attributes['title'] ??
            dateEl?.attributes['datetime'] ??
            dateEl?.text.trim() ??
            '';

        // Comment text — multiple strategies
        String text = '';
        final messageEl = commentEl.querySelector(
            'div.comment-text, '
            'div.comment_message, '
            'div.comment-content, '
            'div.comment-body, '
            '.comment-body-col .comment-text') ??
            commentEl.querySelector('.comment-body-col');
        if (messageEl != null) {
          // If comment-body-col was selected, try to get just the text part
          if (messageEl.classes.contains('comment-body-col')) {
            final innerText = messageEl.querySelector('.comment-text, .comment-body');
            text = innerText?.text.trim() ?? messageEl.text.trim();
          } else {
            text = messageEl.text.trim();
          }
        }
        // Last resort: just grab all text after the header
        if (text.isEmpty) {
          final allText = commentEl.text.trim();
          // Remove the author and date from the text
          text = allText
              .replaceFirst(RegExp('^$author'), '')
              .replaceFirst(RegExp('^$time'), '')
              .trim();
        }

        if (text.isNotEmpty || finalCid > 0) {
          comments.add(FAComment(
            id: finalCid > 0 ? '$finalCid' : '',
            author: author.isNotEmpty ? author : 'Anonymous',
            avatarUrl: avatarUrl,
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
