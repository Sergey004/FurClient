> [!NOTE]
> **Privacy**
>
> FurClient does not use telemetry, analytics, trackers, Firebase, or other
> third-party data collection services. Your Fur Affinity credentials and
> account data are not collected or sold.

# FurClient

An unofficial cross-platform [Fur Affinity](https://www.furaffinity.net/)
client built with Flutter and Dart.

[![CI](https://github.com/Sergey004/FurClient/actions/workflows/ci.yml/badge.svg)](https://github.com/Sergey004/FurClient/actions/workflows/ci.yml)

## Platforms and downloads

| Platform | UI | Background notifications | Build |
|---|---|---|---|
| **Android** | Material 3 / Material You | `workmanager`, without Google Play Services | `flutter build apk --release` |
| **Windows** | Fluent UI | In-process timer while the app is running | `flutter build windows --release` |

Release packages are available from
[GitHub Releases](https://github.com/Sergey004/FurClient/releases):

- Android: APK and AAB.
- Windows: Velopack packages with update support.

## Features

### Account and networking

- WebView-based Fur Affinity login with persistent cookie storage.
- Automatic session restoration and validation.
- Locale-independent Cloudflare challenge detection and cookie synchronization.
- Visible Cloudflare resolver on Windows when a headless WebView cannot pass
  the challenge automatically.
- Configurable HTML transport in Settings:
  - **Auto** — use direct HTTP when the session and Cloudflare clearance allow
    it, with a safe WebView fallback.
  - **HTTP** — prefer direct HTTP for eligible page reads.
  - **WebView** — use the WebView path.
- Cronet on Android and Dart HTTP on Windows for supported requests.
- WebView remains available for login, Cloudflare, AJAX pages, and requests
  that cannot use direct HTTP.

### Content

- Gallery/Browse with adaptive grids, categories, and pagination.
- Watch Feed with favorite-state restoration and progressive updates.
- Search with author, tags, ratings, content types, date range, sorting, and
  search history.
- Submission and journal details with comments.
- Favorite, watch, and comment actions.
- User profiles with stats, biography, quick links, and a shouts wall.
- User galleries, favorites, journals, and watchlists through profile links.
- Notes inbox, note reading, replies, and new-note composition.

### Notifications

Six independently configurable background categories:

- New submissions from watched artists.
- Notes.
- Submission comments.
- Journal comments.
- Shouts.
- Journals from watched artists.

Behavior:

- Android polls periodically with `workmanager` when a network connection is
  available. Exact timing still depends on Android power management.
- Windows polls every 30 minutes **only while the application is running**.
- The first successful poll seeds watermarks without posting the existing
  backlog. Subsequent polls compare numeric IDs to avoid duplicates.
- Disabled categories advance their watermarks, so enabling a category later
  does not replay old events.
- Android registers all nine notification channels at startup, including
  Downloads, System, and Favorites alongside the six polling categories.
- Notification taps restore the session before routing when necessary.
- Submission notifications carry a preview for immediate rendering.
- Shout notifications open the profile and scroll to the highlighted shout.
- Cloudflare service notifications are throttled to avoid repeated alerts.
- Parallel downloads use separate notification IDs and do not overwrite each
  other's progress.

### Downloads

- Automatic download on favorite can be enabled independently.
- Default Android destination:

  ```text
  Download/furaffinity/{rating}/{author}/{original_filename}
  ```

- A user-selected folder uses:

  ```text
  {selected_folder}/furaffinity/{rating}/{author}/{original_filename}
  ```

- Original filenames are preserved when available.
- Existing files are skipped instead of duplicated.
- Folder write tests and explicit notifications make permission/fallback
  problems visible.
- If the selected or public folder is unavailable, the app falls back to an
  app-specific storage directory.

### Interface and accessibility

- **Android:** Material 3, Material You dynamic colors on supported devices,
  bottom navigation/navigation rail, and a high-refresh-rate mode.
- **Windows:** Fluent navigation, dialogs, controls, system accent color,
  light/dark/system themes, and custom window chrome.
- Touch-aware refresh controls: pull-to-refresh on touch devices and refresh
  buttons for pointer/desktop use.
- Adaptive sheets, dialogs, lists, and favorite controls for each platform.
- Optional haptic feedback.
- SFW mode synchronized with Fur Affinity's `sfw_toggle` cookie.

## Requirements

- **Flutter 3.50.0** on the stable channel (the version pinned in CI).
- **Java 17** for Android builds.
- **Microsoft WebView2 Runtime** on Windows.
- **.NET 8** only if you want to create Velopack release packages locally.

## Getting started

```bash
flutter pub get

# Install the local parser package's dependencies as well
cd packages/fa_kit
flutter pub get
cd ../..

# Run on Windows
flutter run -d windows --debug

# Run on a connected Android device or emulator
flutter devices
flutter run -d <device_id> --debug
```

## Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Windows
flutter build windows --release
```

Outputs:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
build/windows/x64/runner/Release/
```

## Analysis and tests

```bash
dart analyze
flutter test

cd packages/fa_kit
dart test
cd ../..
```

The `fa_kit` parser tests use real-page HTML fixtures. The application tests
also cover notification watermarks, category filtering, ordering, Cloudflare
throttling, channel configuration, and notification payload handling.

## Project structure

```text
furclient/
├── lib/
│   ├── main.dart                       # Startup, session restore, scheduling,
│   │                                   # notification taps, deep links
│   ├── navigation/                    # Fluent and Material application shells
│   ├── screens/                       # Gallery, Watch, Search, Notifications,
│   │                                   # Profile, Notes, Settings, details
│   ├── models/                        # Application models and UserSession
│   ├── services/
│   │   ├── fa_client.dart             # Session, cookies, Cloudflare, HTML/API
│   │   ├── page_transport.dart        # Direct HTTP transport and fallback
│   │   ├── notification_poller.dart   # Six-category diff and watermark logic
│   │   ├── download_service.dart      # Storage paths and downloads
│   │   └── update_service.dart        # Platform update handling
│   ├── utils/
│   │   ├── notifications.dart         # Channels, posting, tap dispatch
│   │   ├── touch_mode.dart            # Windows touch-input detection
│   │   └── cookie_manager.dart        # Platform cookie normalization
│   ├── widgets/adaptive/               # Adaptive switches, sheets, refresh, etc.
│   └── theme/                         # Material and Fluent theme builders
├── packages/fa_kit/                   # Pure HTML parsers and models, no I/O
├── test/                              # Application and widget tests
├── android/                           # Android host project and permissions
├── windows/                           # Windows host project
└── .github/workflows/                 # CI and tagged release builds
```

## Supported deep links

| URL pattern | Result | Status |
|---|---|---|
| `https://www.furaffinity.net/view/{id}/` | Submission detail | Supported |
| `https://www.furaffinity.net/journal/{id}/` | Journal detail | Supported |
| `https://www.furaffinity.net/msg/pms/{id}/` | Note detail | Supported |
| `https://www.furaffinity.net/user/{username}/#shout-{id}` | Profile with the target shout highlighted | Supported |
| `https://www.furaffinity.net/user/{username}/` | User content | Supported |
| `furaffinity://view/{id}/` | Submission detail | Supported |
| Gallery/favorites/journals/watchlist URL variants | Shell-level routing | Partial |

## CI and releases

GitHub Actions runs on pushes and pull requests to `master` and `dev`:

1. Static analysis and both test suites.
2. Android debug APK build.
3. Windows release build.

Tags matching `v*` trigger the release workflow and publish Android APK/AAB
artifacts plus Windows Velopack packages.

## Current limitations

- There are no background notifications on Windows after the application is
  closed.
- Incoming favorite and watch events are not polled as notification categories.
- Journal/shout publishing and submission upload are not implemented.
- Some gallery, favorites, journals, and watchlist deep links still need
  shell-level navigation.
- The image-quality preference is present in Settings but is not yet applied
  consistently to image loading.

## Authentication details

1. Fur Affinity's login page is opened in a WebView; the password is not passed
   to application code.
2. After login, cookies are captured and essential session cookies are checked.
3. Cookies are persisted in `SharedPreferences` and synchronized with the
   WebView store, HTTP cookie jar, and image-loading layer.
4. Startup verification treats a Cloudflare interstitial as a solvable network
   state rather than immediately deleting the saved session.

## License

See [LICENSE](LICENSE).

## Note for FA staff

If this app causes any interference with the servers, development will be
stopped immediately.
