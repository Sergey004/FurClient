import 'dart:convert';
import 'dart:io';
import '../pages/fa_urls.dart';
import '../pages/fa_page.dart';
import '../pages/fa_home_page.dart';
import '../pages/fa_submission_page.dart' as pages;
import '../pages/fa_submissions_page.dart';
import '../pages/fa_journal_page.dart' as pages;
import '../pages/fa_notifications_page.dart';
import '../pages/fa_note_page.dart';
import '../pages/fa_notes_page.dart';
import '../pages/fa_new_note_page.dart';
import '../pages/fa_user_page.dart' as pages;
import '../pages/fa_user_gallery_like_page.dart';
import '../pages/fa_user_journals_page.dart';
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
import '../utils/fa_logger.dart';
import 'http_data_source.dart';
import 'http_data_source_impl.dart';
import 'fa_session.dart';

/// Online FA session that performs real HTTP requests.
///
/// Authentication is cookie-based — the session cookie named "a" must be present.
class OnlineFASession extends FASession {
  static final _log = FALogger.loggerFor('OnlineFASession');

  @override
  final String username;
  @override
  final String displayUsername;
  final List<Cookie> _cookies;
  final HTTPDataSource _dataSource;

  OnlineFASession._({
    required this.username,
    required this.displayUsername,
    required List<Cookie> cookies,
    required HTTPDataSource dataSource,
  })  : _cookies = cookies,
        _dataSource = dataSource;

  /// Create a session from existing cookies.
  ///
  /// Validates the session by fetching the home page.
  /// Returns null if not logged in (no "a" cookie or invalid session).
  static Future<OnlineFASession?> fromCookies({
    required List<Cookie> cookies,
    HTTPDataSource? dataSource,
  }) async {
    final ds = dataSource ?? HttpDataSourceImpl();
    final effectiveDataSource = ds;

    // Check for session cookie "a"
    final hasSessionCookie = cookies.any((c) => c.name == 'a');
    if (!hasSessionCookie) return null;

    try {
      // Fetch home page to validate login
      final data = await effectiveDataSource.httpGet(
        url: Uri.parse(FAURLs.homeUrl),
        cookies: cookies,
      );
      final html = utf8.decode(data);

      // Check for system error/message pages
      final errorPage = FAPage.detectAndParse(html, Uri.parse(FAURLs.homeUrl));
      if (errorPage is FASystemErrorPage) {
        throw FASessionError.parsing(
          sourceUrl: FAURLs.homeUrl,
          underlyingError: errorPage.message,
        );
      }
      if (errorPage is FASystemMessagePage) {
        throw FASessionError.systemMessage(errorPage.message);
      }

      // Parse home page to get username
      final homePage = FAHomePage.parse(html, Uri.parse(FAURLs.homeUrl));

      _log.info('User is logged in as ${homePage.username}');

      return OnlineFASession._(
        username: homePage.username,
        displayUsername: homePage.displayUsername,
        cookies: cookies,
        dataSource: effectiveDataSource,
      );
    } catch (e) {
      if (e is FASessionError) rethrow;
      throw FASessionError.parsing(
        sourceUrl: FAURLs.homeUrl,
        underlyingError: e.toString(),
      );
    }
  }

  // ── Helper Methods ──

  Future<String> _fetchHtml(Uri url) async {
    final data = await _dataSource.httpGet(url: url, cookies: _cookies);
    return utf8.decode(data);
  }

  Future<String> _fetchHtmlPost(Uri url, Map<String, String> params) async {
    final data = await _dataSource.httpData(
      url: url,
      cookies: _cookies,
      method: HTTPMethod.POST,
      parameters: params,
    );
    return utf8.decode(data);
  }

  /// Fetch and validate page, detecting system error/message pages.
  Future<T> _makePage<T>(
    Uri url,
    T Function(String html, Uri url) parser,
  ) async {
    final html = await _fetchHtml(url);

    final errorPage = FAPage.detectAndParse(html, url);
    if (errorPage is FASystemErrorPage) {
      throw FASessionError.parsing(
        sourceUrl: url.toString(),
        underlyingError: errorPage.message,
      );
    }
    if (errorPage is FASystemMessagePage) {
      throw FASessionError.systemMessage(errorPage.message);
    }

    try {
      return parser(html, url);
    } catch (e) {
      throw FASessionError.parsing(
        sourceUrl: url.toString(),
        underlyingError: e.toString(),
      );
    }
  }

