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

    final cidElements = document.querySelectorAll('div[id^="cid-"]');
    for (final el in cidElements) {
      final id = el.id.replaceFirst('cid-', '');

      final authorLink = el.querySelector('a[href*="/user/"]');
      final author = authorLink?.text.trim() ?? 'Anonymous';

      final avatarEl = el.querySelector('img');
      final avatarUrl = avatarEl?.attributes['src'] ?? '';

      final contentEl = el.querySelector('div.comment-content');
      final text = contentEl?.text.trim() ?? '';

      final dateEl = el.querySelector('span.popup_date');
      final time = dateEl?.attributes['title'] ?? 'Unknown';

      comments.add(FAComment(
        id: id,
        author: author,
        avatarUrl: avatarUrl,
        text: text,
        time: time,
      ));
    }

    return comments;
  }
}
