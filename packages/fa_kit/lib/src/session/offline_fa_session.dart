import '../pages/fa_submission_page.dart';
import '../pages/fa_user_journals_page.dart';
import '../pages/fa_watchlist_page.dart';
import '../models/fa_submission.dart';
import '../models/fa_comment.dart';
import '../models/fa_journal.dart';
import '../models/fa_note.dart';
import '../models/fa_note_preview.dart';
import '../models/fa_notification_preview.dart';
import '../models/fa_user.dart';
import '../models/fa_user_gallery_like.dart';
import '../models/fa_user_journals.dart';
import '../models/fa_watchlist.dart';
import 'fa_session.dart';

/// An offline/mock implementation of [FASession] for testing and UI previews.
///
/// Returns demo data for all API methods. Useful for:
/// - Widget testing without network
/// - Flutter widget previews (Widgetbook, storybook)
/// - Integration testing with predictable data
class OfflineFASession extends FASession {
  @override
  final String username;
  @override
  final String displayUsername;

  OfflineFASession({
    this.username = 'DemoUser',
    this.displayUsername = 'Demo User',
  });

  // ── Demo Data ──

  static final Uri _demoSubmissionUrl =
      Uri.parse('https://www.furaffinity.net/view/12345678/');

  static final List<FASubmissionPreview> _demoSubmissionPreviews = [
    FASubmissionPreview(
      sid: 12345678,
      url: Uri.parse('https://www.furaffinity.net/view/12345678/'),
      thumbnailUrl:
          Uri.parse('https://t.furaffinity.net/12345678@600-12345678.jpg'),
      thumbnailWidthOnHeightRatio: 1.33,
      title: 'Amazing Artwork',
      author: 'someartist',
      displayAuthor: 'SomeArtist',
    ),
    FASubmissionPreview(
      sid: 12345677,
      url: Uri.parse('https://www.furaffinity.net/view/12345677/'),
      thumbnailUrl:
          Uri.parse('https://t.furaffinity.net/12345677@600-12345677.jpg'),
      thumbnailWidthOnHeightRatio: 0.75,
      title: 'Cool Sketch',
      author: 'anotherartist',
      displayAuthor: 'AnotherArtist',
    ),
    FASubmissionPreview(
      sid: 12345676,
      url: Uri.parse('https://www.furaffinity.net/view/12345676/'),
      thumbnailUrl:
          Uri.parse('https://t.furaffinity.net/12345676@600-12345676.jpg'),
      thumbnailWidthOnHeightRatio: 1.0,
      title: 'Photo Submission',
      author: 'photographer',
      displayAuthor: 'Photographer',
    ),
  ];

  static final FASubmission _demoSubmission = FASubmission(
    url: _demoSubmissionUrl,
    previewImageUrl:
        Uri.parse('https://t.furaffinity.net/12345678@600-12345678.jpg'),
    fullResolutionMediaUrl:
        Uri.parse('https://d.furaffinity.net/art/someartist/full-12345678.png'),
    widthOnHeightRatio: 1.33,
    metadata: _demoMetadata,
    htmlDescription:
        '<p>This is a <b>demo</b> submission description.</p><p>It has <i>formatted</i> text and '
        '<a href="https://example.com">links</a>.</p>',
    isFavorite: true,
    favoriteUrl: Uri.parse('https://www.furaffinity.net/fav/12345678/'),
    comments: [
      FAVisibleComment(
        indentation: 0,
        cid: 1001,
        author: 'commenter1',
        displayAuthor: 'Commenter One',
        datetime: DateTime(2024, 1, 15, 10, 30),
        naturalDatetime: 'Jan 15, 2024 10:30 AM',
        htmlMessage: '<p>Great artwork!</p>',
        answers: [
          FAVisibleComment(
            indentation: 0,
            cid: 1002,
            author: 'someartist',
            displayAuthor: 'SomeArtist',
            datetime: DateTime(2024, 1, 15, 12, 0),
            naturalDatetime: 'Jan 15, 2024 12:00 PM',
            htmlMessage: '<p>Thank you!</p>',
          ),
        ],
      ),
      FAHiddenComment(
        cid: 1003,
        indentation: 0,
        htmlMessage: '<p>[Hidden by admin]</p>',
      ),
    ],
    targetCommentId: null,
    acceptsNewComments: true,
  );

