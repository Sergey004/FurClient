import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_inappwebview/flutter_inappwebview.dart' as inapp;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class _SessionStorageService {
  static const _cookiesKey = 'fa_cookies';
  static const _usernameKey = 'fa_username';

  Future<String?> loadCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cookiesKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> loadUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_usernameKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCookies(String cookiesJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cookiesKey, cookiesJson);
    } catch (_) {}
  }

  Future<void> saveUsername(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usernameKey, username);
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cookiesKey);
      await prefs.remove(_usernameKey);
    } catch (_) {}
  }
}

class AuthService {
  final _storage = _SessionStorageService();

  OnlineFASession? _session;
  OnlineFASession? get session => _session;
  String? get username => _session?.username;
  bool get isLoggedIn => _session != null;

  Future<void> loadSavedSession() async {
    final cookiesJson = await _storage.loadCookies();
    if (cookiesJson == null || cookiesJson.isEmpty) return;

    final cookies = _deserializeCookies(cookiesJson);
    if (cookies.isEmpty) return;

    try {
      _session = await OnlineFASession.fromCookies(cookies: cookies);
    } catch (_) {
      _session = null;
    }
  }

  Future<OnlineFASession?> saveSessionFromCookies(
    List<io.Cookie> cookies, {
    bool validate = true,
  }) async {
    if (validate) {
      try {
        _session = await OnlineFASession.fromCookies(cookies: cookies);
      } catch (_) {
        return null;
      }
    } else {
      final username = await _storage.loadUsername() ?? 'user';
      _session = OnlineFASession.restored(
        username: username,
        displayUsername: username,
        cookies: cookies,
      );
    }

    if (_session != null) {
      final cookiesJson = _serializeCookies(cookies);
      await _storage.saveCookies(cookiesJson);
      if (_session!.username.isNotEmpty) {
        await _storage.saveUsername(_session!.username);
      }
    }

    return _session;
  }

  Future<void> logout() async {
    try {
      final cookieManager = inapp.CookieManager();
      await cookieManager.deleteAllCookies();
    } catch (_) {}

    _session = null;
    await _storage.clear();
  }

  static List<io.Cookie> _deserializeCookies(String jsonString) {
    try {
      final List<dynamic> raw = jsonDecode(jsonString);
      return raw.map((e) {
        final map = e as Map<String, dynamic>;
        final c = io.Cookie(
          map['name'] as String? ?? '',
          map['value'] as String? ?? '',
        );
        c.domain = map['domain'] as String? ?? '.furaffinity.net';
        c.path = map['path'] as String? ?? '/';
        c.secure = map['isSecure'] as bool? ?? true;
        c.httpOnly = map['isHttpOnly'] as bool? ?? false;
        return c;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static String _serializeCookies(List<io.Cookie> cookies) {
    final data = cookies.map((c) {
      return <String, dynamic>{
        'name': c.name,
        'value': c.value,
        'domain': c.domain ?? '.furaffinity.net',
        'path': c.path ?? '/',
        'isHttpOnly': c.httpOnly,
        'isSecure': c.secure,
      };
    }).toList();
    return jsonEncode(data);
  }
}
