import 'dart:io' as io;

class CookieStore {
  CookieStore._();

  static final CookieStore _instance = CookieStore._();
  static CookieStore get instance => _instance;

  List<io.Cookie>? _cookies;

  void setCookies(List<io.Cookie> cookies) {
    _cookies = List.from(cookies);
  }

  List<io.Cookie>? get cookies => _cookies;

  String? get cookieHeader {
    if (_cookies == null || _cookies!.isEmpty) return null;
    return _cookies!.map((c) => '${c.name}=${c.value}').join('; ');
  }

  void clear() {
    _cookies = null;
  }
}
