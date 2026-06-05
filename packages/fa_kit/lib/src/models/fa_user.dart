import 'fa_comment.dart';
import '../pages/fa_user_page.dart';

/// Watch data from a user profile.
class FAWatchDataModel {
  final Uri watchUrl;

  FAWatchDataModel({required this.watchUrl});

  /// Whether the current user is watching this user.
  bool get watching => watchUrl.path.contains('/unwatch/');
}

/// A FA user profile.
class FAUser {
  final String name;
  final String displayName;
  final Uri? bannerUrl;
  final String htmlDescription;
  final List<FAComment> shouts;
  final int? targetShoutId;
  final FAWatchDataModel? watchData;

  FAUser({
    required this.name,
    required this.displayName,
    this.bannerUrl,
    required this.htmlDescription,
    required this.shouts,
    this.targetShoutId,
    this.watchData,
  });

  /// Create from a parsed user page.
  factory FAUser.fromPage(FAUserPage page) {
    return FAUser(
      name: page.name,
      displayName: page.displayName,
      bannerUrl: page.bannerUrl,
      htmlDescription: page.htmlDescription,
      shouts: buildCommentsTree(page.shouts),
      targetShoutId: page.targetShoutId,
      watchData: page.watchData != null
          ? FAWatchDataModel(watchUrl: page.watchData!.watchUrl)
          : null,
    );
  }

  /// Create a copy with toggled watch status.
  FAUser withToggledWatch({required FAWatchDataModel? watchData}) {
    return FAUser(
      name: name,
      displayName: displayName,
      bannerUrl: bannerUrl,
      htmlDescription: htmlDescription,
      shouts: shouts,
      targetShoutId: targetShoutId,
      watchData: watchData,
    );
  }
}
