# WebView2 Cookie Extraction Debug

## Problem Analysis

Following the COOKIES_WEBVIEW2.md documentation, the issue was:
1. **FAICookieManager.instance()** should use `webViewEnvironment` on Windows
2. **CookieManager without webViewEnvironment** reads system WebView2 profile instead of our `webview2_data` profile
3. System profile contains random cookies from Edge/system instead of FA cookies

## Current Implementation Status

### ✅ Correctly Implemented
`FAICookieManager.instance()` already uses `webViewEnvironment`:
```dart
static CookieManager get instance {
  if (io.Platform.isWindows) {
    return CookieManager.instance(webViewEnvironment: webViewEnvironment);
  }
  return CookieManager.instance();
}
```

### ❌ Issues Found

1. **DateTime Type Cast Error** (Already Fixed)
   - `flutter_inappwebview.Cookie.expiresDate` can be `DateTime` OR `int`
   - Code tried to cast directly to `DateTime` → Crash
   - Fix: Handle both types

2. **Insufficient Debug Logging** (Now Fixed)
   - No visibility into what cookies CookieManager returns
   - No visibility into webViewEnvironment creation
   - No visibility into session restoration process

## Changes Made

### 1. cookie_manager.dart:instance() - Enhanced Logging

```dart
static CookieManager get instance {
  if (io.Platform.isWindows) {
    if (webViewEnvironment == null) {
      debugPrint('=== FAICookieManager WARNING: webViewEnvironment is null on Windows!');
    }
    final cm = CookieManager.instance(webViewEnvironment: webViewEnvironment);
    debugPrint('=== FAICookieManager: Created CookieManager for Windows with webViewEnvironment: ${webViewEnvironment != null}');
    return cm;
  }
  debugPrint('=== FAICookieManager: Created CookieManager for non-Windows platform');
  return CookieManager.instance();
}
```

### 2. cookie_manager.dart:getFACookies() - Enhanced Logging

```dart
static Future<Map<String, Cookie>> getFACookies() async {
  debugPrint('=== FAICookieManager: Getting all cookies from WebViewManager');
  debugPrint('=== FAICookieManager: Current time: ${DateTime.now().toIso8601String()}');

  final cookies = await getCookies('https://www.furaffinity.net');
  debugPrint('=== FAICookieManager: Got ${cookies.length} cookies total: ${cookies.map((c) => c.name).join(", ")}');
  for (final cookie in cookies) {
    debugPrint('=== FAICookieManager:   - ${cookie.name} (domain: ${cookie.domain}, path: ${cookie.path}, httpOnly: ${cookie.isHttpOnly}, secure: ${cookie.isSecure}, expires: ${cookie.expiresDate})');
  }
  return {for (final c in cookies) c.name: c};
}
```

### 3. cookie_manager.dart:syncFromWebView() - Enhanced Logging

```dart
static Future<void> syncFromWebView(InAppWebViewController controller) async {
  try {
    final webViewManager = instance;
    debugPrint('=== FAICookieManager: Starting WebView sync');

    final cookies = await webViewManager.getCookies(
      url: WebUri('https://www.furaffinity.net'),
    );

    debugPrint('=== FAICookieManager: Got ${cookies.length} cookies from WebViewManager');
    for (final cookie in cookies) {
      debugPrint('=== FAICookieManager:   - ${cookie.name} (domain: ${cookie.domain}, path: ${cookie.path}, httpOnly: ${cookie.isHttpOnly}, secure: ${cookie.isSecure}, expires: ${cookie.expiresDate})');

      // Handle both DateTime and int (millisecondsSinceEpoch) for expiresDate
      int? expiresDate;
      if (cookie.expiresDate != null) {
        if (cookie.expiresDate is DateTime) {
          expiresDate = cookie.expiresDate.millisecondsSinceEpoch;
        } else if (cookie.expiresDate is int) {
          expiresDate = cookie.expiresDate;
        } else {
          expiresDate = 0;
        }
      }

      _cookies[cookie.name] = _CookieEntry(
        name: cookie.name,
        value: cookie.value ?? '',
        domain: cookie.domain ?? '.furaffinity.net',
        path: cookie.path ?? '/',
        expiresDate: expiresDate,
        isHttpOnly: cookie.isHttpOnly ?? false,
        isSecure: cookie.isSecure ?? true,
      );
    }

    _saveCookies();
    debugPrint('=== FAICookieManager: Synced ${cookies.length} cookies to internal storage, total ${_cookies.length} cookies');
  } catch (e) {
    debugPrint('=== FAICookieManager: WebView sync failed: $e');
  }
}
```

