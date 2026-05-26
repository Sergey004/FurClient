import 'dart:async';
import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart' as inapp;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'fa_urls.dart';

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
  }

  Future<void> saveSession(UserSession session) async {
    _currentSession = session;
    await _storage.save(session);
  }

  Future<UserSession?> loginViaWebView() async {
    return null;
  }

  Future<void> logout() async {
    final cookieManager = inapp.CookieManager();
    await cookieManager.deleteAllCookies();

    _currentSession = null;
    await _storage.clear();
  }

  Future<bool> restoreSessionCookies() async {
    if (_currentSession?.cookies == null) return false;
    try {
      final List<dynamic> cookiePairs =
          jsonDecode(_currentSession!.cookies!);
      final cookieManager = inapp.CookieManager();
      for (final pair in cookiePairs) {
        if (pair is List && pair.length >= 2) {
          await cookieManager.setCookie(
            url: inapp.WebUri(FAUrls.baseUrl),
            name: pair[0].toString(),
            value: pair[1].toString(),
            domain: '.furaffinity.net',
            path: '/',
          );
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
