/// Flutter/Dart port of FAKit — an unofficial FurAffinity API client library.
///
/// Provides cookie-based authentication, HTML page parsing, and typed models
/// for interacting with FurAffinity (furaffinity.net).
///
/// ## Quick Start
///
/// ```dart
/// import 'package:fa_kit/fa_kit.dart';
///
/// // Create session from cookies
/// final session = await OnlineFASession.fromCookies(
///   cookies: myCookies,
/// );
///
/// if (session == null) {
///   print('Not logged in');
///   return;
/// }
///
/// // Fetch submissions
/// final submissions = await session.submissionPreviews();
/// for (final sub in submissions) {
///   print('${sub.title} by ${sub.displayAuthor}');
/// }
///
/// // Get submission details
/// final submission = await session.submissionForUrl(submissions.first.url);
/// print('Full description: ${submission.htmlDescription}');
///
/// // Get user profile
/// final user = await session.userForName('someUsername');
/// print('Watching: ${user.watchData?.watching}');
/// ```
///
/// ## Architecture
///
/// The library is organized in two layers:
///
/// - **FAPages** (`fa_kit/lib/src/pages/`): Low-level HTML parsing layer that
///   scrapes FurAffinity HTML pages into typed Dart structs using CSS selectors.
///
/// - **FAKit** (`fa_kit/lib/src/models/`, `fa_kit/lib/src/session/`):
///   High-level API / business logic layer that converts parsed HTML content
///   into app models, manages sessions, and provides typed methods for all
///   FurAffinity operations.
///
/// ## Authentication
///
/// FAKit uses cookie-based session authentication. The session cookie named
/// `"a"` must be present. In a Flutter app, you would typically:
///
/// 1. Open a WebView pointed at FA's login page
/// 2. Let the user log in through the native browser
/// 3. Capture cookies from the WebView (especially cookie "a")
/// 4. Create an [OnlineFASession] with those cookies
///
/// ## Navigation
///
/// Use [FATarget] to parse FurAffinity URLs into typed navigation targets:
///
/// ```dart
/// final target = FATarget.parse(Uri.parse('https://www.furaffinity.net/view/12345/'));
/// if (target?.type == FATargetType.submission) {
///   // Navigate to submission detail view
/// }
/// ```
///
/// ## Offline / Testing
///
/// Use [OfflineFASession] for widget testing and UI previews:
///
/// ```dart
/// final session = OfflineFASession(username: 'TestUser');
/// final submissions = await session.submissionPreviews(); // Returns demo data
/// ```
library;

// ── Public API exports ──

// Session & Authentication
export 'src/session/fa_session.dart';
export 'src/session/online_fa_session.dart';
export 'src/session/offline_fa_session.dart';
export 'src/session/http_data_source.dart';
export 'src/session/http_data_source_impl.dart';

// Models
export 'src/models/fa_submission.dart';
export 'src/models/fa_comment.dart';
export 'src/models/fa_journal.dart';
export 'src/models/fa_note.dart';
export 'src/models/fa_note_preview.dart';
export 'src/models/fa_notification_preview.dart';
export 'src/models/fa_user.dart';
export 'src/models/fa_user_gallery_like.dart';
export 'src/models/fa_user_journals.dart';
export 'src/models/fa_watchlist.dart';
export 'src/models/dynamic_thumbnail.dart';

// Pages (low-level)
export 'src/pages/fa_urls.dart';
export 'src/pages/fa_page.dart';
export 'src/pages/fa_pages_error.dart';
export 'src/pages/fa_home_page.dart';
export 'src/pages/fa_submission_page.dart';
export 'src/pages/fa_submissions_page.dart';
export 'src/pages/fa_journal_page.dart';
export 'src/pages/fa_notifications_page.dart';
export 'src/pages/fa_note_page.dart';
export 'src/pages/fa_notes_page.dart';
export 'src/pages/fa_new_note_page.dart';
export 'src/pages/fa_user_page.dart';
export 'src/pages/fa_user_gallery_like_page.dart';
export 'src/pages/fa_user_journals_page.dart';
export 'src/pages/fa_watchlist_page.dart';

// Navigation
export 'src/navigation/fa_target.dart';

// Login
export 'src/login/fa_login.dart';

// Utilities
export 'src/utils/css_inliner.dart';
export 'src/utils/fa_logger.dart';
