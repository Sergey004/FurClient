import '../pages/fa_urls.dart';
import '../pages/fa_watchlist_page.dart';
import '../models/fa_submission.dart';
import '../models/fa_journal.dart';
import '../models/fa_note.dart';
import '../models/fa_note_preview.dart';
import '../models/fa_notification_preview.dart';
import '../models/fa_user.dart';
import '../models/fa_user_gallery_like.dart';
import '../models/fa_user_journals.dart';
import '../models/fa_watchlist.dart';

/// Notes box types.
enum NotesBox { inbox, sent, archive, trash }

/// Errors from OnlineFASession.
class FASessionError implements Exception {
  final FASessionErrorType type;
  final String? sourceUrl;
  final String? underlyingError;
  final String? systemMessage;

  const FASessionError({
    required this.type,
    this.sourceUrl,
    this.underlyingError,
    this.systemMessage,
  });

  factory FASessionError.parsing({
    String? sourceUrl,
    String? underlyingError,
  }) {
    return FASessionError(
      type: FASessionErrorType.parsingError,
      sourceUrl: sourceUrl,
      underlyingError: underlyingError,
    );
  }

  factory FASessionError.systemMessage(String message) {
    return FASessionError(
      type: FASessionErrorType.systemMessageResponse,
      systemMessage: message,
    );
  }

  @override
  String toString() {
    switch (type) {
      case FASessionErrorType.parsingError:
        return 'FASessionError: Parsing error at ${sourceUrl ?? "unknown"} - ${underlyingError ?? "unknown"}';
      case FASessionErrorType.internalInconsistency:
        return 'FASessionError: Internal inconsistency';
      case FASessionErrorType.systemMessageResponse:
        return 'FASessionError: System message - ${systemMessage ?? "unknown"}';
    }
  }
}

enum FASessionErrorType {
  parsingError,
  internalInconsistency,
  systemMessageResponse,
}

/// The main FA session interface.
///
/// All interactions with FurAffinity go through this abstract class.
/// Use [OnlineFASession] for real network requests.
abstract class FASession {
  String get username;
  String get displayUsername;

  // ── Submissions Feed ──
  Future<List<FASubmissionPreview>> submissionPreviews({int? fromSid});
  Future<void> nukeSubmissions();

  // ── Gallery ──
  Future<FAUserGalleryLike> galleryLikeForUrl(Uri url);

  // ── Submission Detail ──
  Future<FASubmission> submissionForUrl(Uri url);
  Future<FASubmission> toggleFavorite(FASubmission submission);
  Future<FASubmission> postCommentOnSubmission({
    required FASubmission submission,
    int? replyToCid,
    required String contents,
  });

  // ── Journals ──
  Future<FAUserJournals> journalsForUrl(Uri url);
  Future<FAJournal> journalForUrl(Uri url);
  Future<FAJournal> postCommentOnJournal({
    required FAJournal journal,
    int? replyToCid,
    required String contents,
  });

  // ── Notes ──
  Future<List<FANotePreview>> notePreviews({required NotesBox box});
  Future<FANote> noteForUrl(Uri url);
  Future<void> sendNote({
    required String toUsername,
    required String subject,
    required String message,
  });
  Future<void> sendNoteWithKey({
    required String apiKey,
    required String toUsername,
    required String subject,
    required String message,
  });
  Future<List<FANotePreview>> moveNotes({
    required List<FANotePreview> notes,
    required NotesBox toBox,
  });
  Future<List<FANotePreview>> markNotesAsUnread(List<FANotePreview> notes);

  // ── Notifications ──
  Future<FANotificationPreviews> notificationPreviews();
  Future<void> deleteSubmissionPreviews(List<FASubmissionPreview> previews);
  Future<FANotificationPreviews> deleteSubmissionCommentNotifications(
      List<FANotificationPreview> notifications);
  Future<FANotificationPreviews> deleteJournalCommentNotifications(
      List<FANotificationPreview> notifications);
  Future<FANotificationPreviews> deleteShoutNotifications(
      List<FANotificationPreview> notifications);
  Future<FANotificationPreviews> deleteJournalNotifications(
      List<FANotificationPreview> notifications);
  Future<FANotificationPreviews> nukeAllSubmissionCommentNotifications();
  Future<FANotificationPreviews> nukeAllJournalCommentNotifications();
  Future<FANotificationPreviews> nukeAllShoutNotifications();
  Future<FANotificationPreviews> nukeAllJournalNotifications();

  // ── Users ──
  Future<FAUser> userForUrl(Uri url);
  Future<FAUser> toggleWatch(FAUser user);

  /// Fetch watchlist with explicit parameters.
  Future<FAWatchlist> watchlist({
    required String username,
    required int page,
    required FAWatchDirection direction,
  });

  /// Fetch watchlist by parsing a URL (convenience method).
  Future<FAWatchlist> watchlistForUrl(Uri url);

  // ── Convenience Methods ──
  Future<FAUserGalleryLike> galleryLikeForUser(String username) =>
      galleryLikeForUrl(Uri.parse(FAURLs.galleryUrl(username)));

  Future<FASubmission> submissionForPreview(FASubmissionPreview preview) =>
      submissionForUrl(preview.url);

  Future<FAJournal> journalForNotification(FANotificationPreview notification) =>
      journalForUrl(notification.url);

  Future<FANote> noteForPreview(FANotePreview preview) =>
      noteForUrl(preview.noteUrl);

  Future<FAUser> userForName(String username) =>
      userForUrl(Uri.parse(FAURLs.userUrl(username)));

  /// Search for submissions.
  Future<List<FASubmissionPreview>> search(String query, {int page = 1});

  /// Convenience: fetch favorites for a user.
  Future<FAUserGalleryLike> favoritesForUser(String username) =>
      galleryLikeForUrl(Uri.parse(FAURLs.favoritesUrl(username)));

  /// Convenience: fetch scraps for a user.
  Future<FAUserGalleryLike> scrapsForUser(String username) =>
      galleryLikeForUrl(Uri.parse(FAURLs.galleryUrl(username)));
}