  static final _demoMetadata = FASubmissionPageMetadata(
    title: 'Amazing Artwork',
    author: 'someartist',
    displayAuthor: 'SomeArtist',
    datetime: DateTime(2024, 1, 14, 8, 0),
    naturalDatetime: 'Jan 14, 2024 08:00 AM',
    viewCount: 1234,
    commentCount: 42,
    favoriteCount: 89,
    rating: Rating.general,
    category: 'Artwork (Digital)',
    theme: 'All',
    species: 'Wolf',
    resolution: '1920x1080',
    fileSize: '2.5 MB',
    keywords: ['demo', 'art', 'digital'],
    folders: [],
  );

  static final FAJournal _demoJournal = FAJournal(
    url: Uri.parse('https://www.furaffinity.net/journal/98765/'),
    author: 'someartist',
    displayAuthor: 'SomeArtist',
    title: 'Demo Journal Title',
    datetime: DateTime(2024, 1, 10, 14, 0),
    naturalDatetime: 'Jan 10, 2024 02:00 PM',
    htmlDescription:
        '<p>This is a <b>demo journal</b> entry with some content.</p>'
        '<p>It can have multiple paragraphs and <a href="https://example.com">links</a>.</p>',
    comments: [
      FAVisibleComment(
        indentation: 0,
        cid: 2001,
        author: 'reader1',
        displayAuthor: 'Reader One',
        datetime: DateTime(2024, 1, 10, 16, 0),
        naturalDatetime: 'Jan 10, 2024 04:00 PM',
        htmlMessage: '<p>Interesting journal!</p>',
      ),
    ],
    targetCommentId: null,
    acceptsNewComments: true,
  );

  static final FAUser _demoUser = FAUser(
    name: 'someartist',
    displayName: 'SomeArtist',
    bannerUrl: Uri.parse('https://a.furaffinity.net/someartist-banner.png'),
    htmlDescription:
        '<p>Hi, I\'m a <b>demo artist</b>!</p><p>Check out my gallery.</p>',
    shouts: [
      FAVisibleComment(
        indentation: 0,
        cid: 3001,
        author: 'visitor1',
        displayAuthor: 'Visitor One',
        datetime: DateTime(2024, 1, 5, 9, 0),
        naturalDatetime: 'Jan 5, 2024 09:00 AM',
        htmlMessage: '<p>Nice profile!</p>',
      ),
    ],
    targetShoutId: null,
    watchData: FAWatchDataModel(
      watchUrl: Uri.parse('https://www.furaffinity.net/unwatch/someartist/'),
    ),
  );

  static final FANote _demoNote = FANote(
    url: Uri.parse('https://www.furaffinity.net/msg/pms/54321/'),
    author: 'someartist',
    displayAuthor: 'SomeArtist',
    title: 'Demo Note Subject',
    datetime: DateTime(2024, 1, 12, 20, 0),
    naturalDatetime: 'Jan 12, 2024 08:00 PM',
    htmlMessage: '<p>This is a <b>demo note</b> message.</p>',
    htmlMessageWithoutWarning: '<p>This is a <b>demo note</b> message.</p>',
    answerKey: 'demo-answer-key-12345',
    answerPlaceholderMessage: 'Type your reply here...',
  );

  static final List<FANotePreview> _demoNotePreviews = [
    FANotePreview(
      id: 54321,
      author: 'someartist',
      displayAuthor: 'SomeArtist',
      title: 'Demo Note Subject',
      datetime: DateTime(2024, 1, 12, 20, 0),
      naturalDatetime: 'Jan 12, 2024 08:00 PM',
      unread: true,
      noteUrl: Uri.parse('https://www.furaffinity.net/msg/pms/54321/'),
    ),
    FANotePreview(
      id: 54320,
      author: 'anotheruser',
      displayAuthor: 'AnotherUser',
      title: 'Older Note',
      datetime: DateTime(2024, 1, 10, 15, 0),
      naturalDatetime: 'Jan 10, 2024 03:00 PM',
      unread: false,
      noteUrl: Uri.parse('https://www.furaffinity.net/msg/pms/54320/'),
    ),
  ];

