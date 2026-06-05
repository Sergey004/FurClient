import 'dart:io';
import 'package:fa_kit/fa_kit.dart';

/// Example: How to use FAKit in a Flutter/Dart application.
///
/// Note: You need to obtain cookies from a login WebView first.
/// The session cookie "a" is required for authenticated access.
void main() async {
  // ─────────────────────────────────────────────
  // 1. Create a session from cookies
  // ─────────────────────────────────────────────
  //
  // In a real Flutter app, you would get cookies from a WebView login flow:
  //
  // ```dart
  // // Using webview_flutter:
  // final cookies = await webView.runJavaScriptReturningResult(
  //   'document.cookie'
  // );
  // ```
  //
  // For this example, assume you have cookies:
  final cookies = [
    Cookie('a', 'your-session-cookie-value'),
    Cookie('b', 'another-cookie-value'),
  ];

  final session = await OnlineFASession.fromCookies(cookies: cookies);

  if (session == null) {
    print('Not logged in — session cookie "a" is missing or invalid');
    return;
  }

  print('Logged in as: ${session.displayUsername}');

  // ─────────────────────────────────────────────
  // 2. Fetch latest submissions
  // ─────────────────────────────────────────────
  final submissions = await session.submissionPreviews();
  print('Latest submissions:');
  for (final sub in submissions) {
    print('  ${sub.title} by ${sub.displayAuthor} (sid: ${sub.sid})');
  }

  // ─────────────────────────────────────────────
  // 3. Get submission details
  // ─────────────────────────────────────────────
  if (submissions.isNotEmpty) {
    final submission = await session.submissionForPreview(submissions.first);
    print('\nSubmission: ${submission.title}');
    print('  Author: ${submission.displayAuthor}');
    print('  Views: ${submission.metadata.viewCount}');
    print('  Favorites: ${submission.metadata.favoriteCount}');
    print('  Rating: ${submission.metadata.rating}');
    print('  Is favorite: ${submission.isFavorite}');

    // Toggle favorite
    if (!submission.isFavorite) {
      final updated = await session.toggleFavorite(submission);
      print('  Now favorited: ${updated.isFavorite}');
    }

    // Comments (tree-structured)
    print('  Comments: ${submission.comments.length} root comments');
    for (final comment in submission.comments) {
      _printComment(comment, indent: 0);
    }
  }

  // ─────────────────────────────────────────────
  // 4. Fetch notifications
  // ─────────────────────────────────────────────
  final notifications = await session.notificationPreviews();
  print('\nNotifications:');
  print('  Submission comments: ${notifications.submissionComments.length}');
  print('  Journal comments: ${notifications.journalComments.length}');
  print('  Shouts: ${notifications.shouts.length}');
  print('  Journals: ${notifications.journals.length}');

  // ─────────────────────────────────────────────
  // 5. Fetch user profile
  // ─────────────────────────────────────────────
  final user = await session.userForName('someUsername');
  print('\nUser: ${user.displayName}');
  print('  Watching: ${user.watchData?.watching ?? "unknown"}');

  // Toggle watch
  if (user.watchData != null) {
    final updatedUser = await session.toggleWatch(user);
    print('  Now watching: ${updatedUser.watchData?.watching}');
  }

  // ─────────────────────────────────────────────
  // 6. Fetch user gallery
  // ─────────────────────────────────────────────
  final gallery = await session.galleryLikeForUser('someUsername');
  print('\nGallery: ${gallery.displayAuthor}');
  print('  Previews: ${gallery.previews.length}');
  print('  Folder groups: ${gallery.folderGroups.length}');

  // ─────────────────────────────────────────────
  // 7. Fetch notes
  // ─────────────────────────────────────────────
  final notePreviews = await session.notePreviews(box: NotesBox.inbox);
  print('\nNotes in inbox: ${notePreviews.length}');
  for (final note in notePreviews) {
    print('  ${note.unread ? "🔴" : "⚪"} ${note.title} from ${note.displayAuthor}');
  }

  // Read a note
  if (notePreviews.isNotEmpty) {
    final note = await session.noteForPreview(notePreviews.first);
    print('\nNote: ${note.title}');
    print('  From: ${note.displayAuthor}');
    print('  Message: ${note.htmlMessageWithoutWarning}');
  }

  // ─────────────────────────────────────────────
  // 8. Send a note
  // ─────────────────────────────────────────────
  await session.sendNote(
    toUsername: 'recipient',
    subject: 'Hello from FAKit!',
    message: 'This is a test note sent via FAKit Flutter library.',
  );
  print('\nNote sent!');

  // ─────────────────────────────────────────────
  // 9. Fetch journals
  // ─────────────────────────────────────────────
  final journals = await session.journalsForUrl(
    Uri.parse(FAURLs.journalsUrl('someUsername')),
  );
  print('\nJournals: ${journals.displayAuthor}');
  for (final journal in journals.journals) {
    print('  ${journal.title} (${journal.naturalDatetime})');
  }

  // ─────────────────────────────────────────────
  // 10. Nuke all notifications
  // ─────────────────────────────────────────────
  await session.nukeAllSubmissionCommentNotifications();
  await session.nukeAllJournalCommentNotifications();
  await session.nukeAllShoutNotifications();
  await session.nukeAllJournalNotifications();
  print('\nAll notifications nuked!');
}

void _printComment(FAComment comment, {required int indent}) {
  final prefix = '  ' * (indent + 2);
  if (comment is FAVisibleComment) {
    print('$prefix${comment.displayAuthor}: '
        '${comment.htmlMessage.replaceAll(RegExp(r'<[^>]*>'), '').trim().substring(0, 50)}...');
  } else if (comment is FAHiddenComment) {
    print('$prefix[hidden comment]');
  }
  for (final answer in comment.answers) {
    _printComment(answer, indent: indent + 1);
  }
}

// ─────────────────────────────────────────────
// Low-level page parsing (without session)
// ─────────────────────────────────────────────
void lowLevelParsingExample() {
  // You can use the FAPages layer directly for parsing HTML:
  //
  // final html = '<html>...FA page HTML...</html>';
  // final url = Uri.parse('https://www.furaffinity.net/view/12345/');
  //
  // // Parse submission page
  // final page = FASubmissionPage.parse(html, url);
  // print(page.metadata.title);
  // print(page.metadata.author);
  //
  // // Build comment tree
  // final comments = buildCommentsTree(page.comments);
  // for (final c in comments) {
  //   print(c.cid);
  // }
  //
  // // Parse submissions list
  // final subsPage = FASubmissionsPage.parse(html, url);
  // for (final item in subsPage.submissions.whereType<FASubmissionsPageItem>()) {
  //   print('${item.title} by ${item.displayAuthor}');
  // }

  // Dynamic thumbnail URLs
  final thumbUrl = Uri.parse('https://t.furaffinity.net/123@300-abc.jpg');
  final dynamic = DynamicThumbnail(thumbUrl);
  print(dynamic.bestThumbnailUrl(width: 250, height: 250)); // 300
  print(dynamic.bestThumbnailUrl(width: 500, height: 500)); // 600

  // CSS inlining
  // final inliner = CSSInliner();
  // final selfContainedHtml = '<p>Some content</p>'
  //     .selfContainedFAHtmlSubmission()
  //     .fixingLinks();
  // final inlinedHtml = await inliner.inlineCSS(selfContainedHtml);
}
