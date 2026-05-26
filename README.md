# FurClient — Fur Affinity Client

A cross-platform Fur Affinity client built with Flutter & Dart.

## Platforms

| Platform | Tech | Build Command |
|---|---|---|
| Windows | Flutter (WinUI 3 style) | `flutter build windows` |
| Linux | Flutter (GNOME style) | `flutter build linux` |
| macOS | Flutter (Cupertino style) | `flutter build macos` |
| Android | Flutter (Material 3) | `flutter build apk` |
| iOS | Flutter (Cupertino) | `flutter build ios` |

## Design System

FurClient adapts its UI to match the host OS design language (see [DESIGN.md](DESIGN.md)):

- **Desktop** (Windows/Linux/macOS) — Fluent WinUI 3 layout: sidebar navigation, Mica-style transparency, cyan `#60cdff` accents, rectangular inputs
- **Mobile** (Android/iOS) — Material 3 / Material You layout: bottom navigation bar, pill indicators, lavender `#e8def8` accents, capsule inputs, rounded-2xl cards
- **Color-coded navigation** — each tab has a distinct accent color (Gallery=cyan, Search=green, Notifications=purple, Profile=lavender)
- **Dynamic color** — Material You wallpaper-derived colors on Android 12+, OS accent color on desktop

## Commands

```bash
# Setup
flutter pub get

# Development
flutter run -d linux
flutter run -d windows
flutter run -d chrome
flutter run -d <device_id>

# Build
flutter build linux
flutter build windows
flutter build apk --release
flutter build ios --release

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
    services/
      auth_service.dart    — Session storage, WebView login flow
      fa_client.dart       — Dio HTTP client with cookie jar, CF handling
      fa_urls.dart         — FA URL builders
    models/
      submission.dart      — Submission model with HTML parsing
      fa_notification.dart — Notification model with type detection
      fa_user.dart         — User profile model with HTML parsing
      fa_comment.dart      — Comment model
      user_session.dart    — Session/cookie model
    widgets/
      submission_card.dart — Reusable submission card
      loading_indicator.dart
      error_view.dart
```

## Authentication

FurClient uses WebView-based login (same approach as the iOS reference app `FurAffinityApp`):

1. Opens FA login page in `flutter_inappwebview`
2. Captures cookies after successful login
3. Stores cookies in `PersistCookieJar` for Dio requests
4. All HTTP requests carry the FA session cookies
5. `verifySession()` validates cookies on app launch (lenient on 5xx)

## Git Workflow

```bash
git add .
git commit -m "description"
git push
git pull
```
