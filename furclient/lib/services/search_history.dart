import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistory {
  static const _key = 'search_history';
  static const _maxItems = 20;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  List<String> get recent {
    return _prefs?.getStringList(_key) ?? [];
  }

  Future<void> add(String query) async {
    final items = recent;
    items.remove(query);
    items.insert(0, query);
    if (items.length > _maxItems) {
      items.removeRange(_maxItems, items.length);
    }
    await _prefs?.setStringList(_key, items);
  }

  Future<void> remove(String query) async {
    final items = recent;
    items.remove(query);
    await _prefs?.setStringList(_key, items);
  }

  Future<void> clear() async {
    await _prefs?.remove(_key);
  }

  /// Bridge for external search triggers (e.g. tag tap from submission detail).
  /// Set a query → shells switch to Search tab → SearchScreen picks it up.
  static final ValueNotifier<String?> externalQuery = ValueNotifier(null);

  /// Trigger a search from outside the SearchScreen (e.g. tag tap).
  static void triggerSearch(String query) {
    externalQuery.value = query;
  }
}
