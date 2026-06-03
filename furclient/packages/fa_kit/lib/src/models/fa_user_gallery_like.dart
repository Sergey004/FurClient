import '../pages/fa_page.dart';
import '../pages/fa_submissions_page.dart';
import '../pages/fa_user_gallery_like_page.dart';
import 'fa_submission.dart';

/// A folder group in a user's gallery.
class FolderGroup {
  final String? title;
  final List<FAFolder> folders;
  final String id;

  FolderGroup({
    required this.title,
    required this.folders,
    required this.id,
  });
}

/// A user's gallery/scrap/favorites page.
class FAUserGalleryLike {
  final Uri url;
  final String displayAuthor;
  final List<FASubmissionPreview> previews;
  final Uri? nextPageUrl;
  final List<FolderGroup> folderGroups;

  FAUserGalleryLike({
    required this.url,
    required this.displayAuthor,
    required this.previews,
    this.nextPageUrl,
    required this.folderGroups,
  });

  /// Create from a parsed gallery page.
  factory FAUserGalleryLike.fromPage(FAUserGalleryLikePage page, Uri url) {
    return FAUserGalleryLike(
      url: url,
      displayAuthor: page.displayAuthor,
      previews: page.previews
          .whereType<FASubmissionsPageItem>()
          .map(FASubmissionPreview.fromPageItem)
          .cast<FASubmissionPreview>()
          .toList(),
      nextPageUrl: page.nextPageUrl,
      folderGroups: page.folderGroups
          .map((g) => FolderGroup(
                title: g.title,
                folders: g.folders,
                id: g.id,
              ))
          .toList(),
    );
  }

  /// Create a copy with additional previews appended.
  FAUserGalleryLike appending(FAUserGalleryLike other) {
    return FAUserGalleryLike(
      url: url,
      displayAuthor: displayAuthor,
      previews: [...previews, ...other.previews],
      nextPageUrl: other.nextPageUrl,
      folderGroups: other.folderGroups.isNotEmpty ? other.folderGroups : folderGroups,
    );
  }
}