  // ── Submissions Feed ──

  @override
  Future<List<FASubmissionPreview>> submissionPreviews({int? fromSid}) async {
    final url = fromSid != null
        ? Uri.parse(FAURLs.submissionsFromUrl(fromSid))
        : Uri.parse(FAURLs.submissionsNewUrl);

    final page = await _makePage(url, FASubmissionsPage.parse);
    final previews = page.submissions
        .whereType<FASubmissionsPageItem>()
        .map(FASubmissionPreview.fromPageItem)
        .toList();
    _log.info('Got ${page.submissions.length} submission previews (${previews.length} after filter)');
    return previews;
  }

  @override
  Future<void> nukeSubmissions() async {
    final html = await _fetchHtmlPost(
      Uri.parse(FAURLs.submissionsNewUrl),
      {'messagecenter-action': 'nuke_notifications'},
    );
    // Verify: parse the result page to confirm success
    _checkForSystemPage(html, Uri.parse(FAURLs.submissionsNewUrl));
  }

  // ── Gallery ──

  @override
  Future<FAUserGalleryLike> galleryLikeForUrl(Uri url) async {
    final page = await _makePage(url, FAUserGalleryLikePage.parse);
    final gallery = FAUserGalleryLike.fromPage(page, url);
    _log.info('Got ${page.previews.length} gallery previews (${gallery.previews.length} after filter)');
    return gallery;
  }

  // ── Submission Detail ──

  @override
  Future<FASubmission> submissionForUrl(Uri url) async {
    final page = await _makePage(url, pages.FASubmissionPage.parse);
    return FASubmission.fromPage(page, url);
  }

  @override
  Future<FASubmission> toggleFavorite(FASubmission submission) async {
    if (submission.favoriteUrl == null) return submission;

    await _fetchHtml(submission.favoriteUrl!);
    return submissionForUrl(submission.url);
  }

  @override
  Future<FASubmission> postCommentOnSubmission({
    required FASubmission submission,
    int? replyToCid,
    required String contents,
  }) async {
    final params = <String, String>{
      'f': '0',
      'reply': contents,
      'submit': 'Post Comment',
    };

    if (replyToCid != null) {
      params['action'] = 'replyto';
      params['replyto'] = replyToCid.toString();
    } else {
      params['action'] = 'reply';
    }

    await _fetchHtmlPost(submission.url, params);
    return submissionForUrl(submission.url);
  }

  // ── Journals ──

  @override
  Future<FAUserJournals> journalsForUrl(Uri url) async {
    final page = await _makePage(url, FAUserJournalsPage.parse);
    return FAUserJournals.fromPage(page);
  }

  @override
  Future<FAJournal> journalForUrl(Uri url) async {
    final page = await _makePage(url, pages.FAJournalPage.parse);
    return FAJournal.fromPage(page, url);
  }

  @override
  Future<FAJournal> postCommentOnJournal({
    required FAJournal journal,
    int? replyToCid,
    required String contents,
  }) async {
    final params = <String, String>{
      'f': '0',
      'reply': contents,
      'submit': 'Post Comment',
    };

    if (replyToCid != null) {
      params['action'] = 'replyto';
      params['replyto'] = replyToCid.toString();
    } else {
      params['action'] = 'reply';
    }

    await _fetchHtmlPost(journal.url, params);
    return journalForUrl(journal.url);
  }

  // ── Notes ──

  @override
  Future<List<FANotePreview>> notePreviews({required NotesBox box}) async {
    final url = _notesBoxUrl(box);
    final page = await _makePage(url, FANotesPage.parse);
    return page.noteHeaders
        .whereType<FANoteHeader>()
        .map(FANotePreview.fromHeader)
        .toList();
  }

  Uri _notesBoxUrl(NotesBox box) {
    switch (box) {
      case NotesBox.inbox:
        return Uri.parse(FAURLs.notesInboxUrl);
      case NotesBox.sent:
        return Uri.parse(FAURLs.notesSentUrl);
      case NotesBox.archive:
        return Uri.parse(FAURLs.notesArchiveUrl);
      case NotesBox.trash:
        return Uri.parse(FAURLs.notesTrashUrl);
    }
  }

