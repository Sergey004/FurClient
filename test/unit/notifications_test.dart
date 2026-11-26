import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furclient/utils/notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    onNotificationTap = null;
  });

  test('Android details use the configured channel name and priority', () {
    final note = androidNotificationDetailsForType('note');
    expect(note.channelId, 'note_channel');
    expect(note.channelName, 'Notes');
    expect(note.importance, Importance.high);
    expect(note.priority, Priority.high);

    final comment = androidNotificationDetailsForType('submission_comment');
    expect(comment.channelName, 'Submission Comments');
    expect(comment.importance, Importance.high);

    final watch = androidNotificationDetailsForType('watch');
    expect(watch.channelId, 'watch_channel');
    expect(watch.channelName, 'Watches');

    final submission = androidNotificationDetailsForType('submission');
    expect(submission.channelName, 'New Submissions');
    expect(submission.importance, Importance.defaultImportance);
  });

  test('notification IDs are stable per event and distinct across downloads',
      () {
    const first = 'download-https://cdn.example/first.png';
    const second = 'download-https://cdn.example/second.png';
    expect(notificationIdFor(first), notificationIdFor(first));
    expect(notificationIdFor(first), isNot(notificationIdFor(second)));
    expect(notificationIdFor(first), greaterThanOrEqualTo(0));
  });

  test('a tap received before runApp is delivered after handler attachment',
      () {
    onNotificationTap = null;
    dispatchNotificationTap('https://www.furaffinity.net/view/42/');

    String? received;
    onNotificationTap = (payload) => received = payload;
    expect(received, isNull);

    flushPendingNotificationTaps();
    expect(received, 'https://www.furaffinity.net/view/42/');
  });
}
