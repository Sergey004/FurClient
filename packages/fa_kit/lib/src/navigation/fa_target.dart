import '../models/fa_submission.dart';
import '../pages/fa_submission_page.dart';
import '../pages/fa_urls.dart';

/// Navigation target for any FurAffinity page.
///
/// Use [FATarget.parse] to determine the page type from a URL.
/// Supports deep links (e.g. `furaffinity://view/12345/`).
class FATarget {
  final FATargetType type;
  final Uri url;

  /// Optional preview data for the target (used for optimistic UI updates).
  final FASubmissionPreview? previewData;

  /// Optional metadata for submission (used for detail views).
  final FASubmissionPageMetadata? metadata;

  const FATarget({
    required this.type,
    required this.url,
    this.previewData,
    this.metadata,
  });

  /// Parse a FurAffinity URL into a [FATarget].
  ///
  /// Returns null if the URL does not match any known page type.
  /// Supports both HTTPS URLs and custom scheme deep links.
  static FATarget? parse(Uri url) {
    final normalizedUrl = _normalizeUrl(url);

    if (FAURLs.isSubmissionUrl(normalizedUrl)) {
      return FATarget(type: FATargetType.submission, url: normalizedUrl);
    }
    if (FAURLs.isNoteUrl(normalizedUrl)) {
      return FATarget(type: FATargetType.note, url: normalizedUrl);
    }
    if (FAURLs.isJournalUrl(normalizedUrl)) {
      return FATarget(type: FATargetType.journal, url: normalizedUrl);
    }
    if (FAURLs.isUserUrl(normalizedUrl)) {
      return FATarget(type: FATargetType.user, url: normalizedUrl);
    }
    if (FAURLs.isGalleryUrl(normalizedUrl)) {
      return FATarget(type: FATargetType.gallery, url: normalizedUrl);
    }
    if (FAURLs.isFavoritesUrl(normalizedUrl)) {
      return FATarget(type: FATargetType.favorites, url: normalizedUrl);
    }
    if (FAURLs.isJournalsListUrl(normalizedUrl)) {
      return FATarget(type: FATargetType.journals, url: normalizedUrl);
    }
    if (FAURLs.isWatchlistUrl(normalizedUrl)) {
      return FATarget(type: FATargetType.watchlist, url: normalizedUrl);
    }

    return null;
  }

  /// Parse a URL string into a [FATarget].
  static FATarget? parseString(String urlString) {
    return parse(Uri.parse(urlString));
  }

  /// Create a submission target with preview data.
  factory FATarget.submission(Uri url, {FASubmissionPreview? previewData}) {
    return FATarget(
      type: FATargetType.submission,
      url: url,
      previewData: previewData,
    );
  }

  /// Create a user target with preview data.
  factory FATarget.user(Uri url, {FASubmissionPreview? previewData}) {
    return FATarget(
      type: FATargetType.user,
      url: url,
      previewData: previewData,
    );
  }

  /// Create a submission metadata target (for navigating from notification).
  factory FATarget.submissionMetadata(FASubmissionPageMetadata meta) {
    return FATarget(
      type: FATargetType.submissionMetadata,
      url: Uri.parse(FAURLs.homeUrl),
      metadata: meta,
    );
  }

  /// Normalize a deep link URL to a standard HTTPS FurAffinity URL.
  static Uri _normalizeUrl(Uri url) {
    if (url.scheme == 'https' || url.scheme == 'http') {
      return _withTrailingSlash(url);
    }

    // Handle custom schemes like furaffinity://view/12345/
    final path = url.path.startsWith('/') ? url.path : '/${url.path}';
    return _withTrailingSlash(Uri(
      scheme: 'https',
      host: 'www.furaffinity.net',
      path: path,
      fragment: url.fragment,
    ));
  }

  static Uri _withTrailingSlash(Uri url) {
    if (url.path.isEmpty || url.path.endsWith('/')) return url;
    return url.replace(path: '${url.path}/');
  }

  /// Extract the submission ID if this is a submission target.
  int? get submissionId => FAURLs.submissionIdFrom(url);

  /// Extract the journal ID if this is a journal target.
  int? get journalId => FAURLs.journalIdFrom(url);

  /// Extract the note ID if this is a note target.
  int? get noteId => FAURLs.noteIdFrom(url);

  /// Extract the username if this is a user/gallery/favorites/journals target.
  String? get username => FAURLs.usernameFrom(url);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FATarget && type == other.type && url == other.url;

  @override
  int get hashCode => Object.hash(type, url);

  @override
  String toString() => 'FATarget($type, $url)';
}

/// Types of FurAffinity pages that can be navigated to.
enum FATargetType {
  /// A submission detail page (`/view/{sid}/`).
  submission,

  /// A note detail page (`/msg/pms/{id}/`).
  note,

  /// A journal detail page (`/journal/{jid}/`).
  journal,

  /// A user profile page (`/user/{username}/`).
  user,

  /// A gallery page (`/gallery/{username}/`).
  gallery,

  /// A favorites page (`/favorites/{username}/`).
  favorites,

  /// A journals list page (`/journals/{username}/`).
  journals,

  /// A watchlist page (`/watchlist/to/{username}/` or `/watchlist/by/{username}/`).
  watchlist,

  /// Submission metadata (navigated from notification, no direct URL).
  submissionMetadata,
}