  static final FANotificationPreviews _demoNotifications =
      FANotificationPreviews(
    submissionComments: [
      FANotificationPreview(
        id: 9001,
        author: 'user1',
        displayAuthor: 'User One',
        title: 'Commented on "My Art"',
        datetime: DateTime(2024, 1, 14, 22, 0),
        naturalDatetime: 'Jan 14, 2024 10:00 PM',
        url: Uri.parse('https://www.furaffinity.net/view/111/'),
      ),
    ],
    journalComments: [
      FANotificationPreview(
        id: 9002,
        author: 'user2',
        displayAuthor: 'User Two',
        title: 'Commented on "My Journal"',
        datetime: DateTime(2024, 1, 14, 20, 0),
        naturalDatetime: 'Jan 14, 2024 08:00 PM',
        url: Uri.parse('https://www.furaffinity.net/journal/222/'),
      ),
    ],
    shouts: [
      FANotificationPreview(
        id: 9003,
        author: 'user3',
        displayAuthor: 'User Three',
        title: 'Shouted on your page',
        datetime: DateTime(2024, 1, 14, 18, 0),
        naturalDatetime: 'Jan 14, 2024 06:00 PM',
        url: Uri.parse('https://www.furaffinity.net/user/demouser/'),
      ),
    ],
    journals: [
      FANotificationPreview(
        id: 9004,
        author: 'someartist',
        displayAuthor: 'SomeArtist',
        title: 'New Journal: "Updates!"',
        datetime: DateTime(2024, 1, 14, 16, 0),
        naturalDatetime: 'Jan 14, 2024 04:00 PM',
        url: Uri.parse('https://www.furaffinity.net/journal/333/'),
      ),
    ],
  );

  static final FAUserGalleryLike _demoGallery = FAUserGalleryLike(
    url: Uri.parse('https://www.furaffinity.net/gallery/someartist/'),
    displayAuthor: 'SomeArtist',
    previews: _demoSubmissionPreviews,
    nextPageUrl: null,
    folderGroups: [],
  );

  static final FAUserJournals _demoJournals = FAUserJournals(
    displayAuthor: 'SomeArtist',
    journals: [
      FAUserJournalEntry(
        id: 98765,
        title: 'Demo Journal Title',
        datetime: DateTime(2024, 1, 10, 14, 0),
        naturalDatetime: 'Jan 10, 2024 02:00 PM',
        url: Uri.parse('https://www.furaffinity.net/journal/98765/'),
      ),
    ],
  );

  static final FAWatchlist _demoWatchlist = FAWatchlist(
    currentUser:
        FAWatchlistUserModel(name: 'someartist', displayName: 'SomeArtist'),
    watchDirection: FAWatchDirection.watching,
    users: [
      FAWatchlistUserModel(name: 'user1', displayName: 'User One'),
      FAWatchlistUserModel(name: 'user2', displayName: 'User Two'),
      FAWatchlistUserModel(name: 'user3', displayName: 'User Three'),
    ],
    nextPageUrl: null,
  );

  // ── FASession Implementation ──

  @override
  Future<List<FASubmissionPreview>> submissionPreviews({int? fromSid}) async {
    return List.from(_demoSubmissionPreviews);
  }

  @override
  Future<void> nukeSubmissions() async {
    // No-op in offline mode
  }

  @override
  Future<FAUserGalleryLike> galleryLikeForUrl(Uri url) async {
    return _demoGallery;
  }

  @override
  Future<FASubmission> submissionForUrl(Uri url) async {
    return _demoSubmission;
  }

  @override
  Future<FASubmission> toggleFavorite(FASubmission submission) async {
    return FASubmission(
      url: submission.url,
      previewImageUrl: submission.previewImageUrl,
      fullResolutionMediaUrl: submission.fullResolutionMediaUrl,
      widthOnHeightRatio: submission.widthOnHeightRatio,
      metadata: submission.metadata,
      htmlDescription: submission.htmlDescription,
      isFavorite: !submission.isFavorite,
      favoriteUrl: submission.favoriteUrl,
      comments: submission.comments,
      targetCommentId: submission.targetCommentId,
      acceptsNewComments: submission.acceptsNewComments,
    );
  }

  @override
  Future<FASubmission> postCommentOnSubmission({
    required FASubmission submission,
    int? replyToCid,
    required String contents,
  }) async {
    return submission;
  }

  @override
  Future<FAUserJournals> journalsForUrl(Uri url) async {
    return _demoJournals;
  }

  @override
  Future<FAJournal> journalForUrl(Uri url) async {
    return _demoJournal;
  }

