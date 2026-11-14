import 'package:fa_kit/fa_kit.dart' as fa;
import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/models/models.dart';
import 'package:furclient/services/fa_client.dart';
import 'package:furclient/services/notification_poller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PostedNotification {
  final String type;
  final String title;
  final String body;
  final int id;
  final String? payload;

  _PostedNotification({
    required this.type,
    required this.title,
    required this.body,
    required this.id,
    required this.payload,
  });
}

NotificationPoster _recorder(List<_PostedNotification> posted) {
  Future<void> poster({
    required String type,
    required String title,
    String body = '',
    int notificationId = 0,
    bool showProgress = false,
    int progress = 0,
    int maxProgress = 100,
    String? payload,
  }) async {
    posted.add(_PostedNotification(
      type: type,
      title: title,
      body: body,
      id: notificationId,
      payload: payload,
    ));
  }

  return poster;
}

class _FakeClient extends FAClient {
  final List<Submission> feed;
  final Object? fetchError;
  final bool loggedIn;
  int feedCalls = 0;

  _FakeClient({
    this.feed = const [],
    this.fetchError,
    this.loggedIn = true,
  });

  @override
  UserSession? get session => UserSession(
        username: 'me',
        avatarUrl: '',
        isLoggedIn: loggedIn,
      );

  @override
  Future<({List<Submission> submissions, int? nextSid})> getWatchSubmissions(
      {int? fromSid}) async {
    feedCalls++;
    final error = fetchError;
    if (error != null) throw error;
    return (submissions: feed, nextSid: null);
  }
}

Submission _submission(String id, {DateTime? date}) => Submission(
      id: id,
      title: 'Submission $id',
      author: 'artist',
      category: 'Digital',
      imageUrl: '',
      views: 0,
      faves: 0,
      commentsCount: 0,
      description: '',
      tags: const [],
      date: '',
      sortDate: date,
      isNsfw: false,
      url: 'https://www.furaffinity.net/view/$id/',
    );

fa.FANotePreview _note(
  int id, {
  bool unread = true,
  DateTime? date,
}) =>
    fa.FANotePreview(
      id: id,
      author: 'sender',
      displayAuthor: 'Sender',
      title: 'Note $id',
      datetime: date ?? DateTime.utc(2025),
      naturalDatetime: '',
      unread: unread,
      noteUrl: Uri.parse('https://www.furaffinity.net/msg/pms/$id/'),
    );

fa.FANotificationPreview _other(int id, {DateTime? date}) =>
    fa.FANotificationPreview(
      id: id,
      author: 'author',
      displayAuthor: 'Author',
      title: 'Item $id',
      datetime: date,
      naturalDatetime: '',
      url: Uri.parse('https://www.furaffinity.net/journal/$id/'),
    );

fa.FANotificationPreviews _others({
  List<fa.FANotificationPreview> submissionComments = const [],
  List<fa.FANotificationPreview> journalComments = const [],
  List<fa.FANotificationPreview> shouts = const [],
  List<fa.FANotificationPreview> journals = const [],
}) =>
    fa.FANotificationPreviews(
      submissionComments: submissionComments,
      journalComments: journalComments,
      shouts: shouts,
      journals: journals,
    );

NotificationPoller _poller(
  _FakeClient client,
  List<_PostedNotification> posted, {
  List<fa.FANotePreview> notes = const [],
  fa.FANotificationPreviews? others,
  NotificationPoster? poster,
}) =>
    NotificationPoller(
      client,
      poster: poster ?? _recorder(posted),
      notesSource: () async => notes,
      othersSource: () async => others ?? _others(),
    );

