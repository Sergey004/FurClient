import '../pages/fa_watchlist_page.dart';

/// A watchlist page.
class FAWatchlist {
  final FAWatchlistUserModel? currentUser;
  final FAWatchDirection watchDirection;
  final List<FAWatchlistUserModel> users;
  final Uri? nextPageUrl;

  FAWatchlist({
    this.currentUser,
    required this.watchDirection,
    required this.users,
    this.nextPageUrl,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FAWatchlist &&
          currentUser == other.currentUser &&
          watchDirection == other.watchDirection &&
          users == other.users &&
          nextPageUrl == other.nextPageUrl;

  @override
  int get hashCode =>
      Object.hash(currentUser, watchDirection, users, nextPageUrl);

  /// Create from a parsed watchlist page.
  factory FAWatchlist.fromPage(FAWatchlistPage page) {
    return FAWatchlist(
      currentUser: page.currentUser != null
          ? FAWatchlistUserModel(
              name: page.currentUser!.name,
              displayName: page.currentUser!.displayName)
          : null,
      watchDirection: page.watchDirection,
      users: page.users
          .map((u) => FAWatchlistUserModel(
                name: u.name,
                displayName: u.displayName,
              ))
          .toList(),
      nextPageUrl: page.nextPageUrl,
    );
  }

  /// Create a copy with additional users appended.
  FAWatchlist appending(FAWatchlist other) {
    return FAWatchlist(
      currentUser: other.currentUser ?? currentUser,
      watchDirection: other.watchDirection,
      users: [...users, ...other.users],
      nextPageUrl: other.nextPageUrl,
    );
  }
}

/// A user in the watchlist.
class FAWatchlistUserModel {
  final String name;
  final String displayName;

  FAWatchlistUserModel({required this.name, required this.displayName});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FAWatchlistUserModel &&
          name == other.name &&
          displayName == other.displayName;

  @override
  int get hashCode => Object.hash(name, displayName);
}