  @override
  Future<FAJournal> postCommentOnJournal({
    required FAJournal journal,
    int? replyToCid,
    required String contents,
  }) async {
    return journal;
  }

  @override
  Future<List<FANotePreview>> notePreviews({required NotesBox box}) async {
    return List.from(_demoNotePreviews);
  }

  @override
  Future<FANote> noteForUrl(Uri url) async {
    return _demoNote;
  }

  @override
  Future<void> sendNote({
    required String toUsername,
    required String subject,
    required String message,
  }) async {
    // No-op in offline mode
  }

  @override
  Future<void> sendNoteWithKey({
    required String apiKey,
    required String toUsername,
    required String subject,
    required String message,
  }) async {
    // No-op in offline mode
  }

  @override
  Future<List<FANotePreview>> moveNotes({
    required List<FANotePreview> notes,
    required NotesBox toBox,
  }) async {
    return List.from(_demoNotePreviews);
  }

  @override
  Future<List<FANotePreview>> markNotesAsUnread(
      List<FANotePreview> notes) async {
    return _demoNotePreviews.map((p) => p.unread ? p : p.asRead()).toList();
  }

  @override
  Future<FANotificationPreviews> notificationPreviews() async {
    return _demoNotifications;
  }

  @override
  Future<void> deleteSubmissionPreviews(
      List<FASubmissionPreview> previews) async {
    // No-op in offline mode
  }

  @override
  Future<FANotificationPreviews> deleteSubmissionCommentNotifications(
      List<FANotificationPreview> notifications) async {
    return FANotificationPreviews(
      submissionComments: [],
      journalComments: [],
      shouts: [],
      journals: [],
    );
  }

  @override
  Future<FANotificationPreviews> deleteJournalCommentNotifications(
      List<FANotificationPreview> notifications) async {
    return FANotificationPreviews(
      submissionComments: [],
      journalComments: [],
      shouts: [],
      journals: [],
    );
  }

  @override
  Future<FANotificationPreviews> deleteShoutNotifications(
      List<FANotificationPreview> notifications) async {
    return FANotificationPreviews(
      submissionComments: [],
      journalComments: [],
      shouts: [],
      journals: [],
    );
  }

  @override
  Future<FANotificationPreviews> deleteJournalNotifications(
      List<FANotificationPreview> notifications) async {
    return FANotificationPreviews(
      submissionComments: [],
      journalComments: [],
      shouts: [],
      journals: [],
    );
  }

  @override
  Future<FANotificationPreviews> nukeAllSubmissionCommentNotifications() async {
    return FANotificationPreviews(
      submissionComments: [],
      journalComments: [],
      shouts: [],
      journals: [],
    );
  }

  @override
  Future<FANotificationPreviews> nukeAllJournalCommentNotifications() async {
    return FANotificationPreviews(
      submissionComments: [],
      journalComments: [],
      shouts: [],
      journals: [],
    );
  }

  @override
  Future<FANotificationPreviews> nukeAllShoutNotifications() async {
    return FANotificationPreviews(
      submissionComments: [],
      journalComments: [],
      shouts: [],
      journals: [],
    );
  }

  @override
  Future<FANotificationPreviews> nukeAllJournalNotifications() async {
    return FANotificationPreviews(
      submissionComments: [],
      journalComments: [],
      shouts: [],
      journals: [],
    );
  }

  @override
  Future<FAUser> userForUrl(Uri url) async {
    return _demoUser;
  }

  @override
  Future<FAUser> toggleWatch(FAUser user) async {
    return FAUser(
      name: user.name,
      displayName: user.displayName,
      bannerUrl: user.bannerUrl,
      htmlDescription: user.htmlDescription,
      shouts: user.shouts,
      targetShoutId: user.targetShoutId,
      watchData: user.watchData != null
          ? FAWatchDataModel(
              watchUrl: Uri.parse(
                  'https://www.furaffinity.net/${user.watchData!.watching ? "unwatch" : "watch"}/${user.name}/'),
            )
          : null,
    );
  }

  @override
  Future<FAWatchlist> watchlist({
    required String username,
    required int page,
    required FAWatchDirection direction,
  }) async {
    return _demoWatchlist;
  }

  @override
  Future<FAWatchlist> watchlistForUrl(Uri url) async {
    return _demoWatchlist;
  }
}
