import 'package:html/parser.dart' as html_parser;

class FANotification {
  final String id;
  final String author;
  final String avatarUrl;
  final String title;
  final String type;
  final String datetime;
  final String url;

  FANotification({
    required this.id,
    required this.author,
    required this.avatarUrl,
    required this.title,
    required this.type,
    required this.datetime,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'avatarUrl': avatarUrl,
        'title': title,
        'type': type,
        'datetime': datetime,
        'url': url,
      };

  factory FANotification.fromJson(Map<String, dynamic> json) => FANotification(
        id: json['id'] as String,
        author: json['author'] as String,
        avatarUrl: json['avatarUrl'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? 'fave',
        datetime: json['datetime'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  static List<FANotification> parseNotifications(String htmlString) {
    final document = html_parser.parse(htmlString);
    final notifications = <FANotification>[];

    final notifElements = document.querySelectorAll('div[id^="notif-"]');
    for (final el in notifElements) {
      final id = el.id;

      final authorLink = el.querySelector('a[href*="/user/"]');
      final author = authorLink?.text.trim() ?? 'Unknown';

      final avatarEl = el.querySelector('img');
      final avatarUrl = avatarEl?.attributes['src'] ?? '';

      final titleText = el.text.trim();

      final dateEl = el.querySelector('.popup_date');
      final datetime =
          dateEl?.attributes['title'] ?? DateTime.now().toIso8601String();

      final linkEl = el.querySelector('a');
      final href = linkEl?.attributes['href'] ?? '';

      String type = 'fave';
      final classList = el.classes;
      if (classList.contains('notif-fave') ||
          titleText.toLowerCase().contains('favorited')) {
        type = 'fave';
      } else if (classList.contains('notif-comment') ||
          titleText.toLowerCase().contains('commented')) {
        type = 'comment';
      } else if (classList.contains('notif-watch') ||
          titleText.toLowerCase().contains('watched')) {
        type = 'watch';
      } else if (classList.contains('notif-journal') ||
          titleText.toLowerCase().contains('journal')) {
        type = 'journal';
      }

      notifications.add(FANotification(
        id: id,
        author: author,
        avatarUrl: avatarUrl,
        title: titleText,
        type: type,
        datetime: datetime,
        url: 'https://www.furaffinity.net$href',
      ));
    }

    return notifications;
  }
}
