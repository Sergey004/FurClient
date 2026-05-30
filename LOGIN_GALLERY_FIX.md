# Login to Gallery Transition Fix

## Problem Summary
After login completion, the gallery screen was not showing despite the login flow appearing to succeed. The issue was that:
1. Cookies were saved in Map format but `_restoreCookiesFromSession()` expected List of pairs
2. `_onLogin()` ignored `verifySession()` failures and always showed gallery
3. Cleanup code called `_loginCompleter.complete(null)` instead of the session

## Root Causes Identified

### 1. Cookie Format Mismatch
- **login_screen.dart** saves cookies as: `[{"name": "a", "value": "xxx", "domain": "..."}, ...]`
- **fa_client.dart:_restoreCookiesFromSession()** expected: `[["name", "value"], ...]`
- Result: Cookies never restored → `verifySession()` returns false → unexpected behavior

### 2. Verification Logic Ignored
- Old flow (fe7a4cc): verifySession → if false → logout
- Current flow: verifySession → if false → just log → show gallery anyway
- Result: Gallery shows with invalid session → all requests fail

### 3. Cleanup Bug
- Line 668 in login_screen.dart: `_loginCompleter?.complete(null)` instead of session
- Result: Login flow expected session but got null

## Fixes Applied

### Fix 1: fa_client.dart:_restoreCookiesFromSession()
```dart
// Before: Expected List<List<String>>
for (final pair in cookiePairs) {
  if (pair is List && pair.length >= 2) {
    name = pair[0].toString();
    value = pair[1].toString();
  }
}

// After: Accepts both List<List> and Map formats
for (final item in cookiePairs) {
  String? name;
  String? value;
  
  if (item is Map<String, dynamic>) {
    name = item['name']?.toString();
    value = item['value']?.toString();
  } else if (item is List && item.length >= 2) {
    name = item[0].toString();
    value = item[1].toString();
  }
}
```

### Fix 2: main.dart:_onLogin()
```dart
// Before: Always shows gallery regardless of verifySession
if (!valid) {
  debugPrint('=== Session appears invalid...');
}
if (mounted) {
  setState(() => _isLoggedIn = true);
}

// After: Only shows gallery if verifySession succeeds
if (!valid) {
  debugPrint('=== Session appears invalid — logout and show login');
  await _authService.logout();
  return;
}
if (mounted) {
  setState(() => _isLoggedIn = true);
}
```

### Fix 3: login_screen.dart:Cleanup Branch
```dart
// Before: Complete with null
_loginCompleter?.complete(null);

// After: Complete with session
_loginCompleter!.complete(cleanedSession);
```

## Expected Behavior After Fix

### Successful Login Flow
1. User enters credentials → taps "Login"
2. WebView opens → user logs in → FA redirects to `/user/sergey004`
3. `_handleNavigation()` extracts cookies (a, b, cf_clearance, sz)
4. `_validateCookies()` passes
5. Username extracted from URL
6. Session created with cookies in Map format
7. `_saveCookiesToCookieStore()` saves cookies to CookieManager
8. `_loginCompleter.complete(session)` called
9. `.then()` callback fires → `_onLogin()` called
10. `_restoreCookiesFromSession()` parses cookies (both Map and List formats supported)
11. Cookies saved to Dio cookieJar
12. `verifySession()` makes HTTP request with cookies → **returns true**
13. `_isLoggedIn = true` → app rebuilds → gallery shows
14. Gallery loads submissions successfully

### Failed Login Flow
1. User enters invalid credentials
2. Session created but invalid
3. `_restoreCookiesFromSession()` tries to restore cookies
4. `verifySession()` returns false (403 Cloudflare)
5. `_onLogin()` calls `await _authService.logout()`
6. `_isLoggedIn = false` → login screen shows again
7. User can retry with valid credentials

## Files Modified

1. **furclient/lib/services/fa_client.dart** (lines 117-153)
   - Fixed `_restoreCookiesFromSession()` to accept both Map and List formats

2. **furclient/lib/main.dart** (lines 122-140)
   - Fixed `_onLogin()` to logout when `verifySession()` returns false

3. **furclient/lib/screens/login_screen.dart** (lines 644-670)
   - Fixed cleanup branch to complete with session instead of null

## Testing

✅ All files compile without errors
✅ No static analysis warnings
✅ Unit tests created (mocks generation deferred)

## Verification Steps

1. Run app: `flutter run`
2. Navigate to login screen
3. Enter valid credentials and tap "Login"
4. Verify:
   - WebView shows FA login page
   - User redirected to user page after login
   - Cookies are extracted successfully
   - Gallery screen shows after login completes
   - Gallery loads submissions without 403 errors

## Notes

- The fix maintains backward compatibility with old List<List> format
- Cookie restoration now handles Map format with full cookie data (name, value, domain, path, isHttpOnly, isSecure, expiresDate)
- Session verification is now enforced to prevent invalid sessions from being accepted
