import '../pages/fa_notifications_page.dart';

/// A notification preview.
class FANotificationPreview {
  final int id;
  final String author;
  final String displayAuthor;
  final String title;
  final DateTime datetime;
  final String naturalDatetime;
  final Uri url;

  FANotificationPreview({
    required this.id,
    required this.author,
    required this.displayAuthor,
    required this.title,
    required this.datetime,
    required this.naturalDatetime,
    required this.url,
  });

  /// Create from a parsed notification header.
  factory FANotificationPreview.fromHeader(FANotificationHeader header) {
    return FANotificationPreview(
      id: header.id,
      author: header.author,
      displayAuthor: header.displayAuthor,
      title: header.title,
      datetime: header.datetime,
      naturalDatetime: header.naturalDatetime,
      url: header.url,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FANotificationPreview && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Container for all notification types.
class FANotificationPreviews {
  final List<FANotificationPreview> submissionComments;
  final List<FANotificationPreview> journalComments;
  final List<FANotificationPreview> shouts;
  final List<FANotificationPreview> journals;

  FANotificationPreviews({
    required this.submissionComments,
    required this.journalComments,
    required this.shouts,
    required this.journals,
  });

  /// Create from a parsed notifications page.
  factory FANotificationPreviews.fromPage(FANotificationsPage page) {
    return FANotificationPreviews(
      submissionComments: page.submissionCommentHeaders
          .map(FANotificationPreview.fromHeader)
          .toList(),
      journalComments: page.journalCommentHeaders
          .map(FANotificationPreview.fromHeader)
          .toList(),
      shouts: page.shoutHeaders
          .map(FANotificationPreview.fromHeader)
          .toList(),
      journals: page.journalHeaders
          .map(FANotificationPreview.fromHeader)
          .toList(),
    );
  }
}
