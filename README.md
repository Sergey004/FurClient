> [!NOTE]
> Privacy
>
> This app does not use telemetry, analytics, trackers, Firebase, or other third-party data collection services.
>
> Your Fur Affinity credentials and account data are not collected or sold.

# FurClient — unofficial Fur Affinity client for Android and Windows

A cross-platform Fur Affinity client built with Flutter & Dart.

## Platforms

| Platform | Tech | Build Command |
|---|---|---|
| Windows | Flutter (WinUI 3 style) | `flutter build windows` |
| Android | Flutter (Material 3) | `flutter build apk` |

## Design System

FurClient adapts its UI to match the host OS design language (see [DESIGN.md](DESIGN.md)):

- **Desktop** (Windows) — Fluent WinUI 3 layout: sidebar navigation, custom window chrome, cyan `#60cdff` accents, rectangular inputs
- **Mobile** (Android) — Material 3 / Material You layout: bottom navigation bar, pill indicators, lavender `#e8def8` accents, capsule inputs, rounded-2xl cards
- **Color-coded navigation** — each tab has a distinct accent color (Gallery=cyan, Watch=teal, Search=green, Notifications=purple, Profile=lavender)
- **Dynamic color** — Material You wallpaper-derived colors on Android 12+, OS accent color on desktop
- **High refresh rate** — pins the display's max refresh mode on Android (no 60↔120 Hz jumping on LTPO panels)

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

# Analysis & tests
dart analyze
flutter test
cd packages/fa_kit && dart test   # HTML parser tests (real-page fixtures)
```

## Project Structure

```
furclient/
  lib/
    main.dart              — App entry, session restore, CF challenge dialog,
                             background task dispatcher, deep links
    theme/
      app_theme.dart       — Color system, breakpoints, adaptive theme
    navigation/
      adaptive_shell.dart  — FluentShell (Windows) / MaterialShell (mobile)
      fluent_shell.dart    — Fluent navigation pane, SFW sync, sign out
      material_shell.dart  — Bottom bar / NavigationRail, SFW sync
    screens/
      login_screen.dart    — WebView-based FA login with cookie capture
      gallery_screen.dart  — Browse submissions with adaptive grid
      watch_feed_screen.dart — Watched-users feed (new@72 cursors)
      search_screen.dart   — Search with filters, sort and history
      notifications_screen.dart — Color-coded notification types
      profile_screen.dart  — Profile stats, bio, quick links, shouts wall
      settings_screen.dart — Theme, SFW, downloads, updates (Fluent/M3)
      submission_detail_screen.dart — Side-by-side desktop / scroll mobile
      user_content_screen.dart        — User gallery / favorites / journals
      journal_detail_screen.dart      — Journal content and comments
    services/
      auth_service.dart    — Session storage, WebView login flow
      fa_client.dart       — WebView-based HTML fetching, cookies,
                             Cloudflare escalation, background parsing
      notification_poller.dart — Background notification polling
      update_service.dart  — GitHub Releases updater (Velopack on Windows)
      download_service.dart — Asset downloading logic
      fa_urls.dart         — FA URL builders
    packages/fa_kit        — Pure HTML parsers & models (no I/O), mirrors
                             the Swift FAKit reference implementation
    models/
      submission.dart      — Submission model
      fa_notification.dart — Notification model with type detection
      fa_user.dart         — User profile, stats and shouts
      user_session.dart    — Session/cookie persistence model
    utils/
      cookie_manager.dart  — CookieManager wrapper (per-platform quirks)
      fa_image_loader.dart — FAImage/FAAvatar widgets
      webview_image_fetcher.dart — Headless WebView image pool (2 workers)
      fa_image_proxy.dart  — Local image proxy for HTML content (Windows)
      notifications.dart   — Local notification channels and posting
```

## Features

### Implemented

- **Authentication**: WebView-based login with cookie persistence and validation
- **Session Management**: Automatic restore; Cloudflare interstitials no longer
  log you out — they are resolved lazily where they appear
- **Cloudflare handling**: locale-independent challenge detection, passive
  retries, visible Turnstile resolver dialog (Windows), `cf-mitigated` header
  checks, CF cookie hygiene (see [AGENTS.md](AGENTS.md) for the gritty details)
- **Navigation**: Adaptive shell — Fluent pane on Windows, bottom bar/rail on mobile
- **Submission Browsing**: Gallery/Browse with category chips and pagination
- **Watch Feed**: watched-users feed with favorite-state restore and
  progressive heart updates
- **Search**: full filters (author, tags, ratings, types, date range, sort) and history
- **Notifications tab**: color-coded by type (shouts, journals, comments, faves)
- **Background Notifications**: periodic polling via `workmanager` (no Google
  Play Services — falls back to AlarmManager), per-category channels, tap →
  deep link, "Cloudflare check required" service notification
- **User Profiles**: stats (fixed for the beta theme's responsive labels),
  bio, quick links, **shouts wall**
- **Settings**: theme, SFW mode (synced with the site's `sfw_toggle` cookie),
  image quality, download folder, per-app updates
- **Downloads**: structured save paths `{rating}/{author}/{file}` with
  progress notifications
- **Updates**: in-app updater — Velopack on Windows, `upgrader` on Android
- **Image Pipeline**: shared WebView image pool (2 workers), 3-layer cache,
  local image proxy for HTML content on Windows, thumbnail size negotiation
- **Smoothness**: HTML parsing runs in background isolates (`Isolate.run`),
  parallel image/feed/favorites fetching, pinned high refresh rate

### Not implemented yet

- **Notes (PMs)**: parsers exist in `packages/fa_kit`; no UI yet
- **Watchlist browsing**: parser exists; no UI yet
- **Posting journals/shouts/notes**: only comments, favorites and watch
  toggles are wired
- **Submission upload**

## Supported Deep Link URLs

| URL Pattern | Target Type | Status |
|---|---|---|
| `https://www.furaffinity.net/view/{id}/` | submission | ✅ |
| `https://www.furaffinity.net/journal/{id}/` | journal | ✅ |
| `https://www.furaffinity.net/user/{username}/` | user | ✅ |
| `https://www.furaffinity.net/gallery/{username}/` | gallery | ✅ |
| `https://www.furaffinity.net/msg/pms/{id}/` | note | ⚠️ stub (no notes UI) |
| `furaffinity://view/{id}/` | submission | ✅ |

## Platform-Specific Notes

- **Windows**: WebView2 (shared environment for login/headless/dialogs —
  mixing environments breaks cookies), local image proxy on `127.0.0.1`,
  Velopack-based updates, Fluent window chrome
- **Android**: Material You dynamic colors, local notifications +
  `workmanager` background polling (GMS-free), App Links
  (`https://*.furaffinity.net`), MANAGE_EXTERNAL_STORAGE for downloads

## Authentication

FurClient uses a WebView-based login (the password never touches app code):

1. **WebView Login**: the FurAffinity login page is opened via `flutter_inappwebview`.
2. **Cookie Capture**: after successful authentication the app captures
   cookies (CookieManager + `document.cookie` strategies) and validates the
   essential ones.
3. **Persistence & Sync**: cookies are stored in `SharedPreferences`
   (`UserSession`) and mirrored into the WebView cookie store, Dio's cookie
   jar and the in-memory `CookieStore` for image loaders.
4. **Validation**: on startup the session is verified against the FA homepage;
   a Cloudflare interstitial is treated as "session alive" — it resolves
   lazily via the challenge resolver instead of forcing a re-login.

## Note for FA Stuff

If this app is causing any interference with the servers, I'll stop "developing" it right away.