Map<String, Object> _initializedPrefs() => {
      'latestSubmissionNotificationID': 0,
      'latestNoteNotificationID': 0,
      'latestSubmissionCommentNotificationID': 0,
      'latestJournalCommentNotificationID': 0,
      'latestShoutNotificationID': 0,
      'latestJournalNotificationID': 0,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first run seeds all watermarks without posting or duplicating later',
      () async {
    SharedPreferences.setMockInitialValues({});
    final posted = <_PostedNotification>[];
    final client = _FakeClient(feed: [_submission('102'), _submission('101')]);
    final poller = _poller(
      client,
      posted,
      notes: [_note(5)],
      others: _others(shouts: [_other(12)], journals: [_other(11)]),
    );

    await poller.pollAndNotify();
    expect(posted, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('latestSubmissionNotificationID'), 102);
    expect(prefs.getInt('latestNoteNotificationID'), 5);
    expect(prefs.getInt('latestShoutNotificationID'), 12);
    expect(prefs.getInt('latestJournalNotificationID'), 11);
    expect(prefs.getInt('latestSubmissionCommentNotificationID'), 0);
    expect(prefs.getInt('latestJournalCommentNotificationID'), 0);

    await poller.pollAndNotify();
    expect(posted, isEmpty);
  });

  test('all six categories post once and advance their own watermark',
      () async {
    SharedPreferences.setMockInitialValues(_initializedPrefs());
    final posted = <_PostedNotification>[];
    final poller = _poller(
      _FakeClient(feed: [_submission('100')]),
      posted,
      notes: [_note(10)],
      others: _others(
        submissionComments: [_other(20)],
        journalComments: [_other(30)],
        shouts: [_other(40)],
        journals: [_other(50)],
      ),
    );

    await poller.pollAndNotify();
    expect(
      posted.map((n) => n.type),
      containsAll(<String>[
        'submission',
        'note',
        'submission_comment',
        'journal_comment',
        'shout',
        'journal',
      ]),
    );
    expect(posted, hasLength(6));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('latestSubmissionNotificationID'), 100);
    expect(prefs.getInt('latestNoteNotificationID'), 10);
    expect(prefs.getInt('latestSubmissionCommentNotificationID'), 20);
    expect(prefs.getInt('latestJournalCommentNotificationID'), 30);
    expect(prefs.getInt('latestShoutNotificationID'), 40);
    expect(prefs.getInt('latestJournalNotificationID'), 50);

    await poller.pollAndNotify();
    expect(posted, hasLength(6));
  });

  test('disabled and already read notes advance without a later backlog',
      () async {
    SharedPreferences.setMockInitialValues({
      ..._initializedPrefs(),
      'notify_notes': false,
    });
    final posted = <_PostedNotification>[];
    final poller = _poller(
      _FakeClient(),
      posted,
      notes: [_note(1), _note(2, unread: false)],
    );

    await poller.pollAndNotify();
    expect(posted, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('latestNoteNotificationID'), 2);

    await prefs.setBool('notify_notes', true);
    await poller.pollAndNotify();
    expect(posted, isEmpty);
  });

  test('only unread fresh notes post while the watermark includes read notes',
      () async {
    SharedPreferences.setMockInitialValues({
      ..._initializedPrefs(),
      'latestNoteNotificationID': 2,
    });
    final posted = <_PostedNotification>[];
    final poller = _poller(
      _FakeClient(),
      posted,
      notes: [_note(3), _note(4, unread: false)],
    );

    await poller.pollAndNotify();
    expect(posted.map((n) => n.body), ['✉️ Note 3']);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('latestNoteNotificationID'), 4);
  });

  test('records post oldest first instead of source HTML order', () async {
    SharedPreferences.setMockInitialValues(_initializedPrefs());
    final posted = <_PostedNotification>[];
    final poller = _poller(
      _FakeClient(feed: [_submission('102'), _submission('101')]),
      posted,
      notes: [
        _note(5, date: DateTime.utc(2025, 1, 3)),
        _note(4, date: DateTime.utc(2025, 1, 1)),
      ],
      others: _others(
        journalComments: [
          _other(20, date: DateTime.utc(2025, 1, 2)),
        ],
        journals: [_other(30, date: DateTime.utc(2025, 1, 4))],
      ),
    );

    await poller.pollAndNotify();
    expect(posted.map((n) => n.body), [
      'Submission 101',
      'Submission 102',
      '✉️ Note 4',
      '💬 Item 20',
      '✉️ Note 5',
      '📝 Item 30',
    ]);
  });

  test('Cloudflare toast is throttled and does not move watermarks', () async {
    SharedPreferences.setMockInitialValues({
      ..._initializedPrefs(),
      'latestSubmissionNotificationID': 7,
      'last_cf_toast_at': DateTime.now().millisecondsSinceEpoch,
    });
    final posted = <_PostedNotification>[];
    final poller = _poller(
      _FakeClient(fetchError: CloudflareError()),
      posted,
    );

    await poller.pollAndNotify();
    expect(posted, isEmpty);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_cf_toast_at', 0);
    await poller.pollAndNotify();
    expect(posted, hasLength(1));
    expect(posted.single.type, 'system');
    expect(posted.single.id, 999999);

    await poller.pollAndNotify();
    expect(posted, hasLength(1));
    expect(prefs.getInt('latestSubmissionNotificationID'), 7);
    expect(prefs.getInt('latestNoteNotificationID'), 0);
  });

  test('ordinary source failure stays silent and preserves watermarks',
      () async {
    SharedPreferences.setMockInitialValues({
      ..._initializedPrefs(),
      'latestSubmissionNotificationID': 7,
    });
    final posted = <_PostedNotification>[];
    final poller = _poller(
      _FakeClient(fetchError: StateError('offline')),
      posted,
    );

    await poller.pollAndNotify();
    expect(posted, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('latestSubmissionNotificationID'), 7);
  });

  test('logged-out poller does not fetch or post', () async {
    SharedPreferences.setMockInitialValues(_initializedPrefs());
    final posted = <_PostedNotification>[];
    final client = _FakeClient(loggedIn: false);
    await _poller(client, posted).pollAndNotify();

    expect(client.feedCalls, 0);
    expect(posted, isEmpty);
  });
}