  String _notesBoxName(NotesBox box) {
    switch (box) {
      case NotesBox.inbox:
        return 'inbox';
      case NotesBox.sent:
        return 'sent';
      case NotesBox.archive:
        return 'archive';
      case NotesBox.trash:
        return 'trash';
    }
  }

  @override
  Future<FANote> noteForUrl(Uri url) async {
    final page = await _makePage(url, FANotePage.parse);
    return FANote.fromPage(page, url);
  }

  @override
  Future<void> sendNote({
    required String toUsername,
    required String subject,
    required String message,
  }) async {
    // First get the API key
    final keyUrlStr = FAURLs.newNoteUrl(toUsername);
    if (keyUrlStr == null) {
      throw FASessionError.parsing(
        sourceUrl: FAURLs.homeUrl,
        underlyingError: 'Failed to build new note URL for user "$toUsername"',
      );
    }
    final keyUrl = Uri.parse(keyUrlStr);
    final keyPage = await _makePage(keyUrl, FANewNotePage.parse);

    await sendNoteWithKey(
      apiKey: keyPage.apiKey,
      toUsername: toUsername,
      subject: subject,
      message: message,
    );
    _log.info('Note sent to $toUsername');
  }

  @override
  Future<void> sendNoteWithKey({
    required String apiKey,
    required String toUsername,
    required String subject,
    required String message,
  }) async {
    final url = Uri.parse(FAURLs.sendNoteUrl);
    await _fetchHtmlPost(url, {
      'key': apiKey,
      'to': toUsername,
      'subject': subject,
      'message': message,
    });
    _log.debug('Note successfully delivered to $toUsername');
  }

  @override
  Future<List<FANotePreview>> moveNotes({
    required List<FANotePreview> notes,
    required NotesBox toBox,
  }) async {
    final params = <String, String>{
      'manage_notes': '1',
      'move_to': _notesBoxName(toBox),
    };

    for (int i = 0; i < notes.length; i++) {
      params['items[$i]'] = notes[i].id.toString();
    }

    await _fetchHtmlPost(Uri.parse(FAURLs.manageNotesUrl), params);
    return notePreviews(box: toBox);
  }

  @override
  Future<List<FANotePreview>> markNotesAsUnread(List<FANotePreview> notes) async {
    final params = <String, String>{
      'manage_notes': '1',
      'move_to': 'inbox',
    };

    for (int i = 0; i < notes.length; i++) {
      params['items[$i]'] = notes[i].id.toString();
    }

    await _fetchHtmlPost(Uri.parse(FAURLs.manageNotesUrl), params);
    return notePreviews(box: NotesBox.inbox);
  }

  // ── Notifications ──

  @override
  Future<FANotificationPreviews> notificationPreviews() async {
    final url = Uri.parse(FAURLs.notificationsUrl);
    final page = await _makePage(url, FANotificationsPage.parse);
    final result = FANotificationPreviews.fromPage(page);
    final count = result.submissionComments.length +
        result.journalComments.length +
        result.shouts.length +
        result.journals.length;
    _log.info('Got $count notification previews');
    return result;
  }

  @override
  Future<void> deleteSubmissionPreviews(List<FASubmissionPreview> previews) async {
    final maxSid = previews.isEmpty
        ? 0
        : previews.map((p) => p.sid).reduce((a, b) => a > b ? a : b);
    final url = Uri.parse(FAURLs.submissionsFromUrl(maxSid));
    final params = <String, String>{
      'messagecenter-action': 'remove_checked',
    };
    for (int i = 0; i < previews.length; i++) {
      params['submissions[$i]'] = previews[i].sid.toString();
    }
    final html = await _fetchHtmlPost(url, params);
    // Verify: parse result and check previews were removed
    _checkForSystemPage(html, url);
    final page = FASubmissionsPage.parse(html, url);
    final remainingSids = page.submissions
        .whereType<FASubmissionsPageItem>()
        .map((i) => i.sid)
        .toSet();
    for (final preview in previews) {
      if (remainingSids.contains(preview.sid)) {
        throw FASessionError.parsing(
          sourceUrl: url.toString(),
          underlyingError: 'Failed to delete submission ${preview.sid}',
        );
      }
    }
  }

  @override
  Future<FANotificationPreviews> deleteSubmissionCommentNotifications(
      List<FANotificationPreview> notifications) async {
    final params = <String, String>{
      'remove-submission-comments': 'Remove Selected Comments',
    };
    for (final n in notifications) {
      params['comments-submissions[]'] = n.id.toString();
    }
    await _fetchHtmlPost(Uri.parse(FAURLs.notificationsUrl), params);
    return notificationPreviews();
  }

