import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CookieMain {
  Future<void> setCookie(String id, String cookie) async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    storage.setString(id, cookie);
    debugPrint('=== CookieMain: Saved cookie for $id');
  }

  Future<String?> getData(String id) async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    return storage.getString(id);
  }

  Future<void> clearCookie(String id) async {
    final SharedPreferences storage = await SharedPreferences.getInstance();
    await storage.remove(id);
  }
}
