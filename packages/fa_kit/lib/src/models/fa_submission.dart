import 'dynamic_thumbnail.dart';
import 'fa_comment.dart';
import '../pages/fa_submission_page.dart';
import '../pages/fa_submissions_page.dart';

/// Submission preview for the browse/submissions list.
class FASubmissionPreview implements Comparable<FASubmissionPreview> {
  final int sid;
  final Uri url;
  final Uri thumbnailUrl;
  final double thumbnailWidthOnHeightRatio;
  final String title;
  final String author;
  final String displayAuthor;
  final DynamicThumbnail dynamicThumbnail;

  FASubmissionPreview({
    required this.sid,
    required this.url,
    required this.thumbnailUrl,
    required this.thumbnailWidthOnHeightRatio,
    required this.title,
    required this.author,
    required this.displayAuthor,
  }) : dynamicThumbnail = DynamicThumbnail(thumbnailUrl);

  /// Create from a parsed submissions page item.
  factory FASubmissionPreview.fromPageItem(FASubmissionsPageItem item) {
    return FASubmissionPreview(
      sid: item.sid,
      url: item.url,
      thumbnailUrl: item.thumbnailUrl,
      thumbnailWidthOnHeightRatio: item.thumbnailWidthOnHeightRatio,
      title: item.title,
      author: item.author,
      displayAuthor: item.displayAuthor,
    );
  }

  @override
  int compareTo(FASubmissionPreview other) => other.sid.compareTo(sid);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FASubmissionPreview && sid == other.sid;

  @override
  int get hashCode => sid.hashCode;
}

/// A full submission with all details.
class FASubmission {
  final Uri url;
  final Uri previewImageUrl;
  final Uri? fullResolutionMediaUrl;
  final double widthOnHeightRatio;
  final FASubmissionPageMetadata metadata;
  final String htmlDescription;
  final bool isFavorite;
  final Uri? favoriteUrl;
  final List<FAComment> comments;
  final int? targetCommentId;
  final bool acceptsNewComments;

  FASubmission({
    required this.url,
    required this.previewImageUrl,
    this.fullResolutionMediaUrl,
    required this.widthOnHeightRatio,
    required this.metadata,
    required this.htmlDescription,
    required this.isFavorite,
    this.favoriteUrl,
    required this.comments,
    this.targetCommentId,
    required this.acceptsNewComments,
  });

  /// Create from a parsed submission page, building the comment tree.
  factory FASubmission.fromPage(FASubmissionPage page, Uri url) {
    return FASubmission(
      url: url,
      previewImageUrl: page.previewImageUrl,
      fullResolutionMediaUrl: page.fullResolutionMediaUrl,
      widthOnHeightRatio: page.widthOnHeightRatio,
      metadata: page.metadata,
      htmlDescription: page.htmlDescription,
      isFavorite: page.isFavorite,
      favoriteUrl: page.favoriteUrl,
      comments: buildCommentsTree(page.comments),
      targetCommentId: page.targetCommentId,
      acceptsNewComments: page.acceptsNewComments,
    );
  }

  /// Convenience getters.
  String get author => metadata.author;
  String get displayAuthor => metadata.displayAuthor;
  String get title => metadata.title;
  DateTime get datetime => metadata.datetime;
  String get naturalDatetime => metadata.naturalDatetime;
  int get favoriteCount => metadata.favoriteCount;

  /// Create a copy with toggled favorite status.
  FASubmission withToggledFavorite({required bool isFavorite, Uri? favoriteUrl}) {
    return FASubmission(
      url: url,
      previewImageUrl: previewImageUrl,
      fullResolutionMediaUrl: fullResolutionMediaUrl,
      widthOnHeightRatio: widthOnHeightRatio,
      metadata: metadata,
      htmlDescription: htmlDescription,
      isFavorite: isFavorite,
      favoriteUrl: favoriteUrl,
      comments: comments,
      targetCommentId: targetCommentId,
      acceptsNewComments: acceptsNewComments,
    );
  }
}
