import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_inappwebview/flutter_inappwebview.dart' as inapp;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../utils/cookie_store.dart';

class _SessionStorageService {
  static const _sessionKey = 'fa_session';

  Future<UserSession?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_sessionKey);
      if (data != null) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        return UserSession.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  Future<void> save(UserSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    } catch (_) {}
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }
}

class AuthService {
  final _storage = _SessionStorageService();

  UserSession? _currentSession;
  UserSession? get currentSession => _currentSession;

  bool get isLoggedIn => _currentSession?.isLoggedIn ?? false;

  Future<void> loadSavedSession() async {
    _currentSession = await _storage.load();
    _syncCookiesToStore();
  }

  Future<void> saveSession(UserSession session) async {
    _currentSession = session;
    await _storage.save(session);
    _syncCookiesToStore();
  }

  void _syncCookiesToStore() {
    final session = _currentSession;
    if (session?.cookies == null) return;
    try {
      final List<dynamic> raw = jsonDecode(session!.cookies!);
      final cookies = raw.map((e) {
        final map = e as Map<String, dynamic>;
        final c = io.Cookie(
          (map['name'] as String?) ?? '',
          (map['value'] as String?) ?? '',
        );
        c.domain = (map['domain'] as String?) ?? '.furaffinity.net';
        c.path = (map['path'] as String?) ?? '/';
        c.secure = (map['isSecure'] as bool?) ?? true;
        c.httpOnly = (map['isHttpOnly'] as bool?) ?? false;
        return c;
      }).toList();
      CookieStore.instance.setCookies(cookies);
    } catch (_) {}
  }

  Future<UserSession?> loginViaWebView() async {
    return null;
  }

  Future<void> logout() async {
    final cookieManager = inapp.CookieManager();
    await cookieManager.deleteAllCookies();

    _currentSession = null;
    CookieStore.instance.clear();
    await _storage.clear();
  }
}
