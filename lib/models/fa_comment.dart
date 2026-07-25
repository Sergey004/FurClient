import 'package:fa_kit/fa_kit.dart' as fa;

class FAComment {
  final String id;
  final String author;
  final String displayName;
  final String avatarUrl;
  final String htmlText;
  final DateTime? datetime;
  final String naturalDatetime;
  final int indentLevel;
  final List<FAComment> replies;
  final bool isHidden;

  // Deprecated — kept for backward compatibility with UI that reads these.
  String get text => htmlText;
  String get time => naturalDatetime;

  FAComment({
    required this.id,
    required this.author,
    required this.displayName,
    required this.avatarUrl,
    required this.htmlText,
    required this.datetime,
    required this.naturalDatetime,
    this.indentLevel = 0,
    this.replies = const [],
    this.isHidden = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'htmlText': htmlText,
        'datetime': datetime?.toIso8601String(),
        'naturalDatetime': naturalDatetime,
        'indentLevel': indentLevel,
        'replies': replies.map((r) => r.toJson()).toList(),
        'isHidden': isHidden,
      };

  factory FAComment.fromJson(Map<String, dynamic> json) {
    return FAComment(
      id: json['id'] as String,
      author: json['author'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      htmlText: json['htmlText'] as String? ?? (json['text'] as String? ?? ''),
      datetime: json['datetime'] != null
          ? DateTime.tryParse(json['datetime'] as String)
          : null,
      naturalDatetime:
          json['naturalDatetime'] as String? ?? (json['time'] as String? ?? ''),
      indentLevel: json['indentLevel'] as int? ?? 0,
      replies: (json['replies'] as List<dynamic>?)
              ?.map((r) => FAComment.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      isHidden: json['isHidden'] as bool? ?? false,
    );
  }

  /// Build an app-level model from the FAKit tree.
  ///
  /// [faKomment] — a `FAVisibleComment` or `FAHiddenComment` from the
  /// FAKit comment tree (after `buildCommentsTree`).
  ///
  /// [avatarUrl] — computed separately (FA uses `a.furaffinity.net/{user}.gif`).
  factory FAComment.fromFAComment(fa.FAComment faKomment,
      {String avatarUrl = ''}) {
    if (faKomment is fa.FAVisibleComment) {
      return FAComment(
        id: faKomment.cid.toString(),
        author: faKomment.author,
        displayName: faKomment.displayAuthor,
        avatarUrl: avatarUrl,
        htmlText: faKomment.htmlMessage,
        datetime: faKomment.datetime,
        naturalDatetime: faKomment.naturalDatetime,
        indentLevel: faKomment.indentation,
        replies: faKomment.answers
            .map((r) => FAComment.fromFAComment(r, avatarUrl: avatarUrl))
            .toList(),
        isHidden: false,
      );
    } else if (faKomment is fa.FAHiddenComment) {
      return FAComment(
        id: faKomment.cid.toString(),
        author: '',
        displayName: '',
        avatarUrl: '',
        htmlText: faKomment.htmlMessage,
        datetime: null,
        naturalDatetime: '',
        indentLevel: faKomment.indentation,
        replies:
            faKomment.answers.map((r) => FAComment.fromFAComment(r)).toList(),
        isHidden: true,
      );
    }
    return FAComment(
      id: '0',
      author: '',
      displayName: '',
      avatarUrl: '',
      htmlText: '',
      datetime: null,
      naturalDatetime: '',
    );
  }
}