  @override
  Future<FANotificationPreviews> deleteJournalCommentNotifications(
      List<FANotificationPreview> notifications) async {
    final params = <String, String>{
      'remove-journal-comments': 'Remove Selected Comments',
    };
    for (final n in notifications) {
      params['comments-journals[]'] = n.id.toString();
    }
    await _fetchHtmlPost(Uri.parse(FAURLs.notificationsUrl), params);
    return notificationPreviews();
  }

  @override
  Future<FANotificationPreviews> deleteShoutNotifications(
      List<FANotificationPreview> notifications) async {
    final params = <String, String>{
      'remove-shouts': 'Remove Selected',
    };
    for (final n in notifications) {
      params['shouts[]'] = n.id.toString();
    }
    await _fetchHtmlPost(Uri.parse(FAURLs.notificationsUrl), params);
    return notificationPreviews();
  }

  @override
  Future<FANotificationPreviews> deleteJournalNotifications(
      List<FANotificationPreview> notifications) async {
    final params = <String, String>{
      'remove-journals': 'Remove Selected',
    };
    for (final n in notifications) {
      params['journals[]'] = n.id.toString();
    }
    await _fetchHtmlPost(Uri.parse(FAURLs.notificationsUrl), params);
    return notificationPreviews();
  }

  @override
  Future<FANotificationPreviews> nukeAllSubmissionCommentNotifications() async {
    await _fetchHtmlPost(Uri.parse(FAURLs.notificationsUrl), {
      'nuke-submission-comments': 'Nuke Submission Comments',
    });
    return notificationPreviews();
  }

  @override
  Future<FANotificationPreviews> nukeAllJournalCommentNotifications() async {
    await _fetchHtmlPost(Uri.parse(FAURLs.notificationsUrl), {
      'nuke-journal-comments': 'Nuke Journal Comments',
    });
    return notificationPreviews();
  }

  @override
  Future<FANotificationPreviews> nukeAllShoutNotifications() async {
    await _fetchHtmlPost(Uri.parse(FAURLs.notificationsUrl), {
      'nuke-shouts': 'Nuke Shouts',
    });
    return notificationPreviews();
  }

  @override
  Future<FANotificationPreviews> nukeAllJournalNotifications() async {
    await _fetchHtmlPost(Uri.parse(FAURLs.notificationsUrl), {
      'nuke-journals': 'Nuke Journals',
    });
    return notificationPreviews();
  }

  // ── Users ──

  @override
  Future<FAUser> userForUrl(Uri url) async {
    final page = await _makePage(url, pages.FAUserPage.parse);
    return FAUser.fromPage(page);
  }

  @override
  Future<FAUser> toggleWatch(FAUser user) async {
    if (user.watchData == null) return user;
    await _fetchHtml(user.watchData!.watchUrl);
    return userForUrl(Uri.parse(FAURLs.userUrl(user.name)));
  }

  @override
  Future<FAWatchlist> watchlist({
    required String username,
    required int page,
    required FAWatchDirection direction,
  }) async {
    final url = Uri.parse(FAURLs.watchlistUrl(username, page, direction));
    final parsedPage = await _makePage(url, FAWatchlistPage.parse);
    return FAWatchlist.fromPage(parsedPage);
  }

  @override
  Future<FAWatchlist> watchlistForUrl(Uri url) async {
    final parsed = FAURLs.parseWatchlistUrl(url);
    if (parsed == null) {
      throw FASessionError.parsing(
        sourceUrl: url.toString(),
        underlyingError: 'Could not parse watchlist URL',
      );
    }
    return watchlist(
      username: parsed.username,
      page: parsed.page,
      direction: parsed.direction,
    );
  }

  /// Check HTML response for system error/message pages and throw if found.
  void _checkForSystemPage(String html, Uri url) {
    final errorPage = FAPage.detectAndParse(html, url);
    if (errorPage is FASystemErrorPage) {
      throw FASessionError.parsing(
        sourceUrl: url.toString(),
        underlyingError: errorPage.message,
      );
    }
    if (errorPage is FASystemMessagePage) {
      throw FASessionError.systemMessage(errorPage.message);
    }
  }
}
