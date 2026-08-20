import 'package:fa_kit/fa_kit.dart' as fa;

class FANotification {
  final String id;
  final String author;
  final String displayName;
  final String avatarUrl;
  final String title;
  final String type;
  final String datetime;
  final String naturalDatetime;
  final String url;

  FANotification({
    required this.id,
    required this.author,
    required this.displayName,
    required this.avatarUrl,
    required this.title,
    required this.type,
    required this.datetime,
    required this.naturalDatetime,
    required this.url,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'title': title,
        'type': type,
        'datetime': datetime,
        'naturalDatetime': naturalDatetime,
        'url': url,
      };

  factory FANotification.fromJson(Map<String, dynamic> json) => FANotification(
        id: json['id'] as String,
        author: json['author'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String? ?? '',
        title: json['title'] as String? ?? '',
        type: json['type'] as String? ?? 'fave',
        datetime: json['datetime'] as String? ?? '',
        naturalDatetime: json['naturalDatetime'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );

  factory FANotification.fromFAHeader(
      fa.FANotificationHeader header, String type) {
    return FANotification(
      id: header.id.toString(),
      author: header.author,
      displayName: header.displayAuthor,
      avatarUrl: fa.FAURLs.avatarUrl(header.author) ?? '',
      title: header.title,
      // type: 'submission_comment' | 'journal_comment' | 'shout' | 'journal'
      type: type,
      datetime: header.naturalDatetime,
      naturalDatetime: header.naturalDatetime,
      url: header.url.toString(),
    );
  }

  // ── Legacy parser (deprecated, kept for backward compat) ──

  static List<FANotification> parseNotifications(String htmlString) {
    final page = fa.FANotificationsPage.parse(
        htmlString, Uri.parse('https://www.furaffinity.net/msg/others/'));
    final result = <FANotification>[];
    for (final h in page.submissionCommentHeaders) {
      result.add(FANotification.fromFAHeader(h, 'submission_comment'));
    }
    for (final h in page.journalCommentHeaders) {
      result.add(FANotification.fromFAHeader(h, 'journal_comment'));
    }
    for (final h in page.shoutHeaders) {
      result.add(FANotification.fromFAHeader(h, 'shout'));
    }
    for (final h in page.journalHeaders) {
      result.add(FANotification.fromFAHeader(h, 'journal'));
    }
    return result;
  }
}