### 4. main.dart:_initApp() - Enhanced Logging

```dart
Future<void> _initApp() async {
  try {
    debugPrint('=== _initApp: Starting application initialization');
    await _client.init();
    debugPrint('=== _initApp: FAClient initialized');
    await _authService.loadSavedSession();
    debugPrint('=== _initApp: Session loaded: ${_authService.currentSession != null}');
    final session = _authService.currentSession;

    if (session != null && session.isLoggedIn) {
      debugPrint('=== _initApp: Restoring session for user: ${session.username}');
      await _client.setSession(session);
      final valid = await _client.verifySession();
      debugPrint('=== _initApp: Session verification result: $valid');
      if (valid) {
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _isRestoringSession = false;
          });
        }
        return;
      } else {
        debugPrint('=== _initApp: Session invalid, logging out');
        await _authService.logout();
      }
    } else {
      debugPrint('=== _initApp: No valid session to restore');
    }
  } catch (e) {
    debugPrint('Init error: $e');
  }

  if (mounted) {
    setState(() {
      _isLoggedIn = false;
      _isRestoringSession = false;
    });
  }
}
```

### 5. main.dart:webViewEnvironment Creation - Enhanced Logging

```dart
if (Platform.isWindows) {
  final availableVersion = await WebViewEnvironment.getAvailableVersion();
  assert(availableVersion != null, 'WebView2 Runtime not found.');
  final dir = await getApplicationSupportDirectory();
  debugPrint('=== Creating WebViewEnvironment with webview2_data profile at: ${dir.path}\\webview2_data');
  webViewEnvironment = await WebViewEnvironment.create(
    settings: WebViewEnvironmentSettings(
      userDataFolder: '${dir.path}\\webview2_data',
      additionalBrowserArguments: '--disable-gpu --use-gl=swiftshader',
    ),
  );
  debugPrint('=== WebViewEnvironment created successfully, version: $availableVersion');
  // Запускаем прокси для FA CDN — читает cookies из webview2_data профиля
  await FAImageProxy().start();
}
```

## Expected Debug Output

### App Startup
```
=== _initApp: Starting application initialization
=== Creating WebViewEnvironment with webview2_data profile at: C:\Users\...\AppData\Roaming\FurClient\webview2_data
=== WebViewEnvironment created successfully, version: 1.0.2403.15
=== FAICookieManager: Created CookieManager for Windows with webViewEnvironment: true
=== _initApp: FAClient initialized
=== FAICookieManager: Loaded 3 cookies from storage (if saved session exists)
```

### Login Flow
```
=== FAICookieManager: Created CookieManager for Windows with webViewEnvironment: true
=== FAImageProxy: Started on 127.0.0.1:47652
=== FAICookieManager: Getting all cookies from WebViewManager
=== FAICookieManager: Got 3 cookies total: a, b, sz
=== FAICookieManager:   - a (domain: .furaffinity.net, path: /, httpOnly: true, secure: true, expires: 1719788400000)
=== FAICookieManager:   - b (domain: .furaffinity.net, path: /, httpOnly: true, secure: true, expires: 1719788400000)
=== FAICookieManager:   - sz (domain: www.furaffinity.net, path: /, httpOnly: false, secure: true, expires: 0)
=== Cookie validation passed: Valid
=== Session saved, completing login
=== _onLogin() called
=== Session appears valid
=== _onLogin() completed successfully
```

## Next Steps

1. **Run the app** and capture the full debug logs
2. **Check if** webViewEnvironment is created successfully
3. **Check if** CookieManager returns 3 cookies (a, b, sz)
4. **Check if** domain/path matches expected values
5. **If still only 1 cookie**, investigate:
   - WebView might not be setting cookies correctly
   - Domain/path mismatch in cookie headers
   - Session might be invalid after Cloudflare challenge

## Key Takeaways from COOKIES_WEBVIEW2.md

✅ **Correct:** `FAICookieManager` uses `webViewEnvironment` on Windows
✅ **Correct:** Uses `CookieManager.instance(webViewEnvironment: webViewEnvironment)` instead of default
✅ **Correct:** Falls back to `document.cookie` for non-HttpOnly cookies
✅ **Important:** HttpOnly cookies (a, b, cf_clearance) must be read via CookieManager, not document.cookie
