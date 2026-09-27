# FurClient — FurAffinity client (Flutter)

Flutter client for furaffinity.net. Platforms: **Android** (the reference platform, "don't break it") and **Windows** (desktop, fluent_ui). HTML parsing lives in the local `packages/fa_kit` package.


## Commands

- `dart analyze` — static analysis (must be clean).
- `flutter run -d windows --debug` — run the Windows build; `flutter build windows --debug` — build it.
- `flutter test` — app tests; `cd packages/fa_kit && dart test` — parser tests (fixtures in `packages/fa_kit/test/fixtures/`, real HTML only, never synthetic).
- Any paired Android/Windows change must be verified on both sides.

## Architecture

- `lib/services/fa_client.dart` — the heart: all HTML goes through headless/persistent WebViews (`_fetchHtmlWithWebView`, `_navigateFeedWebView`), plus cookies and Cloudflare. Debug prints use the `=== ` prefix.
- `packages/fa_kit` — pure HTML parsers (no I/O), mirrors of the Swift FAKit: `FASubmissionsPage`, `FANotificationsPage`, etc. The feed container is `messagecenter-submissions`, items are `figure[id^="sid-"]`.
- `lib/utils/cookie_manager.dart` (`FAICookieManager`) — CookieManager wrapper; `lib/services/auth_service.dart` — session persisted in SharedPreferences key `fa_session` (JSON cookies).
- Windows: images go through the local `FAImageProxy` (127.0.0.1, port set in `main.dart`), which reads cookies from the `webview2_data` profile.
- UI shells: `lib/navigation/fluent_shell.dart` (Windows) and `material_shell.dart` (mobile).

## Platform rules

- **Android is the reference.** Gate any behavioral change behind `Platform.isWindows`; don't touch Android-only APIs (CronetHttp via `runWithClient` in `main.dart`). Windows-only: `WebViewEnvironment` (the `webview2_data` profile), fluent branches, the marionette binding (debug builds).
- On Windows every WebView (login, headless, dialogs) must use the same `webViewEnvironment` — otherwise they get different cookie stores and endless logouts.

## Cloudflare/cookies — hard-won gotchas

- `cf_clearance` is bound to the native WebView2 UA: **never spoof the User-Agent on Windows** (`_webviewHeaders`), and the UA must be identical across all WebViews. An app version change = new UA = dead clearance.
- `flutter_inappwebview_windows` returns `expiresDate` in **seconds** (CDP) while every other platform uses milliseconds. Always go through `FAICookieManager.normalizeExpiryMs()`, or cookies end up "expired in 1970".
- The cookie store is the source of truth: inject only missing names; on freshLogin purge only the FA session cookies and keep `cf_*` (`cf_chl_rc_ni` is a passive-failure counter that flags the client as it grows).
- Headless WebView2 cannot pass Turnstile on its own → escalate to the visible `_CfChallengeDialog` (same `webViewEnvironment`), then retry once. Challenge detection must use locale-independent markers only (`_cf_chl_opt`, `cf-chl-widget`): the "Just a moment" title is localized ("Один момент…").
- FA thumbnails come only in 200/300/320/400/600 sizes (larger ones redirect); avatar is `a.furaffinity.net/<user>.gif`.
- "New" submissions are client-side sid comparison (`new@72`, `new~<sid>@72`); FA counters are cleared with an explicit POST, never via GET.

## Debugging the live app

- `flutter run -d windows --debug > /c/temp/run.log 2>&1 &` — log to your own file (the harness pipe buffers and stays empty until exit).
- Marionette MCP drives the app: `connect` using the ws-URI from the log, then `tap`/`get_interactive_elements`/`take_screenshots`/`hot_reload`/`hot_restart`. Fallback without MCP tools: `node C:/temp/marionette_call.mjs "<wsUri>" '[["tap",{"text":"Watch"}],["take_screenshots",{}]]'` (screenshots land in `C:/temp/shot_*.png`).
- Two taps in a single marionette call sometimes lose a race — split them into separate calls.
- `hot_restart` breaks `WebViewEnvironment` re-creation (profile file lock) — for `main.dart` changes, restart the whole process instead.
