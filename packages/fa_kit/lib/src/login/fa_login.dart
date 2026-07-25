import 'dart:io';

import '../pages/fa_urls.dart';
import '../session/fa_session.dart';
import '../session/http_data_source.dart';
import '../session/online_fa_session.dart';

/// Login manager for FurAffinity.
///
/// Handles the authentication flow:
/// 1. User logs in via FA's website (in a WebView or browser)
/// 2. Cookies are extracted after successful login
/// 3. [OnlineFASession] is created from the cookies
///
/// For Flutter apps, use [FALoginWebView] widget (requires `webview_flutter`).
/// This class provides the core logic without UI dependencies.
class FALoginManager {
  /// The login URL where users enter their credentials.
  Uri get loginUrl => Uri.parse(FAURLs.homeUrl);

  /// Create an [OnlineFASession] from cookies extracted after login.
  ///
  /// Returns null if the cookies don't contain a valid "a" session cookie.
  /// Throws [FASessionError] if the session is invalid.
  ///
  /// Example:
  /// ```dart
  /// final cookies = await extractCookiesFromWebView(); // your implementation
  /// final session = await FALoginManager.makeSession(cookies: cookies);
  /// ```
  static Future<OnlineFASession?> makeSession({
    required List<Cookie> cookies,
    HTTPDataSource? dataSource,
  }) async {
    return OnlineFASession.fromCookies(
      cookies: cookies,
      dataSource: dataSource,
    );
  }

  /// Logout by clearing cookies.
  ///
  /// This simply clears the stored cookies. The actual session cookie
  /// expiration is handled by FA's server.
  static Future<void> logout() async {
    // In a real app, clear stored cookies from SharedPreferences or CookieJar
    // This is a placeholder for the logout logic
  }

  /// Validate that a cookie list contains a valid "a" session cookie.
  bool hasValidSessionCookie(List<Cookie> cookies) {
    return cookies.any((c) => c.name == 'a' && c.value.isNotEmpty);
  }
}

/// Result of the login flow.
class FALoginResult {
  /// The created session, or null if login failed.
  final OnlineFASession? session;

  /// Error message if login failed.
  final String? error;

  const FALoginResult({this.session, this.error});

  bool get isSuccess => session != null;
}

/// A stateful widget that handles FurAffinity login via WebView.
///
/// Requires the `webview_flutter` package. Add it to your `pubspec.yaml`:
/// ```yaml
/// dependencies:
///   webview_flutter: ^4.0.0
/// ```
///
/// Usage:
/// ```dart
/// FALoginWebView(
///   onSessionCreated: (session) {
///     // Store session and navigate to main app
///   },
///   onError: (error) {
///     // Handle login error
///   },
/// )
/// ```
///
/// **Note**: This widget is in a separate file to avoid requiring
/// webview_flutter as a dependency for non-Flutter (server-side) usage.
/// Import it conditionally or copy into your app project.
///
/// This file provides the logic shell. For actual WebView integration,
/// create a widget in your app that uses webview_flutter and calls
/// [FALoginManager.makeSession] when cookies are detected.
class FALoginWebViewPlaceholder {
  /// The URL to load in the WebView for login.
  static Uri get loginUrl => Uri.parse(FAURLs.homeUrl);

  /// The cookie name that indicates a successful login.
  static const String sessionCookieName = 'a';

  /// Check if a set of cookies contains a valid session.
  static bool hasSessionCookie(List<Cookie> cookies) {
    return cookies
        .any((c) => c.name == sessionCookieName && c.value.isNotEmpty);
  }
}
