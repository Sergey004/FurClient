import 'dart:convert';

import 'submission.dart';

/// Превью сабмишена, которое едет в payload уведомления.
///
/// Порталог из эталона (FurAffinityApp, 28–29 окт): превью кодируется
/// JSON-СТРОКОЙ, потому что строка переживает передачу через userInfo на
/// Android, а сбой кодирования/декодирования превью стоит только самого
/// превью — запись уведомления при этом сохраняется.
class SubmissionPreview {
  final String id;
  final String title;
  final String author;
  final String displayName;
  final String thumbnailUrl;
  final String url;
  final String rating;

  const SubmissionPreview({
    required this.id,
    required this.title,
    required this.author,
    required this.displayName,
    required this.thumbnailUrl,
    required this.url,
    required this.rating,
  });

  factory SubmissionPreview.fromSubmission(Submission s) =>
      SubmissionPreview(
        id: s.id,
        title: s.title,
        author: s.author,
        displayName: s.displayName.isNotEmpty ? s.displayName : s.author,
        thumbnailUrl: s.thumbnailUrl,
        url: s.url.isNotEmpty
            ? s.url
            : 'https://www.furaffinity.net/view/${s.id}/',
        rating: s.rating,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'displayName': displayName,
        'thumbnailUrl': thumbnailUrl,
        'url': url,
        'rating': rating,
      };

  /// JSON-строка (как в эталоне). null — если превью не закодировалось.
  String? encode() {
    try {
      return jsonEncode(toJson());
    } catch (_) {
      return null;
    }
  }

  static SubmissionPreview? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final map = jsonDecode(json);
      if (map is! Map) return null;
      return SubmissionPreview(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        author: map['author']?.toString() ?? '',
        displayName: map['displayName']?.toString() ?? '',
        thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
        url: map['url']?.toString() ?? '',
        rating: map['rating']?.toString() ?? 'general',
      );
    } catch (_) {
      // Битый/старый preview — молча теряем превью, запись цела.
      return null;
    }
  }
}
