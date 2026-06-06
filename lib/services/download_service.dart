import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/webview_image_fetcher.dart';

/// Downloads FA images to device storage.
///
/// Path: Download/furaffinity/{rating}/{author}/{original_filename}
/// Rating: general, mature, adult
class DownloadService {
  static DownloadService? _instance;
  static DownloadService get instance => _instance ??= DownloadService._();
  DownloadService._();

  /// Request storage permissions. Returns true if the app can write to storage.
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    if (Platform.isAndroid) {
      // Android 11+ (API 30+): MANAGE_EXTERNAL_STORAGE
      final status = await Permission.manageExternalStorage.status;
      if (status.isGranted) return true;

      if (status.isDenied) {
        final result = await Permission.manageExternalStorage.request();
        if (result.isGranted) return true;
      }

      // Fallback: basic storage permission
      final basicStatus = await Permission.storage.status;
      if (basicStatus.isGranted) return true;

      if (basicStatus.isDenied) {
        final result = await Permission.storage.request();
        return result.isGranted;
      }

      return false;
    }

    // iOS
    final status = await Permission.photos.status;
    if (status.isGranted) return true;
    final result = await Permission.photos.request();
    return result.isGranted;
  }

  /// Download an image from FA and save it to the Downloads directory.
  /// Path: Download/furaffinity/{rating}/{author}/{original_filename}
  ///
  /// If the WebView fetcher fails (dead WebView), automatically resets it
  /// and retries once.
  Future<String?> downloadImage({
    required String imageUrl,
    String title = '',
    String author = '',
    String rating = 'general',
  }) async {
    if (imageUrl.isEmpty) {
      debugPrint('=== DownloadService: Empty URL, skipping');
      return null;
    }

    try {
      // Request permissions if needed
      if (Platform.isAndroid || Platform.isIOS) {
        final hasPermission = await requestPermissions();
        if (!hasPermission) {
          debugPrint('=== DownloadService: Permission denied, trying anyway');
        }
      }

      // Step 1: Download image bytes via WebView (bypasses CF)
      debugPrint('=== DownloadService: Fetching image: $imageUrl');
      var bytes = await WebViewImageFetcher.instance.fetchImage(imageUrl);

      // Retry: if fetch failed, reset WebView and try again
      if (bytes == null || bytes.isEmpty) {
        debugPrint('=== DownloadService: Fetch failed, resetting WebView and retrying...');
        await WebViewImageFetcher.instance.reset();
        await Future.delayed(const Duration(milliseconds: 500));
        bytes = await WebViewImageFetcher.instance.fetchImage(imageUrl);
      }

      if (bytes == null || bytes.isEmpty) {
        debugPrint('=== DownloadService: Failed to fetch image bytes after retry');
        return null;
      }
      debugPrint('=== DownloadService: Fetched ${bytes.length} bytes');

      // Step 2: Build path — /Download/furaffinity/{rating}/{author}/
      final safeAuthor = author.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
      final safeRating = rating.toLowerCase(); // general, mature, adult
      final baseDir = await _getBaseDir();
      final dirPath = '$baseDir/$safeRating/$safeAuthor';
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      debugPrint('=== DownloadService: Save dir: $dirPath');

      // Step 3: Filename — original from URL
      final originalName = _getFilenameFromUrl(imageUrl);
      final filename = originalName ?? _buildFallbackFilename(title, imageUrl);
      final filePath = '$dirPath/$filename';

      // Handle duplicate filenames
      final finalPath = await _getUniquePath(filePath);

      // Step 4: Write file
      final file = File(finalPath);
      await file.writeAsBytes(bytes);

      // Verify file was written
      if (await file.exists()) {
        final size = await file.length();
        debugPrint('=== DownloadService: Saved OK: $finalPath ($size bytes)');
      } else {
        debugPrint('=== DownloadService: ERROR — file not found after write: $finalPath');
      }

      return finalPath;
    } catch (e, stack) {
      debugPrint('=== DownloadService: Download error: $e');
      debugPrint('=== DownloadService: Stack: $stack');
      return null;
    }
  }

  /// Get base download directory.
  /// If user chose a custom folder in Settings, use that.
  /// Otherwise falls back to platform defaults.
  Future<String> _getBaseDir() async {
    // Check for custom download path set in Settings
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('custom_download_path');
    if (customPath != null && customPath.isNotEmpty) {
      try {
        final dir = Directory(customPath);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        // Test write
        final testFile = File('$customPath/.write_test');
        testFile.writeAsStringSync('test');
        testFile.deleteSync();
        final furDir = Directory('$customPath/furaffinity');
        if (!furDir.existsSync()) {
          furDir.createSync(recursive: true);
        }
        debugPrint('=== DownloadService: Using custom path: ${furDir.path}');
        return furDir.path;
      } catch (e) {
        debugPrint('=== DownloadService: Custom path not writable: $e');
      }
    }

    if (Platform.isAndroid) {
      // Try public Downloads/furaffinity
      const publicBase = '/storage/emulated/0/Download/furaffinity';
      try {
        final dir = Directory(publicBase);
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        // Test write
        final testFile = File('$publicBase/.write_test');
        testFile.writeAsStringSync('test');
        testFile.deleteSync();
        debugPrint('=== DownloadService: Using public Downloads: $publicBase');
        return publicBase;
      } catch (e) {
        debugPrint('=== DownloadService: Public Downloads not writable: $e');
      }
    }

    // Fallback: app-specific external directory
    try {
      final dirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (dirs != null && dirs.isNotEmpty) {
        final furDir = Directory('${dirs.first.path}/furaffinity');
        if (!furDir.existsSync()) {
          furDir.createSync(recursive: true);
        }
        debugPrint('=== DownloadService: Using app external: ${furDir.path}');
        return furDir.path;
      }
    } catch (e) {
      debugPrint('=== DownloadService: App external dir error: $e');
    }

    // Final fallback: app documents
    final appDir = await getApplicationDocumentsDirectory();
    final furDir = Directory('${appDir.path}/furaffinity');
    if (!furDir.existsSync()) {
      furDir.createSync(recursive: true);
    }
    debugPrint('=== DownloadService: Using app documents: ${furDir.path}');
    return furDir.path;
  }

  /// Extract the original filename from a URL path.
  /// FA URL: https://d.furaffinity.net/art/author/timestamp/original_filename.ext
  String? _getFilenameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.last;
      if (path.isNotEmpty && path.contains('.')) {
        // Sanitize only filesystem-unsafe characters
        final name = path.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_').trim();
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return null;
  }

  /// Build a fallback filename from title + extension from URL.
  String _buildFallbackFilename(String title, String url) {
    final safeTitle = title
        .replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final ext = _getExtensionFromUrl(url);
    return safeTitle.isNotEmpty ? '$safeTitle$ext' : 'image$ext';
  }

  /// Extract file extension from URL, defaulting to .png.
  String _getExtensionFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      if (path.endsWith('.png')) return '.png';
      if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return '.jpg';
      if (path.endsWith('.gif')) return '.gif';
      if (path.endsWith('.webp')) return '.webp';
      if (path.endsWith('.mp4')) return '.mp4';
      if (path.endsWith('.swf')) return '.swf';
      // Check query params like "...?download&ext=png"
      if (uri.queryParameters.containsKey('ext')) {
        final e = uri.queryParameters['ext']!.toLowerCase();
        if (e == 'png' || e == 'jpg' || e == 'jpeg' || e == 'gif' || e == 'webp') {
          return '.$e';
        }
      }
    } catch (_) {}
    return '.png';
  }

  /// Get a unique file path by appending a number if file already exists.
  Future<String> _getUniquePath(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return filePath;

    final dot = filePath.lastIndexOf('.');
    final base = dot > 0 ? filePath.substring(0, dot) : filePath;
    final ext = dot > 0 ? filePath.substring(dot) : '';

    for (int i = 1; i < 1000; i++) {
      final newPath = '$base ($i)$ext';
      if (!File(newPath).existsSync()) return newPath;
    }

    return filePath;
  }
}
