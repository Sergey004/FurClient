import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Persistent on-disk + in-memory cache for FA image bytes.
///
/// Mirrors the FurAffinityApp Swift approach (Kingfisher + URLCache) where
/// FA avatars and submission thumbnails persist across sessions and are
/// fetched at most once per URL.  Three layers:
///
/// 1. **In-memory LRU** (`_memoryCache`) — wired directly into [Image.memory]
///    widgets for instant render.
/// 2. **In-flight dedup** (`_inflight`) — a [Completer] per canonical URL so
///    multiple [FAImage] widgets pointing at the same thumbnail share a single
///    network/WebView request instead of stampeding.
/// 3. **On-disk cache** (`flutter_cache_manager`) — survives app restarts and
///    de-dups with other HTTP caches.  Entries older than 30 days are evicted.
///
/// Usage:
/// ```dart
/// final bytes = await FAImageCache.instance.load(url);
/// ```
/// `load(url)` returns instantly from cache or dedups an in-flight fetch.
class FAImageCache {
  FAImageCache._();
  static final FAImageCache instance = FAImageCache._();

  /// In-memory LRU keyed by canonical URL.  Capped at [_memoryLimit].
  final LinkedHashMap<String, Uint8List> _memoryCache = LinkedHashMap();

  /// Currently-running fetches per URL.  Completes with bytes (or null on
  /// failure) so concurrent callers share one request.
  final Map<String, Future<Uint8List?>> _inflight = {};

  static const int _memoryLimit = 256;

  /// Default cache manager from `flutter_cache_manager`.  Stores files in the
  /// platform-appropriate cache directory (`getApplicationCacheDirectory` on
  /// Windows, `getTemporaryDirectory` on Android).
  DefaultCacheManager get _disk => DefaultCacheManager();

  /// Returns cached bytes for [url] or kicks off a single deduped fetch.
  ///
  /// Callers should treat `null` as "fetch failed/empty" and fall back to
  /// their own error UI.
  Future<Uint8List?> load(String url, Future<Uint8List?> Function() fetch) async {
    final key = _canonical(url);
    if (key.isEmpty) return null;

    // Layer 1: in-memory
    final cached = _memoryCache[key];
    if (cached != null) {
      _touchMemory(key);
      return cached;
    }

    // Layer 2: in-flight dedup — same URL, share one Future
    final existing = _inflight[key];
    if (existing != null) return existing;

    // Layer 3: on-disk — single fire-and-await fetch
    final completer = Completer<Uint8List?>();
    _inflight[key] = completer.future;

    try {
      final FileInfo? info = await _disk.getFileFromCache(key);
      if (info != null && await info.file.exists()) {
        final bytes = await info.file.readAsBytes();
        if (bytes.isNotEmpty) {
          _storeMemory(key, bytes);
          completer.complete(bytes);
          return bytes;
        }
      }
    } catch (e) {
      debugPrint('FAImageCache: disk read failed for $key: $e');
    }

    // Network/WebView fetch
    try {
      final bytes = await fetch();
      if (bytes == null || bytes.isEmpty) {
        completer.complete(null);
        return null;
      }
      _storeMemory(key, bytes);
      unawaited(_storeDisk(key, bytes));
      completer.complete(bytes);
      return bytes;
    } catch (e) {
      debugPrint('FAImageCache: fetch failed for $key: $e');
      completer.complete(null);
      return null;
    } finally {
      _inflight.remove(key);
    }
  }

  /// Stores bytes on disk via [DefaultCacheManager.putFile].
  /// Future [getFileFromCache] calls with the same key will return this file.
  Future<void> _storeDisk(String key, Uint8List bytes) async {
    try {
      await _disk.putFile(
        key,
        bytes,
        key: key,
        maxAge: const Duration(days: 30),
        fileExtension: 'bin',
      );
    } catch (e) {
      debugPrint('FAImageCache: disk write failed for $key: $e');
    }
  }

  void _storeMemory(String key, Uint8List bytes) {
    if (_memoryCache.length >= _memoryLimit) {
      final oldestKey = _memoryCache.keys.first;
      _memoryCache.remove(oldestKey);
    }
    _memoryCache[key] = bytes;
  }

  void _touchMemory(String key) {
    final value = _memoryCache.remove(key);
    if (value != null) _memoryCache[key] = value;
  }

  String _canonical(String url) {
    var u = url.trim();
    if (u.startsWith('//')) u = 'https:$u';
    return u;
  }

  /// Drops the in-memory + disk entry for [url].  Used when the user
  /// explicitly requests a fresh fetch (e.g. "Force reload" action).
  Future<void> evict(String url) async {
    final key = _canonical(url);
    _memoryCache.remove(key);
    try {
      await _disk.removeFile(key);
    } catch (_) {}
  }

  /// Clears everything.  Heavy; prefer [evict] for targeted refresh.
  Future<void> clear() async {
    _memoryCache.clear();
    try {
      await _disk.emptyCache();
    } catch (_) {}
  }
}

/// Convenience function for callers that want the bytes only.
Future<Uint8List?> faImageLoad(String url, Future<Uint8List?> Function() fetch) {
  return FAImageCache.instance.load(url, fetch);
}