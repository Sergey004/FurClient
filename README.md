**This app never leaks data and does not use telemetry or trackers.**

# FurClient — Fur Affinity Client

A cross-platform Fur Affinity client built with Flutter & Dart.

## Platforms

| Platform | Tech | Build Command |
|---|---|---|
| Windows | Flutter (WinUI 3 style) | `flutter build windows` |
| Android | Flutter (Material 3) | `flutter build apk` |

## Design System

FurClient adapts its UI to match the host OS design language (see [DESIGN.md](DESIGN.md)):

- **Desktop** (Windows) — Fluent WinUI 3 layout: sidebar navigation, Mica-style transparency, cyan `#60cdff` accents, rectangular inputs
- **Mobile** (Android) — Material 3 / Material You layout: bottom navigation bar, pill indicators, lavender `#e8def8` accents, capsule inputs, rounded-2xl cards
- **Color-coded navigation** — each tab has a distinct accent color (Gallery=cyan, Search=green, Notifications=purple, Profile=lavender)
- **Dynamic color** — Material You wallpaper-derived colors on Android 12+, OS accent color on desktop

## Commands

```bash
# Setup
flutter pub get

# Development
flutter run -d windows
flutter run -d <device_id>

# Build
flutter build windows
flutter build apk --release

# Analysis
flutter analyze
```

## Project Structure

```
furclient/
  lib/
    main.dart              — App entry, DynamicColorBuilder, session restore
    theme/
      app_theme.dart       — Color system, breakpoints, adaptive theme
    navigation/
      app_navigator.dart   — NavigationRail (desktop) / NavigationBar (mobile)
    screens/
      login_screen.dart    — WebView-based FA login
      gallery_screen.dart  — Browse submissions with adaptive grid
      search_screen.dart   — Search with history
      notifications_screen.dart — Color-coded notification types
      profile_screen.dart  — User profile with desktop sidebar layout
      settings_screen.dart — Adaptive Fluent/M3 toggles
      submission_detail_screen.dart — Side-by-side desktop / scroll mobile
      user_content_screen.dart        — Detailed user content view
      journal_detail_screen.dart     — Journal specific views
    services/
      auth_service.dart    — Session storage, WebView login flow
      fa_client.dart       — Dio HTTP client, cookie jar, Cloudflare handling
      cdn_fetcher.dart     — CDN source resolving
      download_service.dart — Asset downloading logic
      fa_urls.dart         — FA URL builders
      cookie_helper.dart   — Cookie parsing and manipulation
    models/
      submission.dart      — Submission model with HTML parsing
      fa_notification.dart — Notification model with type detection
      fa_user.dart         — User profile model
      fa_comment.dart      — Comment model
      user_session.dart    — Session/cookie persistence model
      fa_journal.dart      — Journal content models
    widgets/
      submission_card.dart — Reusable submission card
      loading_indicator.dart
      error_view.dart
    utils/
      cloudflare_bypass.dart — Cloudflare handling
      cdn_image_loader.dart — Optimized image fetching logic
```

## Features

### Core Features (100% implemented)

- **Authentication**: WebView-based login with cookie persistence
- **Session Management**: Automatic session restore and validation
- **Navigation**: Adaptive navigation (NavigationRail on desktop, NavigationBar on mobile)
- **Submission Browsing**: Gallery view with pagination and filtering
- **Search**: Search submissions with history and results
- **Notifications**: View and manage notifications
- **User Profiles**: Browse user content (submissions, journals, stats)
- **Settings**: Theme, SFW mode, download preferences

### Content Features (90-95% implemented)

- **Submissions**: View details, comments, favorites, adoption status
- **Journals**: Read and manage journal entries
- **Gallery**: Browse user galleries
- **Watchlist**: Track users you're watching
- **Favorites**: View favorited submissions
- **Notes**: Inbox/outbox note management
- **Download**: Save images directly from the app

### Navigation Features (95% implemented)

- **Deep Links**: AppLinks integration for `/view/{id}`, `/user/{name}`, `/gallery/{name}`, `/journal/{id}`, `/favorites/{name}`, etc.
- **History**: Navigation stack support
- **Cross-platform**: Adaptive routing for desktop and mobile

### Supported Deep Link URLs

| URL Pattern | Target Type | Implementation Status |
|---|---|---|
| `https://www.furaffinity.net/view/{id}/` | submission | ✅ Done |
| `https://www.furaffinity.net/journal/{id}/` | journal | ✅ Done |
| `https://www.furaffinity.net/user/{username}/` | user | ✅ Done |
| `https://www.furaffinity.net/gallery/{username}/` | gallery | ✅ Done |
| `https://www.furaffinity.net/favorites/{username}/` | favorites | ✅ Done |
| `https://www.furaffinity.net/journals/{username}/` | journals | ✅ Done |
| `https://www.furaffinity.net/watchlist/to/{username}/` | watchlist | ✅ Done |
| `https://www.furaffinity.net/watchlist/by/{username}/` | watchlist | ✅ Done |
| `furaffinity://view/{id}/` | submission | ✅ Done |

### Platform-Specific Features

- **Windows**: Native WebView2 integration, automatic Cloudflare bypass, system theme support
- **Android**: Material You dynamic colors, notification support, file downloads

### Technical Features

- **Cookie Management**: Automatic cookie extraction from WebView (including HttpOnly cookies)
- **Image Handling**: Optimized image loading with caching, progressive images
- **HTTPS Everywhere**: All network requests use HTTPS
- **Error Handling**: Graceful fallback for network errors and parsing failures

## Feature Implementation Status

| Feature | Status | Notes |
|---|---|---|
| User Login | ✅ | WebView-based, includes MFA support for MFA-protected accounts |
| Session Restore | ✅ | Cookies and session data persisted locally |
| Submission View | ✅ | Details, comments, full-size image |
| Journal View | ✅ | Text, images, navigation |
| Gallery View | ✅ | Grid layout, pagination |
| User Profile | ✅ | Stats, avatar, content links |
| Search | ✅ | Keyword search, filters, history |
| Notifications | ✅ | Color-coded by type |
| Favorites | ✅ | User's favorites page |
| Watchlist | ✅ | Following/Watched by views |
| Notes | ⚠️ | View only, compose not implemented |
| Content Filters | ⚠️ | Basic SFW toggle only |
| Two-Factor Auth | ✅ | Works through WebView login |

## Authentication

FurClient uses a WebView-based login (consistent with the approach used in the original mobile app):

1. **WebView Login**: The FurAffinity login page is opened via `flutter_inappwebview`.
2. **Cookie Capture**: After successful authentication, the application captures cookies from the WebView.
3. **Persistence & Sync**: 
    *   Cookies are saved to local storage (`CookieStore`) for automatic use by the Dio library.
    *   User profile and session data are cached in `SharedPreferences` (via `UserSession`).
4. **Validation**: On app startup, `verifySession()` is executed to validate current cookies (handling transient 5xx errors).

## Git Workflow

```bash
git add .
git commit -m "description"
git push
git pull
```

## Note for FA Stuff

If this app is causing any interference with the servers, I'll stop "developing" it right away.
