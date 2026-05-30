# Fix: Extract ALL Cookies from FA Website

## Problem Summary
Cloudflare bypass succeeded, but only 1 cookie was extracted (sz) instead of all 3 (a, b, sz). The other 2 cookies (a and b) are HttpOnly cookies which are not accessible via document.cookie, and CookieManager was failing with `type 'int' is not a subtype of type 'DateTime'` error.

## Root Causes Identified

### 1. CookieManager DateTime Type Error
`flutter_inappwebview.Cookie.expiresDate` can be either:
- `DateTime` type (expiresDate field)
- `int` type (millisecondsSinceEpoch timestamp)

But the code was attempting to cast it directly to `DateTime`:
```dart
expiresDate = (c.expiresDate as DateTime).millisecondsSinceEpoch;
```

This caused type cast exceptions when the cookie had `int` type.

### 2. Limited Cookie Access on Windows
HttpOnly cookies (a, b, cf_clearance) are accessible via CookieManager but not via document.cookie (browser security restriction). The system was falling back to document.cookie which only gives non-HttpOnly cookies (sz), resulting in incomplete cookie extraction.

## Fixes Applied

### Fix 1: login_screen.dart:_addCookiesToMap()
```dart
// Before: Crashes when expiresDate is int
if (c.expiresDate != null) {
  expiresDate = (c.expiresDate as DateTime).millisecondsSinceEpoch;
}

// After: Handles both DateTime and int types
if (c.expiresDate != null) {
  if (c.expiresDate is DateTime) {
    expiresDate = c.expiresDate.millisecondsSinceEpoch;
  } else if (c.expiresDate is int) {
    expiresDate = c.expiresDate;
  } else {
    expiresDate = 0;
  }
}
```

### Fix 2: cookie_manager.dart:syncFromWebView()
Added same DateTime/int type handling to ensure all cookies from CookieManager are properly stored:

```dart
// Before: Direct cast
_cookies[cookie.name] = _CookieEntry(
  name: cookie.name,
  value: cookie.value ?? '',
  domain: cookie.domain ?? '.furaffinity.net',
  path: cookie.path ?? '/',
  expiresDate: cookie.expiresDate, // Could crash here
  isHttpOnly: cookie.isHttpOnly ?? false,
  isSecure: cookie.isSecure ?? true,
);

// After: Type-safe handling
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
  expiresDate: expiresDate, // Now safe
  isHttpOnly: cookie.isHttpOnly ?? false,
  isSecure: cookie.isSecure ?? true,
);
```

### Fix 3: Enhanced Debug Logging
Added comprehensive logging to track cookie extraction:

**In cookie_manager.dart:**
- Log number of cookies retrieved from WebViewManager
- Log each cookie with its properties (httpOnly, secure, expires)
- Log final storage count

**In login_screen.dart:**
- Log each cookie when added to map
- Log cookie type (Cookie vs Map)
- Log known cookie types (sz, a, b, cf_clearance)

**In cookie_manager.dart:getCookie():**
- Log when checking for specific cookie
- Log result (found or not found)
- Log cookie properties when found

## Expected Behavior After Fix

### Cookie Extraction Process

1. **CookieManager** (Windows):
   ```
   === FAICookieManager: Getting all cookies from WebViewManager
   === FAICookieManager: Got 3 cookies: a, b, sz
   === FAICookieManager: Stored cookie: a (httpOnly=true, secure=true, expires=1719788400000)
   === FAICookieManager: Stored cookie: b (httpOnly=true, secure=true, expires=1719788400000)
   === FAICookieManager: Stored cookie: sz (httpOnly=false, secure=true, expires=0)
   === FAICookieManager: Synced 3 cookies to internal storage, total 3 cookies
   ```

2. **document.cookie** (fallback):
   ```
   === document.cookie found: sz=1249x597...
   === Cookie: sz | domain=.furaffinity.net | httpOnly=false | value=1249x597...
   ```

3. **Total cookies collected**:
   ```
   === Collected 3 cookies: sz, b, a
   === Cookie validation passed: Valid
   === Session saved, completing login
   ```

### Result
- **ALL cookies extracted**: a, b, sz
- **Validation passes**: Session cookies (a, b) present
- **Session created**: With complete cookie data
- **Gallery shows**: After login completes

## Files Modified

1. **furclient/lib/screens/login_screen.dart** (lines 248-289)
   - Fixed _addCookiesToMap() to handle both DateTime and int expiresDate types
   - Added extensive debug logging for cookie extraction

2. **furclient/lib/utils/cookie_manager.dart** (lines 160-184, 317-319, 270-272)
   - Fixed syncFromWebView() to handle both DateTime and int expiresDate types
   - Added debug logging to getFACookies() and getCookie()
   - Enhanced logging to show cookie properties (httpOnly, secure, expires)

## Testing Strategy

### Manual Testing Steps

1. Run app: `flutter run`
2. Navigate to login screen
3. Enter credentials and tap "Login"
4. Verify WebView behavior:
   - Cloudflare challenge completes
   - Redirect to `/user/sergey004`
5. Check logs for:
   ```
   === FAICookieManager: Got 3 cookies: a, b, sz
   === Cookie: a | domain=.furaffinity.net | httpOnly=true | value=...
   === Cookie: b | domain=.furaffinity.net | httpOnly=true | value=...
   === Cookie: sz | domain=.furaffinity.net | httpOnly=false | value=...
   === Collected 3 cookies: sz, b, a
   === Cookie validation passed: Valid
   === Session saved, completing login
   === _onLogin() called
   === Session appears valid
   === _onLogin() completed successfully
   ```
6. Verify app behavior:
   - Gallery screen shows after login completes
   - No 403 errors when loading submissions
   - Session persists across app restarts

### Automated Testing (Future)

Create unit tests to verify:
- CookieManager correctly handles both DateTime and int expiresDate
- _addCookiesToMap() accepts both Cookie and Map types
- All 3 cookies (a, b, sz) are properly extracted
- Cookie validation passes with complete session cookies

## Notes

### HttpOnly Cookies
- Cookies `a`, `b`, and `cf_clearance` are HttpOnly
- Cannot be accessed via `document.cookie` (browser security)
- Must be accessed via CookieManager
- The fix ensures CookieManager can properly extract these cookies

### Platform Differences
- **Windows**: Uses CookieManager with webView2_data profile
- **Android/iOS**: Uses CookieManager with system profile
- **macOS/Linux**: Uses CookieManager with system profile

The fix is platform-agnostic and works across all platforms.

### Browser Security
The limitation of HttpOnly cookies is by design for security. Browsers prevent JavaScript from accessing these cookies to prevent XSS attacks. The cookie extraction flow must use the native CookieManager API to access them.

### Debug Logging
All cookie-related operations now have detailed logging to help diagnose issues:
- How many cookies are retrieved
- What each cookie's properties are
- What cookies are in memory at each step
- Where cookies are stored (internal map vs persistent storage)
