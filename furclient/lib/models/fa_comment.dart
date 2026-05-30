import 'package:html/parser.dart' as html_parser;

class FAComment {
  final String id;
  final String author;
  final String avatarUrl;
  final String text;
  final String time;

  FAComment({
    required this.id,
    required this.author,
    required this.avatarUrl,
    required this.text,
    required this.time,
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

  static List<FAComment> parseComments(String htmlString) {
    final document = html_parser.parse(htmlString);
    final comments = <FAComment>[];

    // FA comment selectors — try multiple strategies
    // Strategy 1: div[id^="cid-"] — each comment has an id like cid-123456
    var commentEls = document.querySelectorAll('div[id^="cid-"]');

    // Strategy 2: .comment-ancestor > .comment
    if (commentEls.isEmpty) {
      commentEls = document.querySelectorAll('section.comments-list .comment');
    }

    // Strategy 3: any element with class "comment" inside the comments section
    if (commentEls.isEmpty) {
      final section = document.querySelector('section[id^="comments"]') ??
          document.querySelector('.comments-section') ??
          document.querySelector('#comments');
      if (section != null) {
        commentEls = section.querySelectorAll('.comment');
      }
    }

    // Strategy 4: broadest — any .comment on the page
    if (commentEls.isEmpty) {
      commentEls = document.querySelectorAll('.comment');
    }

    for (final el in commentEls) {
      try {
        // ID
        final id = el.id.replaceFirst('cid-', '');

        // Author — try multiple selectors
        String author = 'Anonymous';
        final authorLink = el.querySelector('a.comment-username') ??
            el.querySelector('.comment-date a[href*="/user/"]') ??
            el.querySelector('a[href*="/user/"]');
        if (authorLink != null) {
          author = authorLink.text.trim();
          if (author.isEmpty) {
            final href = authorLink.attributes['href'] ?? '';
            final m = RegExp(r'/user/([^/]+)/').firstMatch(href);
            author = m?.group(1) ?? 'Anonymous';
          }
        }

        // Avatar — try multiple selectors
        String avatarUrl = '';
        final avatarEl = el.querySelector('.comment-avatar img') ??
            el.querySelector('img.avatar') ??
            el.querySelector('img');
        if (avatarEl != null) {
          avatarUrl = avatarEl.attributes['src'] ?? '';
          if (avatarUrl.startsWith('//')) avatarUrl = 'https:$avatarUrl';
        }

        // Comment text — try multiple selectors
        String text = '';
        final contentEl = el.querySelector('.comment-content') ??
            el.querySelector('.comment-text') ??
            el.querySelector('.comment-body .text') ??
            el.querySelector('div[class*="comment"] div[class*="content"]') ??
            el.querySelector('div[class*="comment"] p');
        if (contentEl != null) {
          text = contentEl.text.trim();
        }
        // Last resort: get all text from the comment, minus author/date
        if (text.isEmpty) {
          final bodyEl = el.querySelector('.comment-body');
          if (bodyEl != null) {
            // Remove date/author parts to get just the text
            text = bodyEl.text.trim();
          } else {
            text = el.text.trim();
          }
        }

        // Date — try multiple selectors
        String time = '';
        final dateEl = el.querySelector('.comment-date .popup_date') ??
            el.querySelector('span.popup_date') ??
            el.querySelector('.comment-date') ??
            el.querySelector('time');
        if (dateEl != null) {
          time = dateEl.attributes['title'] ?? dateEl.text.trim();
        }

        if (text.isNotEmpty) {
          comments.add(FAComment(
            id: id,
            author: author,
            avatarUrl: avatarUrl,
            text: text,
            time: time,
          ));
        }
      } catch (e) {
        // Skip malformed comments
      }
    }

    return comments;
  }
}
